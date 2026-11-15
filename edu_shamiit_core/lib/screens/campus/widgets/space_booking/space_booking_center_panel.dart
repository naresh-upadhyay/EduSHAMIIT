import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/space_booking_models.dart';
import '../../providers/space_booking_provider.dart';

class SpaceBookingCenterPanel extends ConsumerStatefulWidget {
  final Function(SpaceBookingRequestItem item)? onInspectRequest;

  const SpaceBookingCenterPanel({
    super.key,
    this.onInspectRequest,
  });

  @override
  ConsumerState<SpaceBookingCenterPanel> createState() => _SpaceBookingCenterPanelState();
}

class _SpaceBookingCenterPanelState extends ConsumerState<SpaceBookingCenterPanel> {
  String _timelineBuilding = 'b1';
  String _timelineSpaceType = 'All';
  String _timelineStatus = 'All';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(spaceBookingProvider);
    final notifier = ref.read(spaceBookingProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Upper Block: Space Availability & Booking
        _buildAvailabilityBlock(state, notifier, isDark),
        const SizedBox(height: 16),

        // Lower Block: Booking Requests Table
        _buildBookingRequestsBlock(state, notifier, isDark),
      ],
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
                    const SizedBox(width: 12),

                    // Date Navigator: < Mon, 15 Mar 2026 >
                    Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
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
                            onPressed: () {
                              notifier.changeDate(state.selectedDate.subtract(const Duration(days: 1)));
                            },
                          ),
                          const Icon(Icons.calendar_month, size: 15, color: Color(0xFF3B82F6)),
                          const SizedBox(width: 6),
                          Text(
                            'Mon, 15 Mar 2026',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.chevron_right, size: 18, color: textSecondary),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 24),
                            onPressed: () {
                              notifier.changeDate(state.selectedDate.add(const Duration(days: 1)));
                            },
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
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _buildSmallDropdown(
                      label: 'Building: B1 - Academic Block',
                      value: _timelineBuilding,
                      isDark: isDark,
                      items: const [
                        DropdownMenuItem(value: 'b1', child: Text('Building: B1 - Academic Block')),
                        DropdownMenuItem(value: 'all', child: Text('Building: All Buildings')),
                        DropdownMenuItem(value: 'b2', child: Text('Building: B2 - Senior Block')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _timelineBuilding = val);
                      },
                    ),
                    _buildSmallDropdown(
                      label: 'Space Type: All',
                      value: _timelineSpaceType,
                      isDark: isDark,
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('Space Type: All')),
                        DropdownMenuItem(value: 'Classroom', child: Text('Classroom')),
                        DropdownMenuItem(value: 'Auditorium', child: Text('Auditorium')),
                        DropdownMenuItem(value: 'Meeting Room', child: Text('Meeting Room')),
                        DropdownMenuItem(value: 'Lab', child: Text('Lab')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _timelineSpaceType = val);
                      },
                    ),
                    _buildSmallDropdown(
                      label: 'Status: All',
                      value: _timelineStatus,
                      isDark: isDark,
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('Status: All')),
                        DropdownMenuItem(value: 'Confirmed', child: Text('Confirmed')),
                        DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _timelineStatus = val);
                      },
                    ),
                  ],
                ),

                // Toggle: Timeline vs List
                Container(
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
                ),
              ],
            ),
          ),
          Divider(color: cardBorder, height: 1),

          // Interactive Timeline Grid
          _buildInteractiveGrid(state, isDark),
        ],
      ),
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
          value: value,
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          icon: Icon(Icons.keyboard_arrow_down, size: 16, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF1E293B), fontWeight: FontWeight.w500),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildInteractiveGrid(SpaceBookingState state, bool isDark) {
    final headerBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final gridLineColor = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final timeSlots = [
      '8:00 AM', '9:00 AM', '10:00 AM', '11:00 AM', '12:00 PM',
      '1:00 PM', '2:00 PM', '3:00 PM', '4:00 PM', '5:00 PM'
    ];

    final displayRooms = state.roomsTimeline.take(5).toList();

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
                    Text('Loading rooms availability...', style: TextStyle(color: textSecondary, fontSize: 13)),
                  ],
                ),
              )
            else if (displayRooms.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text('No rooms available for timeline on this date.', style: TextStyle(color: textSecondary, fontSize: 13)),
              )
            else
              ...displayRooms.map((room) => _buildTimelineRoomRow(room, timeSlots, isDark, gridLineColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineRoomRow(SpaceTimelineRoom room, List<String> slots, bool isDark, Color gridLineColor) {
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
                // Background grid vertical guide lines
                Row(
                  children: List.generate(
                    10,
                    (i) => Container(
                      width: 62,
                      decoration: BoxDecoration(
                        border: Border(right: BorderSide(color: gridLineColor)),
                      ),
                    ),
                  ),
                ),

                // Booking Event Chips
                ...room.bookings.map((b) => _buildBookingChip(b, isDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingChip(SpaceTimelineBooking b, bool isDark) {
    double left = 0;
    double width = 80;

    final s = b.startTime.toUpperCase();
    if (s.contains('08:00') || s.contains('8:00')) {
      left = 0;
    } else if (s.contains('09:00') || s.contains('9:00')) {
      left = 62;
    } else if (s.contains('10:00')) {
      left = 124;
    } else if (s.contains('11:00')) {
      left = 186;
    } else if (s.contains('12:00')) {
      left = 248;
    } else if (s.contains('01:00') || s.contains('1:00')) {
      left = 310;
    } else if (s.contains('02:00') || s.contains('2:00')) {
      left = 372;
    } else if (s.contains('02:30') || s.contains('2:30')) {
      left = 403;
    } else if (s.contains('03:00') || s.contains('3:00')) {
      left = 434;
    } else if (s.contains('04:00') || s.contains('4:00')) {
      left = 496;
    }

    width = (b.durationMinutes / 60.0) * 62.0 - 4;
    if (width < 50) width = 50;

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
    );
  }

  // ==========================================================================
  // LOWER BLOCK: BOOKING REQUESTS (28) TABLE
  // ==========================================================================

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
                      'Booking Requests (${state.kpis.pendingBookings})',
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
                      _buildStatusTab('All (${state.kpis.pendingBookings})', 'All', state, notifier, isDark),
                      _buildStatusTab('Pending (${state.kpis.pendingBookings})', 'Pending', state, notifier, isDark),
                      _buildStatusTab('Approved (${state.kpis.confirmedBookings})', 'Approved', state, notifier, isDark),
                      _buildStatusTab('Rejected (${state.kpis.rejectedBookings})', 'Rejected', state, notifier, isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(color: cardBorder, height: 1),

          // Scrollable Table Block (Header + Rows)
          LayoutBuilder(
            builder: (context, tblConstraints) {
              final tableWidth = (tblConstraints.maxWidth.isFinite && tblConstraints.maxWidth > 780)
                  ? tblConstraints.maxWidth
                  : 780.0;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Table Header
                      Container(
                        height: 38,
                        color: headerBg,
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            SizedBox(width: 25, child: Text('#', style: _thStyle(textSecondary))),
                            Expanded(flex: 3, child: Text('Request Title', style: _thStyle(textSecondary))),
                            Expanded(flex: 3, child: Text('Space', style: _thStyle(textSecondary))),
                            Expanded(flex: 3, child: Text('Requested By', style: _thStyle(textSecondary))),
                            Expanded(flex: 4, child: Text('Date & Time', style: _thStyle(textSecondary))),
                            Expanded(flex: 2, child: Text('Purpose', style: _thStyle(textSecondary))),
                            Expanded(flex: 2, child: Text('Status', style: _thStyle(textSecondary))),
                            SizedBox(width: 75, child: Text('Actions', style: _thStyle(textSecondary))),
                          ],
                        ),
                      ),
                      Divider(color: cardBorder, height: 1),

                      // Table Body Rows
                      if (state.isLoading)
                        const Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (state.bookingRequests.items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Center(child: Text('No space booking requests found.', style: TextStyle(color: textSecondary))),
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

          // Pagination Bar (SAFE BOUNDS TO PREVENT ARGUMENTERROR)
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
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: rowBorder, width: 1)),
      ),
      child: Row(
        children: [
          // Index #
          SizedBox(
            width: 25,
            child: Text(
              '$idx',
              style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w500),
            ),
          ),

          // Request Title
          Expanded(
            flex: 3,
            child: Text(
              item.title,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Space
          Expanded(
            flex: 3,
            child: Text(
              item.spaceDisplay,
              style: TextStyle(fontSize: 12.5, color: textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Requested By
          Expanded(
            flex: 3,
            child: Text(
              item.requestedByDisplay,
              style: TextStyle(fontSize: 12, color: textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Date & Time
          Expanded(
            flex: 4,
            child: Text(
              item.formattedSchedule,
              style: TextStyle(fontSize: 12, color: textMuted, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Purpose
          Expanded(
            flex: 2,
            child: Text(
              item.purpose,
              style: TextStyle(fontSize: 12, color: textSecondary),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: item.status == 'Pending'
                      ? (isDark ? const Color(0xFF78350F).withValues(alpha: 0.5) : const Color(0xFFFEF3C7))
                      : item.status == 'Approved' || item.status == 'Confirmed'
                          ? (isDark ? const Color(0xFF065F46).withValues(alpha: 0.5) : const Color(0xFFDCFCE7))
                          : (isDark ? const Color(0xFF991B1B).withValues(alpha: 0.5) : const Color(0xFFFEE2E2)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  item.status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: item.status == 'Pending'
                        ? (isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309))
                        : item.status == 'Approved' || item.status == 'Confirmed'
                            ? (isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D))
                            : (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C)),
                  ),
                ),
              ),
            ),
          ),

          // Actions
          SizedBox(
            width: 75,
            child: Row(
              children: [
                // Approve
                InkWell(
                  onTap: () async {
                    final ok = await notifier.decideApproval(item.id, 'APPROVE');
                    if (ok && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Approved "${item.title}" successfully')),
                      );
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.check, size: 16, color: Color(0xFF3B82F6)),
                  ),
                ),
                // Reject
                InkWell(
                  onTap: () async {
                    final ok = await notifier.decideApproval(item.id, 'REJECT');
                    if (ok && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Rejected "${item.title}"')),
                      );
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.close, size: 16, color: Color(0xFFEF4444)),
                  ),
                ),
                // Inspect
                InkWell(
                  onTap: () {
                    if (widget.onInspectRequest != null) {
                      widget.onInspectRequest!(item);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(Icons.remove_red_eye_outlined, size: 16, color: textSecondary),
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
    final totalCount = state.bookingRequests.totalCount;
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);

    // Guaranteed safe bounds: min is never called with invalid lower/upper limit!
    final startIdx = totalCount == 0 ? 0 : (state.currentPage - 1) * state.pageSize + 1;
    final endIdx = totalCount == 0 ? 0 : math.min(state.currentPage * state.pageSize, totalCount);

    final totalPages = state.bookingRequests.totalPages;
    final numPagesToShow = totalPages > 0 ? math.min(totalPages, 6) : 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text(
              'Showing $startIdx – $endIdx of $totalCount requests',
              style: TextStyle(fontSize: 12, color: textSecondary),
            ),
            const SizedBox(width: 24),

            // Page Buttons: « 1 2 3 4 5 6 »
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.first_page, size: 16, color: textSecondary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28),
                  onPressed: state.currentPage > 1 ? () => notifier.setPage(1) : null,
                ),
                ...List.generate(numPagesToShow, (index) {
                  final pageNum = index + 1;
                  final isCur = pageNum == state.currentPage;
                  return InkWell(
                    onTap: () => notifier.setPage(pageNum),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      width: 26,
                      height: 26,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isCur ? const Color(0xFF2563EB) : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$pageNum',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isCur ? FontWeight.w700 : FontWeight.w500,
                          color: isCur ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                        ),
                      ),
                    ),
                  );
                }),
                IconButton(
                  icon: Icon(Icons.last_page, size: 16, color: textSecondary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28),
                  onPressed: (state.currentPage < totalPages && totalPages > 1)
                      ? () => notifier.setPage(totalPages)
                      : null,
                ),
              ],
            ),
            const SizedBox(width: 14),

            // Rows per page dropdown
            Row(
              children: [
                Text('Rows per page: ', style: TextStyle(fontSize: 12, color: textSecondary)),
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: state.pageSize,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    icon: Icon(Icons.keyboard_arrow_down, size: 16, color: textSecondary),
                    style: TextStyle(fontSize: 12, color: textPrimary, fontWeight: FontWeight.w600),
                    items: const [
                      DropdownMenuItem(value: 5, child: Text('5')),
                      DropdownMenuItem(value: 10, child: Text('10')),
                      DropdownMenuItem(value: 20, child: Text('20')),
                    ],
                    onChanged: (val) {
                      if (val != null) notifier.setPageSize(val);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
