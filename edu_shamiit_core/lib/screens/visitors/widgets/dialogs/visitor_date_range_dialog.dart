import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/visitors_provider.dart';

class VisitorDateRangeDialog extends ConsumerStatefulWidget {
  const VisitorDateRangeDialog({super.key});

  @override
  ConsumerState<VisitorDateRangeDialog> createState() => _VisitorDateRangeDialogState();
}

class _VisitorDateRangeDialogState extends ConsumerState<VisitorDateRangeDialog> {
  late DateTime _focusedMonth;
  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 0, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 23, minute: 59);
  String _selectedPreset = 'All Time';
  bool _isAllTime = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(visitorsProvider);
    _selectedPreset = state.selectedDateRange;

    final now = DateTime.now();
    if (state.startDate != null) {
      _startDate = DateTime(state.startDate!.year, state.startDate!.month, state.startDate!.day);
      _startTime = TimeOfDay(hour: state.startDate!.hour, minute: state.startDate!.minute);
      _focusedMonth = DateTime(_startDate!.year, _startDate!.month);
    } else {
      _focusedMonth = DateTime(now.year, now.month);
    }

    if (state.endDate != null) {
      _endDate = DateTime(state.endDate!.year, state.endDate!.month, state.endDate!.day);
      _endTime = TimeOfDay(hour: state.endDate!.hour, minute: state.endDate!.minute);
    }

    if (state.startDate == null && state.endDate == null) {
      _isAllTime = true;
    }
  }

  void _selectPreset(String presetKey) {
    final now = DateTime.now();
    setState(() {
      _selectedPreset = presetKey;
      _isAllTime = false;

      switch (presetKey) {
        case 'Today':
          _startDate = DateTime(now.year, now.month, now.day);
          _endDate = DateTime(now.year, now.month, now.day);
          _startTime = const TimeOfDay(hour: 0, minute: 0);
          _endTime = const TimeOfDay(hour: 23, minute: 59);
          _focusedMonth = DateTime(now.year, now.month);
          break;
        case 'Yesterday':
          final yest = now.subtract(const Duration(days: 1));
          _startDate = DateTime(yest.year, yest.month, yest.day);
          _endDate = DateTime(yest.year, yest.month, yest.day);
          _startTime = const TimeOfDay(hour: 0, minute: 0);
          _endTime = const TimeOfDay(hour: 23, minute: 59);
          _focusedMonth = DateTime(yest.year, yest.month);
          break;
        case 'Last 7 Days':
          final start7 = now.subtract(const Duration(days: 6));
          _startDate = DateTime(start7.year, start7.month, start7.day);
          _endDate = DateTime(now.year, now.month, now.day);
          _startTime = const TimeOfDay(hour: 0, minute: 0);
          _endTime = const TimeOfDay(hour: 23, minute: 59);
          _focusedMonth = DateTime(now.year, now.month);
          break;
        case 'Last 30 Days':
          final start30 = now.subtract(const Duration(days: 29));
          _startDate = DateTime(start30.year, start30.month, start30.day);
          _endDate = DateTime(now.year, now.month, now.day);
          _startTime = const TimeOfDay(hour: 0, minute: 0);
          _endTime = const TimeOfDay(hour: 23, minute: 59);
          _focusedMonth = DateTime(now.year, now.month);
          break;
        case 'This Month':
          _startDate = DateTime(now.year, now.month, 1);
          _endDate = DateTime(now.year, now.month + 1, 0);
          _startTime = const TimeOfDay(hour: 0, minute: 0);
          _endTime = const TimeOfDay(hour: 23, minute: 59);
          _focusedMonth = DateTime(now.year, now.month);
          break;
        case 'Last Month':
          _startDate = DateTime(now.year, now.month - 1, 1);
          _endDate = DateTime(now.year, now.month, 0);
          _startTime = const TimeOfDay(hour: 0, minute: 0);
          _endTime = const TimeOfDay(hour: 23, minute: 59);
          _focusedMonth = DateTime(_startDate!.year, _startDate!.month);
          break;

        case 'All Time':
        default:
          _isAllTime = true;
          _startDate = null;
          _endDate = null;
          _selectedPreset = 'All Time';
          break;
      }
    });
  }

  void _onDayClicked(DateTime day) {
    setState(() {
      _selectedPreset = 'Custom';
      _isAllTime = false;

      if (_startDate == null || (_startDate != null && _endDate != null)) {
        // Start new range selection
        _startDate = day;
        _endDate = null;
      } else if (_startDate != null && _endDate == null) {
        if (day.isBefore(_startDate!)) {
          // Clicked earlier day -> make that the start
          _startDate = day;
        } else {
          // Clicked same or later day -> complete the range
          _endDate = day;
        }
      }
    });
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF3B82F6),
            onPrimary: Colors.white,
            surface: Color(0xFF1E293B),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF3B82F6),
            onPrimary: Colors.white,
            surface: Color(0xFF1E293B),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  void _applyFilter() {
    DateTime? finalStart;
    DateTime? finalEnd;
    String label;

    if (_isAllTime || (_startDate == null && _endDate == null)) {
      label = 'All Time';
      finalStart = null;
      finalEnd = null;
    } else {
      final start = _startDate ?? _endDate!;
      final end = _endDate ?? _startDate!;

      finalStart = DateTime(
        start.year,
        start.month,
        start.day,
        _startTime.hour,
        _startTime.minute,
        0,
      );
      finalEnd = DateTime(
        end.year,
        end.month,
        end.day,
        _endTime.hour,
        _endTime.minute,
        59,
      );

      if (_selectedPreset != 'Custom') {
        label = _selectedPreset;
      } else if (start.year == end.year && start.month == end.month && start.day == end.day) {
        label = DateFormat('dd MMM yyyy').format(start);
      } else {
        label = '${DateFormat('dd MMM yyyy').format(start)} - ${DateFormat('dd MMM yyyy').format(end)}';
      }
    }

    ref.read(visitorsProvider.notifier).setDateRangeFilter(
      label,
      startDate: finalStart,
      endDate: finalEnd,
    );

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Visitor filter updated: $label'),
        backgroundColor: const Color(0xFF2563EB),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final todayFmt = DateFormat('dd MMM').format(now);
    final yestFmt = DateFormat('dd MMM').format(now.subtract(const Duration(days: 1)));

    final presetList = [
      {'key': 'Today', 'label': 'Today', 'subtitle': todayFmt, 'icon': Icons.today_rounded},
      {'key': 'Yesterday', 'label': 'Yesterday', 'subtitle': yestFmt, 'icon': Icons.history_rounded},
      {'key': 'Last 7 Days', 'label': 'Last 7 Days', 'subtitle': 'Past week', 'icon': Icons.date_range_rounded},
      {'key': 'Last 30 Days', 'label': 'Last 30 Days', 'subtitle': 'Past month', 'icon': Icons.calendar_view_month_rounded},
      {'key': 'This Month', 'label': 'This Month', 'subtitle': DateFormat('MMMM yyyy').format(now), 'icon': Icons.calendar_month_rounded},
      {'key': 'Last Month', 'label': 'Last Month', 'subtitle': DateFormat('MMMM yyyy').format(DateTime(now.year, now.month - 1)), 'icon': Icons.event_note_rounded},
      {'key': 'All Time', 'label': 'All Time', 'subtitle': 'Full records', 'icon': Icons.all_inclusive_rounded},
    ];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 780,
        constraints: const BoxConstraints(maxHeight: 650),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.date_range_rounded, color: Color(0xFF3B82F6), size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Date & Time Range Selection',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Select preset periods or pick custom multi-date range with precision time bounds',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    hoverColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

            // 2. Dual Panel Content
            Flexible(
              child: SingleChildScrollView(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: Presets Sidebar (~230px)
                    Container(
                      width: 230,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF131D31) : const Color(0xFFF8FAFC),
                        border: Border(
                          right: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF3B82F6)),
                              const SizedBox(width: 6),
                              Text(
                                'QUICK PRESETS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...presetList.map((preset) {
                            final isSelected = !_isAllTime && _selectedPreset == preset['key'] ||
                                (_isAllTime && preset['key'] == 'All Time');
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: InkWell(
                                onTap: () => _selectPreset(preset['key'] as String),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF2563EB).withValues(alpha: 0.18)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF3B82F6)
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        preset['icon'] as IconData,
                                        size: 16,
                                        color: isSelected
                                            ? const Color(0xFF3B82F6)
                                            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              preset['label'] as String,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                color: isSelected
                                                    ? (isDark ? Colors.white : const Color(0xFF1D4ED8))
                                                    : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                                              ),
                                            ),
                                            Text(
                                              preset['subtitle'] as String,
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                color: isSelected
                                                    ? const Color(0xFF3B82F6)
                                                    : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          size: 15,
                                          color: Color(0xFF3B82F6),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    // Right: Custom Multi-Date Calendar & Time (~530px)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Month Nav Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      DateFormat('MMMM yyyy').format(_focusedMonth),
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (_selectedPreset == 'Custom')
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'Custom Range',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF3B82F6),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    OutlinedButton(
                                      onPressed: () {
                                        setState(() {
                                          _focusedMonth = DateTime(now.year, now.month);
                                        });
                                      },
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        side: BorderSide(
                                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                        ),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                      child: Text(
                                        'Today',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      icon: const Icon(Icons.chevron_left_rounded, size: 20),
                                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                      onPressed: () {
                                        setState(() {
                                          _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
                                        });
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.chevron_right_rounded, size: 20),
                                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                      onPressed: () {
                                        setState(() {
                                          _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Calendar Grid
                            _buildCalendarGrid(isDark),

                            const SizedBox(height: 14),
                            Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            const SizedBox(height: 12),

                            // Time Selection Controls
                            Row(
                              children: [
                                const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF3B82F6)),
                                const SizedBox(width: 6),
                                Text(
                                  'TIME BOUNDARIES (24-HOUR FORMAT)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                // Start Time
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.login_rounded, size: 15, color: Color(0xFF10B981)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'From Time',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                                ),
                                              ),
                                              Text(
                                                '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        InkWell(
                                          onTap: _pickStartTime,
                                          borderRadius: BorderRadius.circular(6),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'Change',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF3B82F6),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // End Time
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.logout_rounded, size: 15, color: Color(0xFFF59E0B)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'To Time',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                                ),
                                              ),
                                              Text(
                                                '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        InkWell(
                                          onTap: _pickEndTime,
                                          borderRadius: BorderRadius.circular(6),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'Change',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF3B82F6),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Quick Time Presets
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _buildTimeChip('00:00 - 23:59 (Full Day)', const TimeOfDay(hour: 0, minute: 0), const TimeOfDay(hour: 23, minute: 59), isDark),
                                _buildTimeChip('08:00 - 14:00 (Morning Shift)', const TimeOfDay(hour: 8, minute: 0), const TimeOfDay(hour: 14, minute: 0), isDark),
                                _buildTimeChip('12:00 - 18:00 (Afternoon Shift)', const TimeOfDay(hour: 12, minute: 0), const TimeOfDay(hour: 18, minute: 0), isDark),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

            // 3. Bottom Summary & Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              color: isDark ? const Color(0xFF131D31) : const Color(0xFFF8FAFC),
              child: Row(
                children: [
                  // Summary badge
                  Expanded(
                    child: _buildSummaryBadge(isDark),
                  ),
                  const SizedBox(width: 14),

                  // Reset
                  TextButton.icon(
                    onPressed: () => _selectPreset('All Time'),
                    icon: const Icon(Icons.restart_alt_rounded, size: 16),
                    label: const Text('Reset All Time'),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Cancel
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Apply
                  ElevatedButton.icon(
                    onPressed: _applyFilter,
                    icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                    label: const Text(
                      'Apply Filter',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      elevation: 2,
                      shadowColor: const Color(0xFF2563EB).withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
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

  Widget _buildTimeChip(String label, TimeOfDay start, TimeOfDay end, bool isDark) {
    final isSelected = _startTime == start && _endTime == end;
    return InkWell(
      onTap: () {
        setState(() {
          _startTime = start;
          _endTime = end;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2563EB).withValues(alpha: 0.2)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected
                ? const Color(0xFF3B82F6)
                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryBadge(bool isDark) {
    if (_isAllTime || (_startDate == null && _endDate == null)) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.all_inclusive_rounded, size: 14, color: Color(0xFF10B981)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Showing all visitor activity records without date restrictions',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    final start = _startDate ?? _endDate!;
    final end = _endDate ?? _startDate!;
    final daysCount = end.difference(start).inDays + 1;
    final startFmt = DateFormat('dd MMM yyyy').format(start);
    final endFmt = DateFormat('dd MMM yyyy').format(end);
    final startTimeStr = '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}';
    final endTimeStr = '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF3B82F6)),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: RichText(
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
              children: [
                const TextSpan(text: 'Selected: ', style: TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(
                  text: '$startFmt, $startTimeStr ➔ $endFmt, $endTimeStr',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                TextSpan(
                  text: ' ($daysCount ${daysCount == 1 ? 'day' : 'days'})',
                  style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid(bool isDark) {
    const weekdays = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

    final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final startWeekday = firstDayOfMonth.weekday % 7; // Sunday = 0

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final totalCells = ((startWeekday + daysInMonth) / 7).ceil() * 7;

    return Column(
      children: [
        // Weekday header
        Row(
          children: weekdays.map((day) {
            return Expanded(
              child: Center(
                child: Text(
                  day,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),

        // Grid cells
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalCells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 3,
            crossAxisSpacing: 0,
            childAspectRatio: 1.35,
          ),
          itemBuilder: (context, index) {
            final dayOffset = index - startWeekday + 1;
            if (dayOffset < 1 || dayOffset > daysInMonth) {
              return const SizedBox();
            }

            final cellDate = DateTime(_focusedMonth.year, _focusedMonth.month, dayOffset);
            final isToday = cellDate.year == today.year && cellDate.month == today.month && cellDate.day == today.day;

            final effectiveStart = _startDate;
            final effectiveEnd = _endDate ?? _startDate;

            bool isStart = false;
            bool isEnd = false;
            bool isInRange = false;

            if (!_isAllTime && effectiveStart != null && effectiveEnd != null) {
              final startOnly = DateTime(effectiveStart.year, effectiveStart.month, effectiveStart.day);
              final endOnly = DateTime(effectiveEnd.year, effectiveEnd.month, effectiveEnd.day);

              isStart = cellDate.isAtSameMomentAs(startOnly);
              isEnd = cellDate.isAtSameMomentAs(endOnly);
              isInRange = (cellDate.isAfter(startOnly) && cellDate.isBefore(endOnly)) || isStart || isEnd;
            }

            return InkWell(
              onTap: () => _onDayClicked(cellDate),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                decoration: BoxDecoration(
                  color: isInRange
                      ? const Color(0xFF2563EB).withValues(alpha: isStart || isEnd ? 1.0 : 0.16)
                      : Colors.transparent,
                  borderRadius: BorderRadius.horizontal(
                    left: isStart ? const Radius.circular(8) : Radius.zero,
                    right: isEnd ? const Radius.circular(8) : Radius.zero,
                  ),
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: (isStart || isEnd)
                        ? const Color(0xFF2563EB)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isToday && !isStart && !isEnd
                        ? Border.all(color: const Color(0xFF3B82F6), width: 1.5)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$dayOffset',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: (isStart || isEnd || isToday) ? FontWeight.w700 : FontWeight.w500,
                      color: (isStart || isEnd)
                          ? Colors.white
                          : (isInRange
                              ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8))
                              : (isDark ? Colors.white : const Color(0xFF0F172A))),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

void showVisitorDateRangeDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (ctx) => const VisitorDateRangeDialog(),
  );
}
