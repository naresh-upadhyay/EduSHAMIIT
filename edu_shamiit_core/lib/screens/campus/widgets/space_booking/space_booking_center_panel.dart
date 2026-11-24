import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/campus_models.dart';
import '../../models/space_booking_models.dart';
import '../../providers/campus_provider.dart';
import '../../providers/space_booking_provider.dart';
import '../../services/campus_lookup_helper.dart';
import '../common/campus_pagination_bar.dart';
import '../common/campus_searchable_dropdown.dart';
import 'widgets/space_booking_legend_bar.dart';
import 'widgets/space_booking_week_view.dart';
import 'widgets/space_booking_month_view.dart';
import 'widgets/space_analytics_charts.dart';
import 'dialogs/space_conflict_warning_dialog.dart';
import 'dialogs/create_edit_booking_dialog.dart';

class SpaceBookingCenterPanel extends ConsumerStatefulWidget {
  final Function(SpaceBookingRequestItem item)? onInspectRequest;
  final Function(SpaceBookingRequestItem item)? onEditRequest;
  final Function(SpaceBookingRequestItem item)? onDeleteRequest;
  final Function({
    String? roomId,
    String? roomName,
    String? roomType,
    DateTime? date,
    String? startTime,
    String? endTime,
  })? onCreateBooking;

  const SpaceBookingCenterPanel({
    super.key,
    this.onInspectRequest,
    this.onEditRequest,
    this.onDeleteRequest,
    this.onCreateBooking,
  });

  @override
  ConsumerState<SpaceBookingCenterPanel> createState() => _SpaceBookingCenterPanelState();
}

class _SpaceBookingCenterPanelState extends ConsumerState<SpaceBookingCenterPanel> {
  String _analyticsTimeframe = 'today';
  late TextEditingController _requestSearchCtrl;

  // Dynamic Lookup & Entity State for Searchable Filters
  List<Map<String, dynamic>> _dynamicClasses = [];
  List<BuildingFloorModel> _dynamicFloors = [];
  List<RoomModel> _dynamicRooms = [];
  List<Map<String, dynamic>> _dynamicFacilities = [];
  List<String> _dynamicPurposes = [];
  List<String> _dynamicSpaceTypes = [];
  List<String> _dynamicStatuses = [];
  List<String> _dynamicDepartments = [];

  @override
  void initState() {
    super.initState();
    _requestSearchCtrl = TextEditingController();
    _loadDynamicLookups();
  }

  Future<void> _loadDynamicLookups() async {
    try {
      final futures = await Future.wait([
        CampusLookupHelper.instance.getClasses(),
        CampusLookupHelper.instance.getAllRooms(),
        CampusLookupHelper.instance.getFacilitiesList(),
        CampusLookupHelper.instance.getLookupLabels('BOOKING_PURPOSE'),
        CampusLookupHelper.instance.getLookupLabels('SPACE_TYPE'),
        CampusLookupHelper.instance.getLookupLabels('BOOKING_STATUS'),
        CampusLookupHelper.instance.getDepartments(),
      ]);

      if (mounted) {
        setState(() {
          _dynamicClasses = futures[0] as List<Map<String, dynamic>>;
          _dynamicRooms = futures[1] as List<RoomModel>;
          _dynamicFacilities = futures[2] as List<Map<String, dynamic>>;
          _dynamicPurposes = (futures[3] as List<String>).isNotEmpty
              ? (futures[3] as List<String>)
              : [
                  'Academic',
                  'Class / Lecture Instruction',
                  'Practical / Lab Session',
                  'Examination / Assessment',
                  'Staff / Faculty Meeting',
                  'Workshop / Seminar / Conference',
                  'Cultural & Club Activity',
                  'Sports & Athletic Training',
                  'Parent-Teacher Orientation',
                  'Scheduled Maintenance Downtime',
                  'Other Special Event',
                ];
          _dynamicSpaceTypes = (futures[4] as List<String>).isNotEmpty
              ? (futures[4] as List<String>)
              : [
                  'Classroom',
                  'Smart Classroom',
                  'Auditorium',
                  'Meeting Room',
                  'Computer Lab',
                  'Physics Lab',
                  'Chemistry Lab',
                  'Biology Lab',
                  'Sports Facility',
                  'Gymnasium',
                  'Library Hall',
                  'Cafeteria Hub',
                  'Health Center & Clinic',
                  'Robotics & FabLab',
                ];
          _dynamicStatuses = (futures[5] as List<String>).isNotEmpty
              ? (futures[5] as List<String>)
              : [
                  'Confirmed',
                  'Pending',
                  'In Use',
                  'Approved',
                  'Rejected',
                  'Cancelled',
                  'Conflict',
                ];
          _dynamicDepartments = (futures[6] as List<String>).isNotEmpty
              ? (futures[6] as List<String>)
              : [
                  'Administration',
                  'Academic / Teaching',
                  'Maintenance & Facilities',
                  'Science & Labs',
                  'Sports & Physical Ed',
                  'Arts & Culture',
                  'IT & Infrastructure',
                ];
        });
      }
    } catch (_) {}
  }

  Future<void> _loadFloorsForBuilding(String buildingId) async {
    if (buildingId == 'all' || buildingId.isEmpty) {
      if (mounted) {
        setState(() {
          _dynamicFloors = [];
        });
      }
      return;
    }
    try {
      final floors = await CampusLookupHelper.instance.getFloorsForBuilding(buildingId);
      if (mounted) {
        setState(() {
          _dynamicFloors = floors;
        });
      }
    } catch (_) {}
  }

  int _getActiveFiltersCount(SpaceBookingState state) {
    int count = 0;
    if (state.selectedDomain != 'all' && state.selectedDomain.isNotEmpty) count++;
    if (state.selectedBuildingId != 'all' && state.selectedBuildingId.isNotEmpty) count++;
    if (state.selectedFloorId != 'all' && state.selectedFloorId.isNotEmpty) count++;
    if (state.selectedRoomId != 'all' && state.selectedRoomId.isNotEmpty) count++;
    if (state.selectedSpaceType != 'All' && state.selectedSpaceType.isNotEmpty) count++;
    if (state.selectedPurpose != 'All' && state.selectedPurpose.isNotEmpty) count++;
    if (state.selectedClassId != 'all' && state.selectedClassId.isNotEmpty) count++;
    if (state.selectedDepartment != 'all' && state.selectedDepartment.isNotEmpty) count++;
    if (state.statusFilter != 'All' && state.statusFilter.isNotEmpty) count++;
    if (state.selectedCapacity != 'Any Capacity' && state.selectedCapacity.isNotEmpty) count++;
    return count;
  }

  int _parseCapacityMin(String capStr) {
    final match = RegExp(r'(\d+)').firstMatch(capStr);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 0;
    }
    return 0;
  }

  String _getClassName(String classId) {
    try {
      final c = _dynamicClasses.firstWhere((x) => x['id']?.toString() == classId);
      return c['name']?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  void _resetAllFilters(SpaceBookingNotifier notifier) {
    notifier.resetFilters();
    setState(() {
      _dynamicFloors = [];
    });
  }

  List<SpaceTimelineRoom> _getFilteredRooms(SpaceBookingState state) {
    if (state.roomsTimeline.isEmpty) return const [];

    return state.roomsTimeline.where((room) {
      // 1. Domain filter (room vs facility)
      if (state.selectedDomain != 'all' && state.selectedDomain.isNotEmpty) {
        final d = (room.spaceDomain ?? 'room').toLowerCase();
        if (d != state.selectedDomain.toLowerCase()) return false;
      }

      // 2. Building filter
      if (state.selectedBuildingId != 'all' && state.selectedBuildingId.isNotEmpty) {
        if (room.buildingId != state.selectedBuildingId) return false;
      }

      // 3. Floor filter
      if (state.selectedFloorId != 'all' && state.selectedFloorId.isNotEmpty) {
        if (room.floorId != null && room.floorId != state.selectedFloorId) return false;
      }

      // 4. Room/Facility ID filter
      if (state.selectedRoomId != 'all' && state.selectedRoomId.isNotEmpty) {
        if (room.roomId != state.selectedRoomId) return false;
      }

      // 5. Space Type filter
      if (state.selectedSpaceType != 'All' && state.selectedSpaceType.isNotEmpty) {
        final st = state.selectedSpaceType.toLowerCase();
        final rt = room.roomType.toLowerCase();
        if (!rt.contains(st) && !st.contains(rt)) return false;
      }

      // 6. Capacity filter
      if (state.selectedCapacity != 'Any Capacity' && state.selectedCapacity.isNotEmpty) {
        final minCap = _parseCapacityMin(state.selectedCapacity);
        if (room.capacity < minCap) return false;
      }

      // 7. Purpose filter (if selected, room must have a booking with matching purpose)
      if (state.selectedPurpose != 'All' && state.selectedPurpose.isNotEmpty) {
        final p = state.selectedPurpose.toLowerCase();
        final hasMatch = room.bookings.any((b) =>
            b.purpose.toLowerCase().contains(p) ||
            b.title.toLowerCase().contains(p) ||
            p.contains(b.purpose.toLowerCase()));
        if (!hasMatch) return false;
      }

      // 8. Class / Section filter
      if (state.selectedClassId != 'all' && state.selectedClassId.isNotEmpty) {
        final className = _getClassName(state.selectedClassId);
        final hasClassMatch = room.bookings.any((b) =>
            (className.isNotEmpty && b.title.toLowerCase().contains(className.toLowerCase())) ||
            (className.isNotEmpty && b.purpose.toLowerCase().contains(className.toLowerCase())));
        if (!hasClassMatch) return false;
      }

      // 9. Department filter
      if (state.selectedDepartment != 'all' && state.selectedDepartment.isNotEmpty) {
        final dept = state.selectedDepartment.toLowerCase();
        final hasDeptMatch = room.bookings.any((b) =>
            b.organizerRole.toLowerCase().contains(dept) ||
            b.organizerName.toLowerCase().contains(dept) ||
            b.title.toLowerCase().contains(dept));
        if (!hasDeptMatch) return false;
      }

      // 10. Status filter
      if (state.statusFilter != 'All' && state.statusFilter.isNotEmpty) {
        final s = state.statusFilter.toLowerCase();
        final hasStatusMatch = room.bookings.any((b) => b.status.toLowerCase() == s);
        if (!hasStatusMatch) return false;
      }

      return true;
    }).toList();
  }

  @override
  void dispose() {
    _requestSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(spaceBookingProvider);
    final notifier = ref.read(spaceBookingProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isBookingSpaces = state.selectedNav == 'Booking Spaces' ||
        state.selectedNav == 'Booking Space' ||
        state.selectedNav == 'Booking Calendar';
    final isRequests = state.selectedNav == 'Booking Requests' ||
        state.selectedNav == 'Pending Requests' ||
        state.selectedNav == 'Approved Bookings' ||
        state.selectedNav == 'Rejected Bookings' ||
        state.selectedNav == 'My Bookings';
    final isUsage = state.selectedNav == 'Usage & Reports';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Center Navigation Tabs (Booking Spaces, Booking Requests, Usage & Reports)
        _buildTopViewTabs(state, notifier, isDark),
        const SizedBox(height: 14),

        // Active View Body (No stacking = zero scrolling to find the grid or requests!)
        if (isBookingSpaces)
          _buildAvailabilityBlock(state, notifier, isDark)
        else if (isRequests)
          _buildBookingRequestsBlock(state, notifier, isDark)
        else if (isUsage)
          _buildUsageAndReportsScreen(state, notifier, isDark)
        else
          _buildAvailabilityBlock(state, notifier, isDark),
      ],
    );
  }

  // ==========================================================================
  // TOP NAVIGATION TABS (BOOKING SPACES | BOOKING REQUESTS | USAGE & REPORTS)
  // ==========================================================================

  Widget _buildTopViewTabs(SpaceBookingState state, SpaceBookingNotifier notifier, bool isDark) {
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    final isBookingSpaces = state.selectedNav == 'Booking Spaces' ||
        state.selectedNav == 'Booking Space' ||
        state.selectedNav == 'Booking Calendar';
    final isRequests = state.selectedNav == 'Booking Requests' ||
        state.selectedNav == 'Pending Requests' ||
        state.selectedNav == 'Approved Bookings' ||
        state.selectedNav == 'Rejected Bookings' ||
        state.selectedNav == 'My Bookings';
    final isUsage = state.selectedNav == 'Usage & Reports';

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTopTabItem(
              icon: Icons.grid_view_rounded,
              label: 'Booking Spaces',
              isSelected: isBookingSpaces,
              badgeCount: null,
              isDark: isDark,
              onTap: () => notifier.setSelectedNav('Booking Spaces'),
            ),
            const SizedBox(width: 4),
            _buildTopTabItem(
              icon: Icons.assignment_outlined,
              label: 'Booking Requests',
              isSelected: isRequests,
              badgeCount: state.kpis.pendingBookings,
              badgeColor: isDark ? const Color(0xFF312E81) : const Color(0xFFE0E7FF),
              badgeTextColor: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4338CA),
              isDark: isDark,
              onTap: () => notifier.setSelectedNav('Booking Requests'),
            ),
            const SizedBox(width: 4),
            _buildTopTabItem(
              icon: Icons.bar_chart_outlined,
              label: 'Usage & Reports',
              isSelected: isUsage,
              badgeCount: null,
              isDark: isDark,
              onTap: () => notifier.setSelectedNav('Usage & Reports'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopTabItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    int? badgeCount,
    Color? badgeColor,
    Color? badgeTextColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
              ),
            ),
            if (badgeCount != null && badgeCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : (badgeColor ?? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : (badgeTextColor ?? const Color(0xFF4338CA)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // UPPER BLOCK: AVAILABILITY & TIMELINE GRID
  // ==========================================================================

  Widget _buildAvailabilityBlock(SpaceBookingState state, SpaceBookingNotifier notifier, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Title & Subtitle + Day/Week/Month + Date navigator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 650;

                final titleBlock = Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 20, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Space Availability & Booking',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'View and manage space bookings across your campus',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                final controlsBlock = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // View Mode Toggle: Day / Week / Month
                    Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Row(
                        children: ['Day', 'Week', 'Month'].map((mode) {
                          final isSel = state.timelineViewMode == mode;
                          return InkWell(
                            onTap: () => notifier.setTimelineViewMode(mode),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSel ? const Color(0xFF2563EB) : Colors.transparent,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Text(
                                mode,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSel ? Colors.white : textSecondary,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Today Button
                    OutlinedButton(
                      onPressed: () => notifier.jumpToToday(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        minimumSize: const Size(0, 32),
                        side: BorderSide(color: cardBorder),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(
                        'Today',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Date Navigator: < Mon, 15 Mar 2026 >
                    Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                        border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.chevron_left, size: 18, color: textSecondary),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 24),
                            onPressed: () => notifier.previousDate(),
                          ),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: state.selectedDate,
                                firstDate: DateTime(2025),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                notifier.changeDate(picked);
                              }
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.calendar_month, size: 15, color: Color(0xFF3B82F6)),
                                  const SizedBox(width: 6),
                                  Text(
                                    state.timelineViewMode == 'Month'
                                        ? DateFormat('MMMM yyyy').format(state.selectedDate)
                                        : (state.timelineViewMode == 'Week'
                                            ? 'Week of ${DateFormat('d MMM').format(state.selectedDate.subtract(Duration(days: state.selectedDate.weekday - 1)))}'
                                            : DateFormat('EEE, d MMM yyyy').format(state.selectedDate)),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.chevron_right, size: 18, color: textSecondary),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 24),
                            onPressed: () => notifier.nextDate(),
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleBlock,
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: controlsBlock,
                      ),
                    ],
                  );
                } else {
                  return Row(
                    children: [
                      Expanded(child: titleBlock),
                      const SizedBox(width: 12),
                      controlsBlock,
                    ],
                  );
                }
              },
            ),
          ),
          Divider(color: cardBorder, height: 1),

          // Filters Row: Building, Space Type, Status + Timeline/List Toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Filter Row 1: Space Location Allocation (Domain, Building, Floor, Room/Space, Space Type)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildDomainDropdown(state, notifier, isDark),
                    _buildBuildingDropdown(state, notifier, isDark),
                    _buildFloorDropdown(state, notifier, isDark),
                    _buildRoomDropdown(state, notifier, isDark),
                    _buildSpaceTypeDropdown(state, notifier, isDark),
                  ],
                ),
                const SizedBox(height: 8),

                // Filter Row 2: Booking Criteria & Actions (Purpose, Class, Department, Status, Capacity, Reset, Timeline/List toggle)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildPurposeDropdown(state, notifier, isDark),
                        _buildClassDropdown(state, notifier, isDark),
                        _buildDepartmentDropdown(state, notifier, isDark),
                        _buildStatusDropdown(state, notifier, isDark),
                        _buildCapacityDropdown(state, notifier, isDark),

                        if (_getActiveFiltersCount(state) > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.filter_alt, size: 13, color: Color(0xFF3B82F6)),
                                const SizedBox(width: 4),
                                Text(
                                  '${_getActiveFiltersCount(state)} Active',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF3B82F6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () => _resetAllFilters(notifier),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.filter_alt_off_outlined, size: 13, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Reset All',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : const Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Toggle: Timeline vs List
                    _buildTimelineListToggle(state, notifier, isDark, cardBorder, textSecondary),
                  ],
                ),
              ],
            ),
          ),
          Divider(color: cardBorder, height: 1),

          // Legend Filter Bar
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SpaceBookingLegendBarWidget(),
          ),
          Divider(color: cardBorder, height: 1),

          // Interactive Timeline Grid / Week View / Month View / List View
          if (state.displayMode == 'List')
            _buildScheduledBookingsListView(state, notifier, isDark, _getFilteredRooms(state))
          else if (state.timelineViewMode == 'Week')
            SpaceBookingWeekView(
              selectedDate: state.selectedDate,
              rooms: _getFilteredRooms(state),
              selectedPurpose: state.selectedPurpose,
              onInspectRequest: widget.onInspectRequest,
              onSlotTap: (day, time) {
                if (widget.onCreateBooking != null) {
                  final parts = time.split(':');
                  final h = int.tryParse(parts[0]) ?? 10;
                  final startStr = h < 12
                      ? '${h.toString().padLeft(2, '0')}:00 AM'
                      : (h == 12 ? '12:00 PM' : '${(h - 12).toString().padLeft(2, '0')}:00 PM');
                  final endH = h + 1;
                  final endStr = endH < 12
                      ? '${endH.toString().padLeft(2, '0')}:00 AM'
                      : (endH == 12 ? '12:00 PM' : '${(endH - 12).toString().padLeft(2, '0')}:00 PM');
                  widget.onCreateBooking!(
                    date: day,
                    startTime: startStr,
                    endTime: endStr,
                  );
                }
              },
            )
          else if (state.timelineViewMode == 'Month')
            SpaceBookingMonthView(
              selectedDate: state.selectedDate,
              rooms: _getFilteredRooms(state),
              selectedPurpose: state.selectedPurpose,
              onInspectRequest: widget.onInspectRequest,
              onDayTap: (day) {
                notifier.changeDate(day);
                notifier.setTimelineViewMode('Day');
              },
            )
          else
            _buildInteractiveGrid(state, isDark, _getFilteredRooms(state)),
        ],
      ),
    );
  }

  Widget _buildScheduledBookingsListView(
    SpaceBookingState state,
    SpaceBookingNotifier notifier,
    bool isDark,
    List<SpaceTimelineRoom> filteredRooms,
  ) {
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final List<Map<String, dynamic>> items = [];
    for (final room in filteredRooms) {
      for (final b in room.bookings) {
        if (state.selectedPurpose != 'All' && state.selectedPurpose.isNotEmpty) {
          final p = state.selectedPurpose.toLowerCase();
          if (!b.purpose.toLowerCase().contains(p) && !b.title.toLowerCase().contains(p) && !p.contains(b.purpose.toLowerCase())) {
            continue;
          }
        }
        if (state.selectedClassId != 'all' && state.selectedClassId.isNotEmpty) {
          final className = _getClassName(state.selectedClassId);
          if (className.isNotEmpty &&
              !b.title.toLowerCase().contains(className.toLowerCase()) &&
              !b.purpose.toLowerCase().contains(className.toLowerCase())) {
            continue;
          }
        }
        if (state.selectedDepartment != 'all' && state.selectedDepartment.isNotEmpty) {
          final dept = state.selectedDepartment.toLowerCase();
          if (!b.organizerRole.toLowerCase().contains(dept) &&
              !b.organizerName.toLowerCase().contains(dept) &&
              !b.title.toLowerCase().contains(dept)) {
            continue;
          }
        }
        if (state.statusFilter != 'All' && state.statusFilter.isNotEmpty) {
          if (b.status.toLowerCase() != state.statusFilter.toLowerCase()) {
            continue;
          }
        }
        items.add({
          'booking': b,
          'room': room,
        });
      }
    }

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.event_busy_outlined, size: 40, color: textSecondary),
              const SizedBox(height: 8),
              Text(
                'No scheduled bookings found for this filter/date.',
                style: TextStyle(fontSize: 13, color: textSecondary, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => Divider(color: cardBorder, height: 16),
      itemBuilder: (context, index) {
        final item = items[index];
        final SpaceTimelineBooking b = item['booking'];
        final SpaceTimelineRoom room = item['room'];

        return InkWell(
          onTap: () {
            if (widget.onInspectRequest != null) {
              widget.onInspectRequest!(SpaceBookingRequestItem(
                id: b.id,
                bookingRef: b.bookingRef.isNotEmpty ? b.bookingRef : 'SB-${b.id.length > 8 ? b.id.substring(0, 8) : b.id}',
                title: b.title,
                purpose: b.purpose.isNotEmpty ? b.purpose : 'Academic Booking',
                category: 'Academic',
                priority: 'Normal',
                status: b.status,
                isApproved: b.status.toLowerCase() == 'confirmed' || b.status.toLowerCase() == 'approved',
                bookingDate: DateFormat('d MMM yyyy').format(state.selectedDate),
                startTime: b.startTime,
                endTime: b.endTime,
                formattedSchedule: '${b.startTime} - ${b.endTime}',
                roomId: room.roomId,
                roomName: room.roomName.isNotEmpty ? room.roomName : 'Room ${room.roomNumber}',
                roomType: room.roomType.isNotEmpty ? room.roomType : 'Classroom',
                spaceDisplay: '${room.roomNumber} - ${room.roomName}',
                buildingId: room.buildingId,
                buildingName: room.buildingName.isNotEmpty ? room.buildingName : 'Academic Block',
                organizerName: b.organizerName.isNotEmpty ? b.organizerName : 'Faculty',
                organizerRole: b.organizerRole.isNotEmpty ? b.organizerRole : 'Organizer',
                requestedByDisplay: '${b.organizerName} (${b.organizerRole})',
                attendeeCount: room.capacity > 0 ? room.capacity : 30,
                isRecurring: false,
              ));
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        b.startTime,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF3B82F6)),
                      ),
                      Text(
                        b.endTime,
                        style: TextStyle(fontSize: 10, color: textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              b.title,
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              room.roomName,
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: textPrimary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Organizer: ${b.organizerName} • ${room.roomType} (Cap: ${room.capacity})',
                        style: TextStyle(fontSize: 11.5, color: textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: b.status.toLowerCase() == 'confirmed'
                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                        : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    b.status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: b.status.toLowerCase() == 'confirmed' ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, size: 18, color: textSecondary),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSmallDropdown({
    required String label,
    required String value,
    required bool isDark,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.any((i) => i.value == value) ? value : (items.isNotEmpty ? items.first.value : null),
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          icon: Icon(Icons.keyboard_arrow_down, size: 16, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF1E293B), fontWeight: FontWeight.w500),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildInteractiveGrid(SpaceBookingState state, bool isDark, List<SpaceTimelineRoom> displayRooms) {
    final headerBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final gridLineColor = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final timeSlots = [
      '8:00 AM', '9:00 AM', '10:00 AM', '11:00 AM', '12:00 PM',
      '1:00 PM', '2:00 PM', '3:00 PM', '4:00 PM', '5:00 PM'
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        constraints: const BoxConstraints(minWidth: 820),
        child: Column(
          children: [
            // Table Header
            Container(
              height: 36,
              color: headerBg,
              child: Row(
                children: [
                  Container(
                    width: 140,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Space / Room',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textSecondary),
                    ),
                  ),
                  Container(
                    width: 65,
                    alignment: Alignment.center,
                    child: Text(
                      'Capacity',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textSecondary),
                    ),
                  ),
                  ...timeSlots.map((slot) => Container(
                        width: 62,
                        alignment: Alignment.center,
                        child: Text(
                          slot,
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: textSecondary),
                        ),
                      )),
                ],
              ),
            ),
            Divider(color: cardBorder, height: 1),

            // Rows
            if (state.isLoading)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Text('Loading spaces availability...', style: TextStyle(color: textSecondary, fontSize: 13)),
                  ],
                ),
              )
            else if (displayRooms.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  _getActiveFiltersCount(state) > 0
                      ? 'No spaces match the selected filters on this date. Try clearing some filters.'
                      : 'No rooms available for timeline on this date.',
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
              )
            else
              ...displayRooms.map((room) => _buildTimelineRoomRow(
                    room,
                    timeSlots,
                    isDark,
                    gridLineColor,
                    state.selectedPurpose,
                    state.statusFilter,
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineRoomRow(
    SpaceTimelineRoom room,
    List<String> slots,
    bool isDark,
    Color gridLineColor,
    String? selectedPurpose,
    String? statusFilter,
  ) {
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final textMuted = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);

    return Container(
      height: 54,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: gridLineColor, width: 1)),
      ),
      child: Row(
        children: [
          // Space / Room Title
          Container(
            width: 140,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  room.roomName,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '(${room.roomType})',
                  style: TextStyle(fontSize: 11, color: textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Capacity
          Container(
            width: 65,
            alignment: Alignment.center,
            child: Text(
              '${room.capacity}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMuted),
            ),
          ),

          // Timeline Canvas (10 slots x 62px = 620px width)
          SizedBox(
            width: 620,
            height: 54,
            child: Stack(
              children: [
                // Background grid vertical interactive slots
                Row(
                  children: List.generate(10, (i) {
                    final startH = 8 + i;
                    final endH = startH + 1;
                    final startStr = startH < 12
                        ? '${startH.toString().padLeft(2, '0')}:00 AM'
                        : (startH == 12 ? '12:00 PM' : '${(startH - 12).toString().padLeft(2, '0')}:00 PM');
                    final endStr = endH < 12
                        ? '${endH.toString().padLeft(2, '0')}:00 AM'
                        : (endH == 12 ? '12:00 PM' : '${(endH - 12).toString().padLeft(2, '0')}:00 PM');

                    return Tooltip(
                      message: 'Click to schedule ${room.roomName} ($startStr - $endStr)',
                      waitDuration: const Duration(milliseconds: 300),
                      child: InkWell(
                        onTap: () {
                          if (widget.onCreateBooking != null) {
                            widget.onCreateBooking!(
                              roomId: room.roomId,
                              roomName: room.roomName,
                              roomType: room.roomType,
                              date: ref.read(spaceBookingProvider).selectedDate,
                              startTime: startStr,
                              endTime: endStr,
                            );
                          }
                        },
                        hoverColor: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                        child: Container(
                          width: 62,
                          height: 54,
                          decoration: BoxDecoration(
                            border: Border(right: BorderSide(color: gridLineColor)),
                          ),
                        ),
                      ),
                    );
                  }),
                ),

                // Booking Event Chips
                ...room.bookings.where((b) {
                  if (selectedPurpose != null && selectedPurpose != 'All' && selectedPurpose.isNotEmpty) {
                    final p = selectedPurpose.toLowerCase();
                    if (!b.purpose.toLowerCase().contains(p) && !b.title.toLowerCase().contains(p) && !p.contains(b.purpose.toLowerCase())) {
                      return false;
                    }
                  }
                  if (statusFilter != null && statusFilter != 'All' && statusFilter.isNotEmpty) {
                    if (b.status.toLowerCase() != statusFilter.toLowerCase()) {
                      return false;
                    }
                  }
                  return true;
                }).map((b) => _buildBookingChip(b, room, isDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDomainDropdown(SpaceBookingState state, SpaceBookingNotifier notifier, bool isDark) {
    return CampusSearchableDropdown<String>(
      title: 'Domain / Venue Type',
      label: 'All Venues',
      value: state.selectedDomain,
      allValue: 'all',
      prefixIcon: Icons.domain_rounded,
      isDark: isDark,
      minWidth: 120,
      maxWidth: 190,
      items: const [
        CampusSearchableDropdownItem(
          value: 'all',
          label: 'All Venues',
          subtitle: 'Classrooms, Halls & Facilities',
          icon: Icons.apartment_rounded,
        ),
        CampusSearchableDropdownItem(
          value: 'room',
          label: 'Classrooms & Rooms',
          subtitle: 'Academic spaces, lecture halls & labs',
          icon: Icons.meeting_room_outlined,
          iconColor: Color(0xFF3B82F6),
        ),
        CampusSearchableDropdownItem(
          value: 'facility',
          label: 'Campus Facilities',
          subtitle: 'Grounds, stadiums, sports & clinic',
          icon: Icons.sports_soccer_outlined,
          iconColor: Color(0xFF10B981),
        ),
      ],
      onChanged: (val) {
        notifier.applyQuickFilters(domain: val);
      },
    );
  }

  Widget _buildBuildingDropdown(SpaceBookingState state, SpaceBookingNotifier notifier, bool isDark) {
    final buildings = ref.watch(campusProvider).buildings;
    return CampusSearchableDropdown<String>(
      title: 'Campus Building',
      label: 'All Buildings',
      value: state.selectedBuildingId,
      allValue: 'all',
      prefixIcon: Icons.apartment_rounded,
      isDark: isDark,
      minWidth: 130,
      maxWidth: 220,
      items: [
        const CampusSearchableDropdownItem(
          value: 'all',
          label: 'All Buildings',
          subtitle: 'All campus locations',
          icon: Icons.location_city_rounded,
        ),
        ...buildings.map((b) => CampusSearchableDropdownItem(
          value: b.id,
          label: '${b.code} - ${b.name}',
          subtitle: '${b.totalRooms} Rooms • ${b.totalFloors} Floors',
          icon: Icons.business_outlined,
          iconColor: const Color(0xFF3B82F6),
        )),
      ],
      onChanged: (val) {
        _loadFloorsForBuilding(val);
        notifier.applyQuickFilters(
          buildingId: val,
          floorId: 'all',
          roomId: 'all',
        );
      },
    );
  }

  Widget _buildFloorDropdown(SpaceBookingState state, SpaceBookingNotifier notifier, bool isDark) {
    return CampusSearchableDropdown<String>(
      title: 'Floor Level',
      label: 'All Floors',
      value: state.selectedFloorId,
      allValue: 'all',
      prefixIcon: Icons.stairs_outlined,
      isDark: isDark,
      minWidth: 110,
      maxWidth: 170,
      items: [
        const CampusSearchableDropdownItem(
          value: 'all',
          label: 'All Floors',
          subtitle: 'Show all levels',
          icon: Icons.stairs_outlined,
        ),
        ..._dynamicFloors.map((f) => CampusSearchableDropdownItem(
          value: f.id,
          label: f.name,
          subtitle: 'Floor Level ${f.floorLevel}',
          icon: Icons.layers_outlined,
          iconColor: const Color(0xFF8B5CF6),
        )),
      ],
      onChanged: (val) {
        notifier.applyQuickFilters(
          floorId: val,
          roomId: 'all',
        );
      },
    );
  }

  Widget _buildRoomDropdown(SpaceBookingState state, SpaceBookingNotifier notifier, bool isDark) {
    final List<CampusSearchableDropdownItem<String>> items = [
      const CampusSearchableDropdownItem(
        value: 'all',
        label: 'All Spaces',
        subtitle: 'Every bookable room or ground',
        icon: Icons.room_preferences_outlined,
      ),
    ];

    // Filter rooms by building and floor if chosen
    if (state.selectedDomain != 'facility') {
      final filteredRooms = _dynamicRooms.where((r) {
        if (state.selectedBuildingId != 'all' && state.selectedBuildingId.isNotEmpty) {
          if (r.buildingId != state.selectedBuildingId) return false;
        }
        if (state.selectedFloorId != 'all' && state.selectedFloorId.isNotEmpty) {
          if (r.floorId != state.selectedFloorId) return false;
        }
        return true;
      });

      for (final r in filteredRooms) {
        items.add(CampusSearchableDropdownItem(
          value: r.id,
          label: '${r.roomNumber} - ${r.name}',
          subtitle: '${r.roomType} • Fits ${r.maxCapacity} seats',
          icon: Icons.meeting_room_outlined,
          iconColor: const Color(0xFF3B82F6),
        ));
      }
    }

    if (state.selectedDomain != 'room') {
      final filteredFac = _dynamicFacilities.where((fac) {
        if (state.selectedBuildingId != 'all' && state.selectedBuildingId.isNotEmpty) {
          if (fac['building_id'] != null && fac['building_id'] != state.selectedBuildingId) return false;
        }
        return true;
      });

      for (final fac in filteredFac) {
        final fid = fac['id']?.toString() ?? '';
        if (fid.isNotEmpty) {
          items.add(CampusSearchableDropdownItem(
            value: fid,
            label: '${fac['name']} (${fac['code'] ?? 'FAC'})',
            subtitle: '${fac['category'] ?? 'Facility'} • Cap: ${fac['capacity'] ?? 100}',
            icon: Icons.sports_soccer_outlined,
            iconColor: const Color(0xFF10B981),
          ));
        }
      }
    }

    return CampusSearchableDropdown<String>(
      title: 'Space / Venue',
      label: 'All Spaces',
      value: state.selectedRoomId,
      allValue: 'all',
      prefixIcon: Icons.meeting_room_outlined,
      isDark: isDark,
      minWidth: 130,
      maxWidth: 220,
      items: items,
      onChanged: (val) {
        notifier.applyQuickFilters(roomId: val);
      },
    );
  }

  Widget _buildSpaceTypeDropdown(SpaceBookingState state, SpaceBookingNotifier notifier, bool isDark) {
    return CampusSearchableDropdown<String>(
      title: 'Space Type',
      label: 'All Types',
      value: state.selectedSpaceType,
      allValue: 'All',
      prefixIcon: Icons.category_outlined,
      isDark: isDark,
      minWidth: 120,
      maxWidth: 180,
      items: [
        const CampusSearchableDropdownItem(
          value: 'All',
          label: 'All Space Types',
          subtitle: 'Classrooms, labs, sports, etc.',
          icon: Icons.category_outlined,
        ),
        ..._dynamicSpaceTypes.map((type) => CampusSearchableDropdownItem(
          value: type,
          label: type,
          icon: Icons.grid_view_rounded,
          iconColor: const Color(0xFF6366F1),
        )),
      ],
      onChanged: (val) {
        notifier.applyQuickFilters(spaceType: val);
      },
    );
  }

  Widget _buildPurposeDropdown(SpaceBookingState state, SpaceBookingNotifier notifier, bool isDark) {
    return CampusSearchableDropdown<String>(
      title: 'Booking Purpose',
      label: 'All Purposes',
      value: state.selectedPurpose,
      allValue: 'All',
      prefixIcon: Icons.flag_outlined,
      isDark: isDark,
      minWidth: 120,
      maxWidth: 180,
      items: [
        const CampusSearchableDropdownItem(
          value: 'All',
          label: 'All Purposes',
          subtitle: 'Instruction, exams, meetings, etc.',
          icon: Icons.flag_outlined,
        ),
        ..._dynamicPurposes.map((p) => CampusSearchableDropdownItem(
          value: p,
          label: p,
          icon: Icons.event_note_outlined,
          iconColor: const Color(0xFF0EA5E9),
        )),
      ],
      onChanged: (val) {
        notifier.applyQuickFilters(purpose: val);
      },
    );
  }

  Widget _buildClassDropdown(SpaceBookingState state, SpaceBookingNotifier notifier, bool isDark) {
    return CampusSearchableDropdown<String>(
      title: 'Target Class / Cohort',
      label: 'All Classes',
      value: state.selectedClassId,
      allValue: 'all',
      prefixIcon: Icons.school_outlined,
      isDark: isDark,
      minWidth: 120,
      maxWidth: 180,
      items: [
        const CampusSearchableDropdownItem(
          value: 'all',
          label: 'All Classes',
          subtitle: 'All cohorts & sections',
          icon: Icons.school_outlined,
        ),
        ..._dynamicClasses.map((c) => CampusSearchableDropdownItem(
          value: c['id']?.toString() ?? '',
          label: '${c['name']} (${c['code'] ?? ''})',
          subtitle: c['stage'] != null ? 'Stage: ${c['stage']}' : null,
          icon: Icons.group_outlined,
          iconColor: const Color(0xFFF59E0B),
        )),
      ],
      onChanged: (val) {
        notifier.applyQuickFilters(classId: val);
      },
    );
  }

  Widget _buildDepartmentDropdown(SpaceBookingState state, SpaceBookingNotifier notifier, bool isDark) {
    return CampusSearchableDropdown<String>(
      title: 'Department / Faculty',
      label: 'All Departments',
      value: state.selectedDepartment,
      allValue: 'all',
      prefixIcon: Icons.business_center_outlined,
      isDark: isDark,
      minWidth: 120,
      maxWidth: 180,
      items: [
        const CampusSearchableDropdownItem(
          value: 'all',
          label: 'All Departments',
          subtitle: 'All academic & admin units',
          icon: Icons.business_center_outlined,
        ),
        ..._dynamicDepartments.map((dept) => CampusSearchableDropdownItem(
          value: dept,
          label: dept,
          icon: Icons.account_balance_outlined,
          iconColor: const Color(0xFF8B5CF6),
        )),
      ],
      onChanged: (val) {
        notifier.applyQuickFilters(department: val);
      },
    );
  }

  Widget _buildStatusDropdown(SpaceBookingState state, SpaceBookingNotifier notifier, bool isDark) {
    return CampusSearchableDropdown<String>(
      title: 'Booking Status',
      label: 'All Statuses',
      value: state.statusFilter,
      allValue: 'All',
      prefixIcon: Icons.verified_outlined,
      isDark: isDark,
      minWidth: 110,
      maxWidth: 160,
      items: [
        const CampusSearchableDropdownItem(
          value: 'All',
          label: 'All Statuses',
          subtitle: 'Any approval state',
          icon: Icons.verified_outlined,
        ),
        ..._dynamicStatuses.map((s) => CampusSearchableDropdownItem(
          value: s,
          label: s,
          icon: Icons.check_circle_outline,
          iconColor: s.toLowerCase() == 'confirmed' || s.toLowerCase() == 'approved'
              ? const Color(0xFF10B981)
              : (s.toLowerCase() == 'pending' ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)),
        )),
      ],
      onChanged: (val) {
        notifier.applyQuickFilters(status: val);
      },
    );
  }

  Widget _buildCapacityDropdown(SpaceBookingState state, SpaceBookingNotifier notifier, bool isDark) {
    return CampusSearchableDropdown<String>(
      title: 'Min Capacity',
      label: 'Any Capacity',
      value: state.selectedCapacity,
      allValue: 'Any Capacity',
      prefixIcon: Icons.people_outline,
      isDark: isDark,
      minWidth: 110,
      maxWidth: 160,
      items: const [
        CampusSearchableDropdownItem(
          value: 'Any Capacity',
          label: 'Any Capacity',
          subtitle: 'No minimum capacity',
          icon: Icons.people_outline,
        ),
        CampusSearchableDropdownItem(
          value: '20+ seats',
          label: '20+ seats',
          subtitle: 'Small room (20+ seats)',
          icon: Icons.people,
          iconColor: Color(0xFF3B82F6),
        ),
        CampusSearchableDropdownItem(
          value: '40+ seats',
          label: '40+ seats',
          subtitle: 'Medium classroom (40+ seats)',
          icon: Icons.people,
          iconColor: Color(0xFF3B82F6),
        ),
        CampusSearchableDropdownItem(
          value: '60+ seats',
          label: '60+ seats',
          subtitle: 'Large lab/lecture hall (60+ seats)',
          icon: Icons.groups_outlined,
          iconColor: Color(0xFF10B981),
        ),
        CampusSearchableDropdownItem(
          value: '100+ seats',
          label: '100+ seats',
          subtitle: 'Auditorium / Center (100+ seats)',
          icon: Icons.groups,
          iconColor: Color(0xFFF59E0B),
        ),
        CampusSearchableDropdownItem(
          value: '200+ seats',
          label: '200+ seats',
          subtitle: 'Major hall / Ground (200+ seats)',
          icon: Icons.diversity_3,
          iconColor: Color(0xFF8B5CF6),
        ),
        CampusSearchableDropdownItem(
          value: '500+ seats',
          label: '500+ seats',
          subtitle: 'Stadium / Grand venue (500+ seats)',
          icon: Icons.stadium,
          iconColor: Color(0xFFEF4444),
        ),
      ],
      onChanged: (val) {
        notifier.applyQuickFilters(capacity: val);
      },
    );
  }

  Widget _buildTimelineListToggle(
    SpaceBookingState state,
    SpaceBookingNotifier notifier,
    bool isDark,
    Color cardBorder,
    Color textSecondary,
  ) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => notifier.setDisplayMode('Timeline'),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: state.displayMode == 'Timeline' ? const Color(0xFF2563EB) : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.view_timeline_outlined,
                    size: 15,
                    color: state.displayMode == 'Timeline' ? Colors.white : textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Timeline',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: state.displayMode == 'Timeline' ? Colors.white : textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: () => notifier.setDisplayMode('List'),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: state.displayMode == 'List' ? const Color(0xFF2563EB) : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.format_list_bulleted,
                    size: 15,
                    color: state.displayMode == 'List' ? Colors.white : textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'List',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: state.displayMode == 'List' ? Colors.white : textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _parseTimeToLeft(String timeStr) {
    try {
      final clean = timeStr.trim().toUpperCase();
      final isPM = clean.contains('PM');
      final isAM = clean.contains('AM');
      final timePart = clean.replaceAll(RegExp(r'[^\d:]'), '');
      final parts = timePart.split(':');
      if (parts.isNotEmpty) {
        int hour = int.parse(parts[0]);
        int minute = parts.length > 1 ? int.parse(parts[1]) : 0;
        if (isPM && hour < 12) hour += 12;
        if (isAM && hour == 12) hour = 0;

        final totalMinutes = hour * 60 + minute;
        const startOfDayMinutes = 8 * 60; // 08:00 AM
        final offsetMinutes = totalMinutes - startOfDayMinutes;
        final double left = (offsetMinutes / 60.0) * 62.0;
        return left.clamp(0.0, 560.0);
      }
    } catch (_) {}
    return 0.0;
  }

  Widget _buildBookingChip(SpaceTimelineBooking b, SpaceTimelineRoom room, bool isDark) {
    final double left = _parseTimeToLeft(b.startTime);
    final double width = math.max(50.0, (b.durationMinutes / 60.0) * 62.0 - 4);

    // Theme adaptive colors
    Color bg = isDark ? const Color(0xFF0369A1).withValues(alpha: 0.35) : const Color(0xFFE0F2FE);
    Color text = isDark ? const Color(0xFFBAE6FD) : const Color(0xFF0369A1);
    Color border = isDark ? const Color(0xFF0284C7) : const Color(0xFFBAE6FD);

    final titleLower = b.title.toLowerCase();
    if (titleLower.contains('practical') || titleLower.contains('ai in education') || titleLower.contains('training')) {
      bg = isDark ? const Color(0xFF7E22CE).withValues(alpha: 0.35) : const Color(0xFFF3E8FF);
      text = isDark ? const Color(0xFFE9D5FF) : const Color(0xFF7E22CE);
      border = isDark ? const Color(0xFF9333EA) : const Color(0xFFE9D5FF);
    } else if (titleLower.contains('meeting') || titleLower.contains('club')) {
      bg = isDark ? const Color(0xFF15803D).withValues(alpha: 0.35) : const Color(0xFFDCFCE7);
      text = isDark ? const Color(0xFFBBF7D0) : const Color(0xFF15803D);
      border = isDark ? const Color(0xFF16A34A) : const Color(0xFFBBF7D0);
    } else if (titleLower.contains('workshop')) {
      bg = isDark ? const Color(0xFFB45309).withValues(alpha: 0.35) : const Color(0xFFFEF3C7);
      text = isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309);
      border = isDark ? const Color(0xFFD97706) : const Color(0xFFFDE68A);
    } else if (titleLower.contains('exam')) {
      bg = isDark ? const Color(0xFFBE123C).withValues(alpha: 0.35) : const Color(0xFFFFE4E6);
      text = isDark ? const Color(0xFFFECDD3) : const Color(0xFFBE123C);
      border = isDark ? const Color(0xFFE11D48) : const Color(0xFFFECDD3);
    }

    return Positioned(
      left: left,
      top: 6,
      bottom: 6,
      width: width,
      child: Tooltip(
        message: '${b.title}\n${b.startTime} - ${b.endTime}\nOrganizer: ${b.organizerName}',
        child: InkWell(
          onTap: () {
            if (widget.onInspectRequest != null) {
              widget.onInspectRequest!(SpaceBookingRequestItem(
                id: b.id,
                bookingRef: b.bookingRef.isNotEmpty ? b.bookingRef : 'SB-${b.id.length > 8 ? b.id.substring(0, 8) : b.id}',
                title: b.title,
                purpose: b.purpose.isNotEmpty ? b.purpose : 'Academic Booking',
                category: 'Academic',
                priority: 'Normal',
                status: b.status,
                isApproved: b.status.toLowerCase() == 'confirmed' || b.status.toLowerCase() == 'approved',
                bookingDate: b.startDatetime != null ? DateFormat('d MMM yyyy').format(b.startDatetime!) : '20 Mar 2026',
                startTime: b.startTime,
                endTime: b.endTime,
                formattedSchedule: '${b.startTime} - ${b.endTime}',
                roomId: room.roomId,
                roomName: room.roomName.isNotEmpty ? room.roomName : 'Room ${room.roomNumber}',
                roomType: room.roomType.isNotEmpty ? room.roomType : 'Classroom',
                spaceDisplay: '${room.roomNumber} - ${room.roomName}',
                buildingId: room.buildingId,
                buildingName: room.buildingName.isNotEmpty ? room.buildingName : 'Academic Block',
                organizerName: b.organizerName.isNotEmpty ? b.organizerName : 'Faculty',
                organizerRole: b.organizerRole.isNotEmpty ? b.organizerRole : 'Organizer',
                requestedByDisplay: '${b.organizerName} (${b.organizerRole})',
                attendeeCount: room.capacity > 0 ? room.capacity : 30,
                isRecurring: false,
              ));
            }
          },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  b.title,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${b.startTime} - ${b.endTime}',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                    color: text.withValues(alpha: 0.85),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // LOWER BLOCK: BOOKING REQUESTS (28) TABLE
  // ==========================================================================

  String _getBookingRequestsTitle(SpaceBookingState state) {
    final count = state.bookingRequests.totalCount;
    if (state.statusFilter == 'All') {
      return 'All Bookings ($count)';
    } else if (state.statusFilter == 'Approved') {
      return 'Approved Bookings ($count)';
    } else if (state.statusFilter == 'Rejected') {
      return 'Rejected Bookings ($count)';
    } else if (state.statusFilter == 'Cancelled') {
      return 'Cancelled Bookings ($count)';
    } else {
      return 'Booking Requests ($count)';
    }
  }

  Widget _buildBookingRequestsBlock(SpaceBookingState state, SpaceBookingNotifier notifier, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final headerBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Title and Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.assignment_outlined, size: 20, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 8),
                    Text(
                      _getBookingRequestsTitle(state),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),

                // Status Tabs: All | Pending | Approved | Rejected
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStatusTab('All (${state.kpis.totalBookings})', 'All', state, notifier, isDark),
                      _buildStatusTab('Pending (${state.kpis.pendingBookings})', 'Pending', state, notifier, isDark),
                      _buildStatusTab('Approved (${state.kpis.confirmedBookings})', 'Approved', state, notifier, isDark),
                      _buildStatusTab('Rejected (${state.kpis.rejectedBookings})', 'Rejected', state, notifier, isDark),
                      _buildStatusTab('Cancelled (${state.kpis.cancelledBookings})', 'Cancelled', state, notifier, isDark),
                      _buildStatusTab('Conflicts', 'Conflict', state, notifier, isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(color: cardBorder, height: 1),

          // Search & Multi-Facet Filters Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, fltConstraints) {
                    final isCompact = fltConstraints.maxWidth < 900;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Search Input
                        SizedBox(
                          width: isCompact ? fltConstraints.maxWidth : 300,
                          height: 34,
                          child: TextField(
                            controller: _requestSearchCtrl,
                            style: TextStyle(fontSize: 12.5, color: textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Search title, ref, requester, room...',
                              hintStyle: TextStyle(fontSize: 12, color: textSecondary),
                              prefixIcon: Icon(Icons.search_rounded, size: 16, color: textSecondary),
                              suffixIcon: _requestSearchCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 14),
                                      color: textSecondary,
                                      onPressed: () {
                                        _requestSearchCtrl.clear();
                                        notifier.setSearchQuery('');
                                      },
                                    )
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: cardBorder),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
                              ),
                            ),
                            onSubmitted: (val) => notifier.setSearchQuery(val),
                            onChanged: (val) {
                              setState(() {});
                            },
                          ),
                        ),

                        // Building Dropdown
                        _buildSmallDropdown(
                          label: 'Building: All',
                          value: state.selectedBuildingId,
                          isDark: isDark,
                          items: [
                            const DropdownMenuItem(value: 'all', child: Text('Building: All')),
                            ...ref.watch(campusProvider).buildings.map(
                                  (b) => DropdownMenuItem(
                                    value: b.id,
                                    child: Text('Building: ${b.code} - ${b.name}'),
                                  ),
                                ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              notifier.setBuildingFilter(val);
                            }
                          },
                        ),

                        // Space Type Dropdown
                        _buildSmallDropdown(
                          label: 'Space Type: All',
                          value: state.selectedSpaceType,
                          isDark: isDark,
                          items: const [
                            DropdownMenuItem(value: 'All', child: Text('Space Type: All')),
                            DropdownMenuItem(value: 'Classroom', child: Text('Classroom')),
                            DropdownMenuItem(value: 'Lab', child: Text('Lab')),
                            DropdownMenuItem(value: 'Auditorium', child: Text('Auditorium')),
                            DropdownMenuItem(value: 'Seminar Hall', child: Text('Seminar Hall')),
                            DropdownMenuItem(value: 'Meeting Room', child: Text('Meeting Room')),
                            DropdownMenuItem(value: 'Sports Facility', child: Text('Sports Facility')),
                            DropdownMenuItem(value: 'Library Hall', child: Text('Library Hall')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              notifier.setSpaceTypeFilter(val);
                            }
                          },
                        ),

                        // Purpose Dropdown
                        _buildSmallDropdown(
                          label: 'Purpose: All',
                          value: state.selectedPurpose,
                          isDark: isDark,
                          items: const [
                            DropdownMenuItem(value: 'All', child: Text('Purpose: All')),
                            DropdownMenuItem(value: 'Academic', child: Text('Academic')),
                            DropdownMenuItem(value: 'Workshop', child: Text('Workshop')),
                            DropdownMenuItem(value: 'Exam', child: Text('Exam')),
                            DropdownMenuItem(value: 'Club Activity', child: Text('Club Activity')),
                            DropdownMenuItem(value: 'Faculty Meeting', child: Text('Faculty Meeting')),
                            DropdownMenuItem(value: 'Cultural Event', child: Text('Cultural Event')),
                            DropdownMenuItem(value: 'Sports Event', child: Text('Sports Event')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              notifier.setPurposeFilter(val);
                            }
                          },
                        ),

                        // Date Range Filter Button
                        _buildRequestsDateRangeButton(state, notifier, isDark),

                        // Search Apply Button
                        InkWell(
                          onTap: () => notifier.setSearchQuery(_requestSearchCtrl.text.trim()),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 34,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search, size: 14, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'Search',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                // Active Filter Badges & Reset
                if (state.searchQuery.isNotEmpty ||
                    (state.selectedBuildingId.isNotEmpty && state.selectedBuildingId != 'all') ||
                    (state.selectedSpaceType.isNotEmpty && state.selectedSpaceType != 'All') ||
                    (state.selectedPurpose.isNotEmpty && state.selectedPurpose != 'All') ||
                    state.dateRangeFrom != null) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('Active Filters:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textSecondary)),
                      ..._buildActiveFilterChips(state, notifier, isDark),
                      InkWell(
                        onTap: () {
                          _requestSearchCtrl.clear();
                          notifier.clearAllRequestsFilters();
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.restart_alt_rounded, size: 13, color: Color(0xFFEF4444)),
                              SizedBox(width: 4),
                              Text('Clear All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Divider(color: cardBorder, height: 1),

          // Scrollable Table Block (Header + Rows)
          LayoutBuilder(
            builder: (context, tblConstraints) {
              final tableWidth = (tblConstraints.maxWidth.isFinite && tblConstraints.maxWidth > 850)
                  ? tblConstraints.maxWidth
                  : 850.0;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Server-Side Sortable Table Header
                      Container(
                        height: 36,
                        color: headerBg,
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            SizedBox(width: 32, child: Text('#', style: _thStyle(textSecondary))),
                            _buildSortableHeader('Request Title', 'title', 3, textSecondary, state, notifier),
                            _buildSortableHeader('Space', 'space', 3, textSecondary, state, notifier),
                            _buildSortableHeader('Requested By', 'organizer_name', 3, textSecondary, state, notifier),
                            _buildSortableHeader('Date & Time', 'booking_date', 4, textSecondary, state, notifier),
                            _buildSortableHeader('Purpose', 'purpose', 2, textSecondary, state, notifier),
                            _buildSortableHeader('Status', 'status', 2, textSecondary, state, notifier),
                            SizedBox(width: 120, child: Text('Actions', style: _thStyle(textSecondary))),
                          ],
                        ),
                      ),
                      Divider(color: cardBorder, height: 1),

                      // Table Body Rows
                      if (state.isLoading)
                        const Padding(
                          padding: EdgeInsets.all(40.0),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (state.bookingRequests.items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.inbox_outlined, size: 40, color: textSecondary.withValues(alpha: 0.4)),
                                const SizedBox(height: 8),
                                Text(
                                  'No space booking requests match current filters.',
                                  style: TextStyle(color: textSecondary, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...state.bookingRequests.items.asMap().entries.map((entry) {
                          final idx = (state.currentPage - 1) * state.pageSize + entry.key + 1;
                          final item = entry.value;
                          return _buildRequestRow(idx, item, notifier, isDark);
                        }),
                    ],
                  ),
                ),
              );
            },
          ),

          Divider(color: cardBorder, height: 1),

          // Pagination Bar
          _buildPaginationBar(state, notifier, isDark),
        ],
      ),
    );
  }

  TextStyle _thStyle(Color color) => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: color,
  );

  Widget _buildSortableHeader(String title, String colKey, int flex, Color color, SpaceBookingState state, SpaceBookingNotifier notifier) {
    final isCurrent = state.sortBy.toLowerCase() == colKey.toLowerCase();
    final isAsc = state.sortOrder.toUpperCase() == 'ASC';
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () => notifier.setSorting(colKey),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: _thStyle(isCurrent ? const Color(0xFF3B82F6) : color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                isCurrent
                    ? (isAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                    : Icons.unfold_more_rounded,
                size: 14,
                color: isCurrent ? const Color(0xFF3B82F6) : color.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestsDateRangeButton(SpaceBookingState state, SpaceBookingNotifier notifier, bool isDark) {
    String dateLabel = 'Date: All';
    if (state.dateRangeFrom != null && state.dateRangeTo != null) {
      if (state.dateRangeFrom == state.dateRangeTo) {
        dateLabel = DateFormat('dd MMM').format(state.dateRangeFrom!);
      } else {
        dateLabel = '${DateFormat('dd MMM').format(state.dateRangeFrom!)} - ${DateFormat('dd MMM').format(state.dateRangeTo!)}';
      }
    } else if (state.dateRangeFrom != null) {
      dateLabel = 'From: ${DateFormat('dd MMM').format(state.dateRangeFrom!)}';
    }

    final hasDateFilter = state.dateRangeFrom != null;

    return PopupMenuButton<String>(
      tooltip: 'Filter by Date Range',
      onSelected: (val) async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        if (val == 'all') {
          notifier.clearDateRangeFilter();
        } else if (val == 'today') {
          notifier.setRequestsDateRange(today, today);
        } else if (val == 'tomorrow') {
          final tomorrow = today.add(const Duration(days: 1));
          notifier.setRequestsDateRange(tomorrow, tomorrow);
        } else if (val == 'week') {
          notifier.setRequestsDateRange(today, today.add(const Duration(days: 7)));
        } else if (val == 'month') {
          final start = DateTime(today.year, today.month, 1);
          final end = DateTime(today.year, today.month + 1, 0);
          notifier.setRequestsDateRange(start, end);
        } else if (val == 'custom') {
          final range = await showDateRangePicker(
            context: context,
            firstDate: DateTime(now.year - 1),
            lastDate: DateTime(now.year + 2),
            initialDateRange: (state.dateRangeFrom != null && state.dateRangeTo != null)
                ? DateTimeRange(start: state.dateRangeFrom!, end: state.dateRangeTo!)
                : null,
          );
          if (range != null) {
            notifier.setRequestsDateRange(range.start, range.end);
          }
        }
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem(value: 'all', child: Text('All Dates')),
        const PopupMenuItem(value: 'today', child: Text('Today')),
        const PopupMenuItem(value: 'tomorrow', child: Text('Tomorrow')),
        const PopupMenuItem(value: 'week', child: Text('Next 7 Days')),
        const PopupMenuItem(value: 'month', child: Text('This Month')),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'custom',
          child: Row(
            children: [
              Icon(Icons.date_range, size: 16),
              SizedBox(width: 8),
              Text('Custom Range...'),
            ],
          ),
        ),
      ],
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: hasDateFilter
              ? const Color(0xFF2563EB).withValues(alpha: isDark ? 0.25 : 0.1)
              : (isDark ? const Color(0xFF0F172A) : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasDateFilter ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_month_outlined,
              size: 15,
              color: hasDateFilter ? const Color(0xFF3B82F6) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 6),
            Text(
              dateLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: hasDateFilter ? FontWeight.w600 : FontWeight.w500,
                color: hasDateFilter ? const Color(0xFF3B82F6) : (isDark ? Colors.white : const Color(0xFF1E293B)),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActiveFilterChips(SpaceBookingState state, SpaceBookingNotifier notifier, bool isDark) {
    final chips = <Widget>[];

    if (state.searchQuery.isNotEmpty) {
      chips.add(_buildFilterChip(
        label: 'Search: "${state.searchQuery}"',
        onDeleted: () {
          _requestSearchCtrl.clear();
          notifier.setSearchQuery('');
        },
        isDark: isDark,
      ));
    }

    if (state.selectedBuildingId.isNotEmpty && state.selectedBuildingId != 'all') {
      final bName = ref.watch(campusProvider).buildings.cast<dynamic>().firstWhere(
            (b) => b.id == state.selectedBuildingId,
            orElse: () => null,
          )?.name ?? state.selectedBuildingId;
      chips.add(_buildFilterChip(
        label: 'Building: $bName',
        onDeleted: () => notifier.setBuildingFilter('all'),
        isDark: isDark,
      ));
    }

    if (state.selectedSpaceType.isNotEmpty && state.selectedSpaceType != 'All') {
      chips.add(_buildFilterChip(
        label: 'Type: ${state.selectedSpaceType}',
        onDeleted: () => notifier.setSpaceTypeFilter('All'),
        isDark: isDark,
      ));
    }

    if (state.selectedPurpose.isNotEmpty && state.selectedPurpose != 'All') {
      chips.add(_buildFilterChip(
        label: 'Purpose: ${state.selectedPurpose}',
        onDeleted: () => notifier.setPurposeFilter('All'),
        isDark: isDark,
      ));
    }

    if (state.dateRangeFrom != null || state.dateRangeTo != null) {
      final fromStr = state.dateRangeFrom != null ? DateFormat('dd MMM').format(state.dateRangeFrom!) : '';
      final toStr = state.dateRangeTo != null ? DateFormat('dd MMM').format(state.dateRangeTo!) : '';
      final label = (state.dateRangeFrom != null && state.dateRangeTo != null)
          ? 'Date: $fromStr - $toStr'
          : 'Date: $fromStr';
      chips.add(_buildFilterChip(
        label: label,
        onDeleted: () => notifier.clearDateRangeFilter(),
        isDark: isDark,
      ));
    }

    return chips;
  }

  Widget _buildFilterChip({required String label, required VoidCallback onDeleted, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.2 : 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF3B82F6)),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onDeleted,
            child: const Icon(Icons.close_rounded, size: 13, color: Color(0xFF3B82F6)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTab(String label, String statusKey, SpaceBookingState state, SpaceBookingNotifier notifier, bool isDark) {
    final isSel = state.statusFilter == statusKey;
    final selBg = isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.5) : const Color(0xFFEFF6FF);
    final selBorder = isDark ? const Color(0xFF3B82F6) : const Color(0xFFBFDBFE);
    final selText = isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB);
    final unselText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: InkWell(
        onTap: () => notifier.setStatusFilter(statusKey),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSel ? selBg : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: isSel ? Border.all(color: selBorder) : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
              color: isSel ? selText : unselText,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestRow(int idx, SpaceBookingRequestItem item, SpaceBookingNotifier notifier, bool isDark) {
    final rowBorder = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: rowBorder, width: 1)),
      ),
      child: Row(
        children: [
          // Index #
          SizedBox(
            width: 28,
            child: Text(
              '$idx',
              style: TextStyle(fontSize: 11.5, color: textSecondary, fontWeight: FontWeight.w500),
            ),
          ),

          // Request Title
          Expanded(
            flex: 3,
            child: Text(
              item.title,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Space
          Expanded(
            flex: 3,
            child: Text(
              item.spaceDisplay,
              style: TextStyle(fontSize: 11.5, color: textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Requested By
          Expanded(
            flex: 3,
            child: Text(
              item.requestedByDisplay,
              style: TextStyle(fontSize: 11.5, color: textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Date & Time
          Expanded(
            flex: 4,
            child: Text(
              item.formattedSchedule,
              style: TextStyle(fontSize: 11.5, color: textMuted, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Purpose
          Expanded(
            flex: 2,
            child: Text(
              item.purpose,
              style: TextStyle(fontSize: 11.5, color: textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Status Badge
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: item.status == 'Pending'
                      ? (isDark ? const Color(0xFF78350F).withValues(alpha: 0.5) : const Color(0xFFFEF3C7))
                      : item.status == 'Approved' || item.status == 'Confirmed'
                          ? (isDark ? const Color(0xFF065F46).withValues(alpha: 0.5) : const Color(0xFFDCFCE7))
                          : item.status == 'Cancelled'
                              ? (isDark ? const Color(0xFF334155).withValues(alpha: 0.5) : const Color(0xFFF1F5F9))
                              : item.status == 'Conflict'
                                  ? (isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.6) : const Color(0xFFFFE4E6))
                                  : (isDark ? const Color(0xFF991B1B).withValues(alpha: 0.5) : const Color(0xFFFEE2E2)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  item.status,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: item.status == 'Pending'
                        ? (isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309))
                        : item.status == 'Approved' || item.status == 'Confirmed'
                            ? (isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D))
                            : item.status == 'Cancelled'
                                ? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))
                                : item.status == 'Conflict'
                                    ? (isDark ? const Color(0xFFFDA4AF) : const Color(0xFFBE123C))
                                    : (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C)),
                  ),
                ),
              ),
            ),
          ),

          // Actions
          SizedBox(
            width: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (item.status == 'Pending' || item.status == 'Submitted') ...[
                  // Approve
                  Tooltip(
                    message: 'Approve Request',
                    child: InkWell(
                      onTap: () async {
                        final res = await notifier.decideApprovalDetailed(item.id, 'APPROVE');
                        if (!mounted) return;
                        if (res['success'] == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Approved "${item.title}" successfully'),
                              backgroundColor: const Color(0xFF059669),
                            ),
                          );
                        } else if (res['conflict'] == true) {
                          showDialog(
                            context: context,
                            builder: (ctx) => SpaceConflictWarningDialog(
                              roomName: item.spaceDisplay,
                              requestedTime: '${item.bookingDate} (${item.startTime} - ${item.endTime})',
                              conflictMessage: res['message']?.toString() ?? 'Cannot approve: Space is already booked during this time slot.',
                              onChangeTime: () {
                                if (widget.onEditRequest != null) {
                                  widget.onEditRequest!(item);
                                } else {
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (dCtx) => CreateEditBookingDialog(
                                      initialItem: item,
                                      onSaved: () => ref.read(spaceBookingProvider.notifier).loadAll(),
                                    ),
                                  );
                                }
                              },
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res['message']?.toString() ?? 'Failed to approve booking'),
                              backgroundColor: const Color(0xFFEF4444),
                            ),
                          );
                        }
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(3.0),
                        child: Icon(Icons.check, size: 15, color: Color(0xFF16A34A)),
                      ),
                    ),
                  ),
                  // Reject
                  Tooltip(
                    message: 'Reject Request',
                    child: InkWell(
                      onTap: () async {
                        final ok = await notifier.decideApproval(item.id, 'REJECT');
                        if (ok && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Rejected "${item.title}"')),
                          );
                        }
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(3.0),
                        child: Icon(Icons.close, size: 15, color: Color(0xFFEF4444)),
                      ),
                    ),
                  ),
                ],
                // Edit
                Tooltip(
                  message: 'Modify Schedule',
                  child: InkWell(
                    onTap: () {
                      if (widget.onEditRequest != null) {
                        widget.onEditRequest!(item);
                      } else if (widget.onInspectRequest != null) {
                        widget.onInspectRequest!(item);
                      }
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(3.0),
                      child: Icon(Icons.edit_outlined, size: 15, color: Color(0xFF3B82F6)),
                    ),
                  ),
                ),
                // Delete
                Tooltip(
                  message: 'Delete Schedule',
                  child: InkWell(
                    onTap: () {
                      if (widget.onDeleteRequest != null) {
                        widget.onDeleteRequest!(item);
                      }
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(3.0),
                      child: Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFEF4444)),
                    ),
                  ),
                ),
                // Inspect
                Tooltip(
                  message: 'View Details',
                  child: InkWell(
                    onTap: () {
                      if (widget.onInspectRequest != null) {
                        widget.onInspectRequest!(item);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(3.0),
                      child: Icon(Icons.remove_red_eye_outlined, size: 15, color: textSecondary),
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

  Widget _buildPaginationBar(SpaceBookingState state, SpaceBookingNotifier notifier, bool isDark) {
    return CampusPaginationBar(
      currentPage: state.currentPage,
      pageSize: state.pageSize,
      totalItems: state.bookingRequests.totalCount,
      onPageChanged: (newPage) => notifier.setPage(newPage),
      onPageSizeChanged: (newSize) => notifier.setPageSize(newSize),
      itemLabel: 'requests',
    );
  }

  // ==========================================================================
  // VIEW 4: USAGE & REPORTS SCREEN (ADVANCED 10X GRAPH PRESENTATION)
  // ==========================================================================

  Widget _buildUsageAndReportsScreen(SpaceBookingState state, SpaceBookingNotifier notifier, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final rep = state.analyticsReport;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header with Title and Timeframe Filter Pills
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.analytics_outlined, size: 22, color: Color(0xFF3B82F6)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Space Utilization & Advanced Analytics',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      'Live institutional facility occupancy, peak load traffic curves, and space distribution',
                      style: TextStyle(fontSize: 11.5, color: textSecondary),
                    ),
                  ],
                ),
              ),
              // Timeframe filter pills
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    _buildTimeframePill('today', 'Today', isDark),
                    _buildTimeframePill('week', 'This Week', isDark),
                    _buildTimeframePill('month', 'This Month', isDark),
                    _buildTimeframePill('term', 'Term', isDark),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 2. Executive KPI Summary Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 720;
              final cards = [
                _buildUsageStatBox(
                  'Peak Occupancy Window',
                  rep.peakHourLabel,
                  'High congestion window',
                  const Color(0xFF3B82F6),
                  Icons.access_time_rounded,
                  isDark,
                ),
                _buildUsageStatBox(
                  'Total Booked Hours',
                  '${rep.totalBookedHours.toStringAsFixed(rep.totalBookedHours % 1 == 0 ? 0 : 1)} Hours',
                  '${rep.totalBookings} reservation${rep.totalBookings == 1 ? "" : "s"}',
                  const Color(0xFF10B981),
                  Icons.timelapse_rounded,
                  isDark,
                ),
                _buildUsageStatBox(
                  'Avg Session Duration',
                  '${rep.avgDurationMinutes.toStringAsFixed(0)} Minutes',
                  'Per confirmed reservation',
                  const Color(0xFF8B5CF6),
                  Icons.hourglass_bottom_rounded,
                  isDark,
                ),
                _buildUsageStatBox(
                  'Campus Space Utilization',
                  '${rep.overallUtilizationPct.toStringAsFixed(1)}%',
                  '${rep.activeSpacesCount} Active / ${rep.totalSpacesCount} Bookable Spaces',
                  const Color(0xFF06B6D4),
                  Icons.pie_chart_outline_rounded,
                  isDark,
                ),
              ];

              if (isWide) {
                return Row(
                  children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: c))).toList(),
                );
              } else {
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: cards.map((c) => SizedBox(width: (constraints.maxWidth - 10) / 2, child: c)).toList(),
                );
              }
            },
          ),
          const SizedBox(height: 22),

          // 3. Row 1 Charts: Hourly Occupancy Area Chart + Today's Space Utilization Donut
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 820;

              final hourlyChartCard = _buildChartContainer(
                title: 'Hourly Space Occupancy & Traffic Curve',
                subtitle: 'Active concurrent session volume across campus (8:00 AM - 6:00 PM)',
                icon: Icons.show_chart_rounded,
                isDark: isDark,
                child: HourlyOccupancyChart(
                  data: rep.hourlyOccupancy,
                  isDark: isDark,
                ),
              );

              final todayUtilizationCard = _buildChartContainer(
                title: "Today's Space Utilization",
                subtitle: 'Live institutional facility status & occupancy breakdown',
                icon: Icons.pie_chart_outline_rounded,
                isDark: isDark,
                child: TodaySpaceUtilizationDonutChart(
                  stats: state.utilization,
                  isDark: isDark,
                ),
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: hourlyChartCard),
                    const SizedBox(width: 14),
                    Expanded(flex: 2, child: todayUtilizationCard),
                  ],
                );
              } else {
                return Column(
                  children: [
                    hourlyChartCard,
                    const SizedBox(height: 14),
                    todayUtilizationCard,
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 16),

          // 4. Row 2 Charts: Space Type Breakdown + Day of Week Bar Chart
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 820;

              final donutChartCard = _buildChartContainer(
                title: 'Space Type Breakdown',
                subtitle: 'Facility distribution by instructional category',
                icon: Icons.donut_large_rounded,
                isDark: isDark,
                child: SpaceTypeDonutChart(
                  items: rep.spaceTypeBreakdown,
                  totalSpaces: rep.totalSpacesCount,
                  isDark: isDark,
                ),
              );

              final dayOfWeekCard = _buildChartContainer(
                title: 'Day-of-Week Occupancy Load',
                subtitle: 'Weekly campus facility utilization percentage (Monday to Saturday)',
                icon: Icons.bar_chart_rounded,
                isDark: isDark,
                child: DayOfWeekBarChart(
                  days: rep.dayOfWeekTraffic,
                  isDark: isDark,
                ),
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: donutChartCard),
                    const SizedBox(width: 14),
                    Expanded(child: dayOfWeekCard),
                  ],
                );
              } else {
                return Column(
                  children: [
                    donutChartCard,
                    const SizedBox(height: 14),
                    dayOfWeekCard,
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 16),

          // 5. Row 3: Building-wise Utilization Matrix
          _buildChartContainer(
            title: 'Building-wise Utilization Matrix',
            subtitle: 'Occupancy capacity ratios across institutional facilities',
            icon: Icons.apartment_rounded,
            isDark: isDark,
            child: BuildingUtilizationList(
              buildings: rep.buildingUtilization,
              isDark: isDark,
            ),
          ),
          const SizedBox(height: 24),

          // 5. Active Spaces Overview Feed
          Row(
            children: [
              Text(
                'Active Spaces Real-Time Roster',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary),
              ),
              const Spacer(),
              Text(
                'Showing ${state.roomsTimeline.take(8).length} campus facilities',
                style: TextStyle(fontSize: 11.5, color: textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.roomsTimeline.take(8).length,
            separatorBuilder: (_, __) => Divider(color: cardBorder, height: 1),
            itemBuilder: (context, index) {
              final r = state.roomsTimeline[index];
              final hasBookings = r.bookings.isNotEmpty;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                  child: const Icon(Icons.meeting_room_outlined, size: 18, color: Color(0xFF3B82F6)),
                ),
                title: Text(
                  '${r.roomNumber} - ${r.roomName}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary),
                ),
                subtitle: Text(
                  '${r.roomType} • Capacity: ${r.capacity} seats • ${r.buildingName}',
                  style: TextStyle(fontSize: 11, color: textSecondary),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasBookings
                        ? const Color(0xFF10B981).withValues(alpha: 0.12)
                        : const Color(0xFF06B6D4).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    hasBookings
                        ? '${r.bookings.length} ${r.bookings.length == 1 ? "Session" : "Sessions"} Active'
                        : 'Available',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: hasBookings ? const Color(0xFF10B981) : const Color(0xFF06B6D4),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTimeframePill(String code, String label, bool isDark) {
    final isSel = _analyticsTimeframe == code;
    return InkWell(
      onTap: () {
        setState(() => _analyticsTimeframe = code);
        ref.read(spaceBookingProvider.notifier).loadAnalyticsReport(timeframe: code);
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
            color: isSel ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  Widget _buildChartContainer({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
    required bool isDark,
  }) {
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final bg = isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF8FAFC);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF3B82F6)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 10.5, color: textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildUsageStatBox(
    String label,
    String value,
    String sub,
    Color color,
    IconData icon,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
