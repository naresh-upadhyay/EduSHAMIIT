import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/space_booking_models.dart';
import '../../providers/space_booking_provider.dart';

class SpaceBookingRightPanel extends ConsumerStatefulWidget {
  final VoidCallback? onOpenRecurringModal;
  final VoidCallback? onOpenManageApprovals;
  final VoidCallback? onOpenUtilizationReport;
  final bool isCompact;

  const SpaceBookingRightPanel({
    super.key,
    this.onOpenRecurringModal,
    this.onOpenManageApprovals,
    this.onOpenUtilizationReport,
    this.isCompact = false,
  });

  @override
  ConsumerState<SpaceBookingRightPanel> createState() => _SpaceBookingRightPanelState();
}

class _SpaceBookingRightPanelState extends ConsumerState<SpaceBookingRightPanel> {
  String _spaceType = 'Classroom';
  String? _selectedRoomId;
  DateTime _bookingDate = DateTime(2026, 3, 20);
  String _startTime = '02:00 PM';
  String _endTime = '04:00 PM';
  String _purpose = 'Club Activity';
  bool _isRecurring = false;
  final TextEditingController _titleController = TextEditingController(text: 'Club Activity Session');

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(spaceBookingProvider);
    final notifier = ref.read(spaceBookingProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final matchingRooms = state.bookableRooms.where((r) {
      if (_spaceType == 'Classroom') return r.roomType == 'Classroom';
      if (_spaceType == 'Auditorium') return r.roomType == 'Auditorium';
      if (_spaceType == 'Meeting Room') return r.roomType == 'Meeting Room';
      if (_spaceType == 'Lab') return r.roomType == 'Lab';
      return true;
    }).toList();

    if (_selectedRoomId == null && matchingRooms.isNotEmpty) {
      _selectedRoomId = matchingRooms.first.id;
    }

    return SizedBox(
      width: widget.isCompact ? null : 290,
      child: Column(
        children: [
          // Card 1: Book a Space Quick Form
          _buildQuickBookingCard(state, notifier, matchingRooms, isDark),
          const SizedBox(height: 16),

          // Card 2: Today's Space Utilization (Donut Chart)
          _buildUtilizationCard(state, isDark),
          const SizedBox(height: 16),

          // Card 3: Quick Actions (2x2 Grid)
          _buildQuickActionsCard(notifier, isDark),
        ],
      ),
    );
  }

  // ==========================================================================
  // CARD 1: BOOK A SPACE FORM
  // ==========================================================================

  Widget _buildQuickBookingCard(
    SpaceBookingState state,
    SpaceBookingNotifier notifier,
    List<BookableRoomItem> rooms,
    bool isDark,
  ) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final inputBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final inputBorder = isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);

    return Container(
      padding: const EdgeInsets.all(14.0),
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
          // Card Header
          Row(
            children: [
              const Icon(Icons.edit_calendar_outlined, size: 18, color: Color(0xFF3B82F6)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Book a Space',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary),
                    ),
                    Text(
                      'Create a new space booking request',
                      style: TextStyle(fontSize: 11, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Space Type *
          _buildFieldLabel('Space Type *', textSecondary),
          _buildDropdownField(
            value: _spaceType,
            isDark: isDark,
            inputBg: inputBg,
            inputBorder: inputBorder,
            items: const [
              DropdownMenuItem(value: 'Classroom', child: Text('Classroom')),
              DropdownMenuItem(value: 'Auditorium', child: Text('Auditorium')),
              DropdownMenuItem(value: 'Meeting Room', child: Text('Meeting Room')),
              DropdownMenuItem(value: 'Lab', child: Text('Lab')),
              DropdownMenuItem(value: 'Sports', child: Text('Sports')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _spaceType = val;
                  _selectedRoomId = null;
                });
              }
            },
          ),
          const SizedBox(height: 10),

          // Select Space *
          _buildFieldLabel('Select Space *', textSecondary),
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: inputBg,
              border: Border.all(color: inputBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: rooms.any((r) => r.id == _selectedRoomId) ? _selectedRoomId : (rooms.isNotEmpty ? rooms.first.id : null),
                isExpanded: true,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                hint: Text('Select Room', style: TextStyle(fontSize: 12, color: textSecondary)),
                icon: Icon(Icons.keyboard_arrow_down, size: 16, color: textSecondary),
                style: TextStyle(fontSize: 12, color: textPrimary),
                items: rooms.map((r) {
                  return DropdownMenuItem<String>(
                    value: r.id,
                    child: Text('${r.name} (Capacity: ${r.maxCapacity})'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedRoomId = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Date *
          _buildFieldLabel('Date *', textSecondary),
          InkWell(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _bookingDate,
                firstDate: DateTime(2025),
                lastDate: DateTime(2030),
              );
              if (d != null) setState(() => _bookingDate = d);
            },
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: inputBg,
                border: Border.all(color: inputBorder),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 15, color: textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    '${_bookingDate.day} Mar ${_bookingDate.year}',
                    style: TextStyle(fontSize: 12, color: textPrimary, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Start Time * and End Time * Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Start Time *', textSecondary),
                    _buildTimeDropdown(_startTime, isDark, inputBg, inputBorder, (val) {
                      if (val != null) setState(() => _startTime = val);
                    }),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('End Time *', textSecondary),
                    _buildTimeDropdown(_endTime, isDark, inputBg, inputBorder, (val) {
                      if (val != null) setState(() => _endTime = val);
                    }),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Purpose *
          _buildFieldLabel('Purpose *', textSecondary),
          _buildDropdownField(
            value: _purpose,
            isDark: isDark,
            inputBg: inputBg,
            inputBorder: inputBorder,
            items: const [
              DropdownMenuItem(value: 'Club Activity', child: Text('Club Activity')),
              DropdownMenuItem(value: 'Lecture', child: Text('Lecture')),
              DropdownMenuItem(value: 'Workshop', child: Text('Workshop')),
              DropdownMenuItem(value: 'Meeting', child: Text('Meeting')),
              DropdownMenuItem(value: 'Practical', child: Text('Practical')),
              DropdownMenuItem(value: 'Practice', child: Text('Practice')),
              DropdownMenuItem(value: 'Exam', child: Text('Exam')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _purpose = val);
            },
          ),
          const SizedBox(height: 10),

          // Recurring Booking Checkbox
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: _isRecurring,
                  activeColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  onChanged: (val) => setState(() => _isRecurring = val ?? false),
                ),
              ),
              const SizedBox(width: 8),
              Text('Recurring Booking', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155))),
              const SizedBox(width: 4),
              Icon(Icons.info_outline, size: 14, color: textSecondary),
            ],
          ),
          const SizedBox(height: 14),

          // Submit Booking Request Button
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton.icon(
              onPressed: state.isSubmitting
                  ? null
                  : () async {
                      if (_selectedRoomId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select a bookable room')),
                        );
                        return;
                      }

                      final start24 = _convert12hTo24h(_startTime);
                      final end24 = _convert12hTo24h(_endTime);

                      final payload = {
                        'title': '$_purpose in $_spaceType',
                        'room_id': _selectedRoomId,
                        'booking_date': '${_bookingDate.year}-${_bookingDate.month.toString().padLeft(2, '0')}-${_bookingDate.day.toString().padLeft(2, '0')}',
                        'start_time': start24,
                        'end_time': end24,
                        'purpose': _purpose,
                        'category': 'Academic',
                        'organizer_name': 'Rohan Verma',
                        'organizer_role': 'Student',
                        'attendee_count': 30,
                      };

                      final ok = await notifier.submitBooking(payload);
                      if (ok && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Booking request submitted successfully!')),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.send_outlined, size: 15),
              label: const Text(
                'Submit Booking Request',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _convert12hTo24h(String time12) {
    if (time12.contains('08:00')) return '08:00:00';
    if (time12.contains('09:00')) return '09:00:00';
    if (time12.contains('10:00')) return '10:00:00';
    if (time12.contains('11:00')) return '11:00:00';
    if (time12.contains('12:00')) return '12:00:00';
    if (time12.contains('01:00')) return '13:00:00';
    if (time12.contains('02:00')) return '14:00:00';
    if (time12.contains('03:00')) return '15:00:00';
    if (time12.contains('04:00')) return '16:00:00';
    if (time12.contains('05:00')) return '17:00:00';
    return '14:00:00';
  }

  Widget _buildTimeDropdown(String value, bool isDark, Color inputBg, Color inputBorder, ValueChanged<String?> onChanged) {
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: inputBg,
        border: Border.all(color: inputBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          icon: Icon(Icons.access_time, size: 15, color: textSecondary),
          style: TextStyle(fontSize: 11.5, color: textPrimary, fontWeight: FontWeight.w500),
          items: const [
            DropdownMenuItem(value: '08:00 AM', child: Text('08:00 AM')),
            DropdownMenuItem(value: '09:00 AM', child: Text('09:00 AM')),
            DropdownMenuItem(value: '10:00 AM', child: Text('10:00 AM')),
            DropdownMenuItem(value: '11:00 AM', child: Text('11:00 AM')),
            DropdownMenuItem(value: '12:00 PM', child: Text('12:00 PM')),
            DropdownMenuItem(value: '01:00 PM', child: Text('01:00 PM')),
            DropdownMenuItem(value: '02:00 PM', child: Text('02:00 PM')),
            DropdownMenuItem(value: '03:00 PM', child: Text('03:00 PM')),
            DropdownMenuItem(value: '04:00 PM', child: Text('04:00 PM')),
            DropdownMenuItem(value: '05:00 PM', child: Text('05:00 PM')),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ==========================================================================
  // CARD 2: TODAY'S SPACE UTILIZATION (DONUT CHART)
  // ==========================================================================

  Widget _buildUtilizationCard(SpaceBookingState state, bool isDark) {
    final stats = state.utilization;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.all(14.0),
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
          // Header: Title & View Report Link
          Row(
            children: [
              const Icon(Icons.pie_chart_outline, size: 17, color: Color(0xFF3B82F6)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Today's Space Utilization",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: widget.onOpenUtilizationReport,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('View Report', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF3B82F6))),
                    SizedBox(width: 2),
                    Icon(Icons.arrow_forward, size: 12, color: Color(0xFF3B82F6)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Donut Chart with Center Text
          Center(
            child: SizedBox(
              width: 140,
              height: 140,
              child: CustomPaint(
                painter: _SpaceDonutChartPainter(
                  inUsePct: stats.inUsePct / 100.0,
                  availPct: stats.availablePct / 100.0,
                  maintPct: stats.maintenancePct / 100.0,
                  notBookPct: stats.notBookablePct / 100.0,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${stats.overallRate.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        'Utilization',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Legend breakdown
          _buildLegendRow('In Use', '${stats.inUseCount} (${stats.inUsePct.toStringAsFixed(1)}%)', const Color(0xFF10B981), isDark),
          const SizedBox(height: 6),
          _buildLegendRow('Available', '${stats.availableCount} (${stats.availablePct.toStringAsFixed(1)}%)', const Color(0xFF06B6D4), isDark),
          const SizedBox(height: 6),
          _buildLegendRow('Under Maintenance', '${stats.maintenanceCount} (${stats.maintenancePct.toStringAsFixed(1)}%)', const Color(0xFFF59E0B), isDark),
          const SizedBox(height: 6),
          _buildLegendRow('Not Bookable', '${stats.notBookableCount} (${stats.notBookablePct.toStringAsFixed(1)}%)', const Color(0xFFEC4899), isDark),
        ],
      ),
    );
  }

  Widget _buildLegendRow(String title, String countText, Color color, bool isDark) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569), fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          countText,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1E293B)),
        ),
      ],
    );
  }

  // ==========================================================================
  // CARD 3: QUICK ACTIONS (2x2 GRID)
  // ==========================================================================

  Widget _buildQuickActionsCard(SpaceBookingNotifier notifier, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);

    return Container(
      padding: const EdgeInsets.all(14.0),
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
          Row(
            children: [
              const Icon(Icons.bolt, size: 18, color: Color(0xFF3B82F6)),
              const SizedBox(width: 6),
              Text(
                'Quick Actions',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2x2 Grid
          Row(
            children: [
              Expanded(
                child: _buildActionTile(
                  icon: Icons.calendar_month,
                  label: 'Create Recurring\nBooking',
                  isDark: isDark,
                  onTap: () {
                    if (widget.onOpenRecurringModal != null) {
                      widget.onOpenRecurringModal!();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionTile(
                  icon: Icons.shield_outlined,
                  label: 'Manage\nApprovals',
                  isDark: isDark,
                  onTap: () {
                    if (widget.onOpenManageApprovals != null) {
                      widget.onOpenManageApprovals!();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildActionTile(
                  icon: Icons.bar_chart_outlined,
                  label: 'Space\nUtilization Report',
                  isDark: isDark,
                  onTap: () {
                    if (widget.onOpenUtilizationReport != null) {
                      widget.onOpenUtilizationReport!();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionTile(
                  icon: Icons.file_download_outlined,
                  label: 'Export\nBookings',
                  isDark: isDark,
                  onTap: () => notifier.exportCsv(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final tileBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final tileBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textLabel = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155);

    return Material(
      color: tileBg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 70),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: tileBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: const Color(0xFF3B82F6)),
              const SizedBox(height: 3),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textLabel, height: 1.15),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3.0),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color),
      ),
    );
  }

  Widget _buildDropdownField({
    required String value,
    required bool isDark,
    required Color inputBg,
    required Color inputBorder,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: inputBg,
        border: Border.all(color: inputBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          icon: Icon(Icons.keyboard_arrow_down, size: 16, color: textSecondary),
          style: TextStyle(fontSize: 12, color: textPrimary),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Custom Donut Painter for Space Utilization
class _SpaceDonutChartPainter extends CustomPainter {
  final double inUsePct;
  final double availPct;
  final double maintPct;
  final double notBookPct;

  _SpaceDonutChartPainter({
    required this.inUsePct,
    required this.availPct,
    required this.maintPct,
    required this.notBookPct,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 8;
    const strokeWidth = 14.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    double startAngle = -pi / 2;

    // 1. In Use (Green)
    paint.color = const Color(0xFF10B981);
    final sweep1 = inUsePct * 2 * pi;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweep1, false, paint);
    startAngle += sweep1;

    // 2. Available (Cyan)
    paint.color = const Color(0xFF06B6D4);
    final sweep2 = availPct * 2 * pi;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweep2, false, paint);
    startAngle += sweep2;

    // 3. Under Maintenance (Amber)
    paint.color = const Color(0xFFF59E0B);
    final sweep3 = maintPct * 2 * pi;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweep3, false, paint);
    startAngle += sweep3;

    // 4. Not Bookable (Pink)
    paint.color = const Color(0xFFEC4899);
    final sweep4 = notBookPct * 2 * pi;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweep4, false, paint);
  }

  @override
  bool shouldRepaint(covariant _SpaceDonutChartPainter oldDelegate) => true;
}
