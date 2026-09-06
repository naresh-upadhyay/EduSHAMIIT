import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum DatePreset {
  today,
  yesterday,
  thisWeek,
  last7Days,
  thisMonth,
  last30Days,
  thisQuarter,
  last90Days,
  thisAcademicYear,
  custom,
}

class DateRangeResult {
  final DateTime? start;
  final DateTime? end;
  final bool isCleared;

  const DateRangeResult({this.start, this.end, this.isCleared = false});
}

class PremiumDateRangeDialog extends StatefulWidget {
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;

  const PremiumDateRangeDialog({
    super.key,
    this.initialStartDate,
    this.initialEndDate,
  });

  static Future<DateRangeResult?> show(
    BuildContext context, {
    DateTime? initialStartDate,
    DateTime? initialEndDate,
  }) {
    return showDialog<DateRangeResult?>(
      context: context,
      barrierDismissible: true,
      builder: (context) => PremiumDateRangeDialog(
        initialStartDate: initialStartDate,
        initialEndDate: initialEndDate,
      ),
    );
  }


  @override
  State<PremiumDateRangeDialog> createState() => _PremiumDateRangeDialogState();
}

class _PremiumDateRangeDialogState extends State<PremiumDateRangeDialog> {
  DateTime? _startDate;
  DateTime? _endDate;
  DateTime _displayedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DatePreset _activePreset = DatePreset.custom;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
    if (_startDate != null) {
      _displayedMonth = DateTime(_startDate!.year, _startDate!.month);
      _determineMatchingPreset();
    } else {
      _displayedMonth = DateTime(DateTime.now().year, DateTime.now().month);
    }
  }

  void _determineMatchingPreset() {
    if (_startDate == null || _endDate == null) {
      _activePreset = DatePreset.custom;
      return;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final s = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
    final e = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);

    if (s == today && e == today) {
      _activePreset = DatePreset.today;
    } else if (s == today.subtract(const Duration(days: 6)) && e == today) {
      _activePreset = DatePreset.last7Days;
    } else if (s == today.subtract(const Duration(days: 29)) && e == today) {
      _activePreset = DatePreset.last30Days;
    } else if (s == DateTime(now.year, now.month, 1) &&
        e == DateTime(now.year, now.month + 1, 0)) {
      _activePreset = DatePreset.thisMonth;
    } else {
      _activePreset = DatePreset.custom;
    }
  }

  void _applyPreset(DatePreset preset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    setState(() {
      _activePreset = preset;
      switch (preset) {
        case DatePreset.today:
          _startDate = today;
          _endDate = today;
          _displayedMonth = DateTime(today.year, today.month);
          break;
        case DatePreset.yesterday:
          final y = today.subtract(const Duration(days: 1));
          _startDate = y;
          _endDate = y;
          _displayedMonth = DateTime(y.year, y.month);
          break;
        case DatePreset.thisWeek:
          final monday = today.subtract(Duration(days: today.weekday - 1));
          final sunday = monday.add(const Duration(days: 6));
          _startDate = monday;
          _endDate = sunday;
          _displayedMonth = DateTime(monday.year, monday.month);
          break;
        case DatePreset.last7Days:
          _startDate = today.subtract(const Duration(days: 6));
          _endDate = today;
          _displayedMonth = DateTime(today.year, today.month);
          break;
        case DatePreset.thisMonth:
          _startDate = DateTime(now.year, now.month, 1);
          _endDate = DateTime(now.year, now.month + 1, 0);
          _displayedMonth = DateTime(now.year, now.month);
          break;
        case DatePreset.last30Days:
          _startDate = today.subtract(const Duration(days: 29));
          _endDate = today;
          _displayedMonth = DateTime(today.year, today.month);
          break;
        case DatePreset.thisQuarter:
          final currentQuarter = ((now.month - 1) ~/ 3) + 1;
          final quarterStartMonth = (currentQuarter - 1) * 3 + 1;
          _startDate = DateTime(now.year, quarterStartMonth, 1);
          _endDate = DateTime(now.year, quarterStartMonth + 3, 0);
          _displayedMonth = DateTime(now.year, quarterStartMonth);
          break;
        case DatePreset.last90Days:
          _startDate = today.subtract(const Duration(days: 89));
          _endDate = today;
          _displayedMonth = DateTime(today.year, today.month);
          break;
        case DatePreset.thisAcademicYear:
          // Academic year April 1 to March 31
          final startYear = now.month >= 4 ? now.year : now.year - 1;
          _startDate = DateTime(startYear, 4, 1);
          _endDate = DateTime(startYear + 1, 3, 31);
          _displayedMonth = DateTime(now.year, now.month);
          break;
        case DatePreset.custom:
          break;
      }
    });
  }

  void _onDayTapped(DateTime day) {
    setState(() {
      _activePreset = DatePreset.custom;
      if (_startDate == null || (_startDate != null && _endDate != null)) {
        _startDate = day;
        _endDate = null;
      } else if (_startDate != null && _endDate == null) {
        if (day.isBefore(_startDate!)) {
          _endDate = _startDate;
          _startDate = day;
        } else {
          _endDate = day;
        }
      }
    });
  }

  int get _selectedDaysCount {
    if (_startDate == null) return 0;
    if (_endDate == null) return 1;
    return _endDate!.difference(_startDate!).inDays.abs() + 1;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 768;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: isCompact ? 380 : 760,
        constraints: const BoxConstraints(maxHeight: 640),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131B2E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.12),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Header
              _buildHeader(isDark),

              const Divider(height: 1),

              // 2. Selection Preview Cards
              _buildPreviewBar(isDark),

              const Divider(height: 1),

              // 3. Body: Presets Sidebar + Calendar
              Flexible(
                child: isCompact
                    ? SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildPresetsBar(isDark, horizontal: true),
                            const Divider(height: 1),
                            _buildCalendarView(isDark),
                          ],
                        ),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Presets Left Sidebar
                          SizedBox(
                            width: 220,
                            child: _buildPresetsBar(isDark, horizontal: false),
                          ),
                          VerticalDivider(width: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                          // Calendar Right Main Area
                          Expanded(
                            child: _buildCalendarView(isDark),
                          ),
                        ],
                      ),
              ),

              const Divider(height: 1),

              // 4. Bottom Action Footer
              _buildFooter(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.date_range_rounded, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Date Range',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Choose quick presets or click start and end dates on the calendar.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: isDark ? const Color(0xFF131B2E) : Colors.white,
      child: Row(
        children: [
          // Start Date Pill Card
          Expanded(
            child: _buildDateCard(
              label: 'From Date',
              date: _startDate,
              isDark: isDark,
              isStart: true,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Icon(Icons.arrow_forward_rounded, size: 18, color: Color(0xFF6366F1)),
          ),
          // End Date Pill Card
          Expanded(
            child: _buildDateCard(
              label: 'To Date',
              date: _endDate ?? _startDate,
              isDark: isDark,
              isStart: false,
            ),
          ),
          if (_startDate != null) ...[
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timelapse_rounded, size: 13, color: Color(0xFF6366F1)),
                  const SizedBox(width: 5),
                  Text(
                    '$_selectedDaysCount ${_selectedDaysCount == 1 ? "day" : "days"}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateCard({
    required String label,
    required DateTime? date,
    required bool isDark,
    required bool isStart,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: date != null ? const Color(0xFF6366F1) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: date != null ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isStart ? Icons.event_available_rounded : Icons.event_busy_rounded,
            size: 16,
            color: date != null ? const Color(0xFF6366F1) : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  date != null ? DateFormat('dd MMM yyyy').format(date) : 'Pick date',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: date != null
                        ? (isDark ? Colors.white : const Color(0xFF0F172A))
                        : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetsBar(bool isDark, {required bool horizontal}) {
    final presets = [
      (DatePreset.today, 'Today', Icons.today_rounded),
      (DatePreset.yesterday, 'Yesterday', Icons.history_rounded),
      (DatePreset.thisWeek, 'This Week', Icons.view_week_rounded),
      (DatePreset.last7Days, 'Last 7 Days', Icons.date_range_rounded),
      (DatePreset.thisMonth, 'This Month', Icons.calendar_month_rounded),
      (DatePreset.last30Days, 'Last 30 Days', Icons.calendar_today_rounded),
      (DatePreset.thisQuarter, 'This Quarter', Icons.pie_chart_rounded),
      (DatePreset.last90Days, 'Last 90 Days', Icons.event_repeat_rounded),
      (DatePreset.thisAcademicYear, 'Academic Year', Icons.school_rounded),
      (DatePreset.custom, 'Custom Range', Icons.tune_rounded),
    ];

    if (horizontal) {
      return Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: presets.map((p) => _buildPresetPill(p.$1, p.$2, p.$3, isDark)).toList(),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              'QUICK PRESETS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ),
          ),
          ...presets.map((p) => _buildPresetListItem(p.$1, p.$2, p.$3, isDark)),
        ],
      ),
    );
  }

  Widget _buildPresetListItem(DatePreset preset, String label, IconData icon, bool isDark) {
    final isSelected = _activePreset == preset;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _applyPreset(preset),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF6366F1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_rounded, size: 14, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetPill(DatePreset preset, String label, IconData icon, bool isDark) {
    final isSelected = _activePreset == preset;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: isSelected,
        showCheckmark: false,
        avatar: Icon(
          icon,
          size: 12,
          color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        ),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
          ),
        ),
        selectedColor: const Color(0xFF6366F1),
        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        onSelected: (_) => _applyPreset(preset),
      ),
    );
  }

  Widget _buildCalendarView(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Month Navigator Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 22),
                onPressed: () {
                  setState(() {
                    _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month - 1);
                  });
                },
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              Row(
                children: [
                  Text(
                    DateFormat('MMMM yyyy').format(_displayedMonth),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 22),
                onPressed: () {
                  setState(() {
                    _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1);
                  });
                },
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Day Names Row
          Row(
            children: ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'].map((d) {
              return Expanded(
                child: Center(
                  child: Text(
                    d,
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

          // Days Grid
          _buildMonthDaysGrid(isDark),
        ],
      ),
    );
  }

  Widget _buildMonthDaysGrid(bool isDark) {
    final firstDayOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    final daysInMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;
    final startingWeekday = firstDayOfMonth.weekday; // 1=Mon, 7=Sun

    final totalSlots = (startingWeekday - 1) + daysInMonth;
    final rowsCount = (totalSlots / 7).ceil();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Column(
      children: List.generate(rowsCount, (row) {
        return Row(
          children: List.generate(7, (col) {
            final dayIndex = row * 7 + col - (startingWeekday - 1) + 1;
            if (dayIndex < 1 || dayIndex > daysInMonth) {
              return const Expanded(child: SizedBox(height: 38));
            }

            final dayDate = DateTime(_displayedMonth.year, _displayedMonth.month, dayIndex);
            final isToday = dayDate == today;

            final isStart = _startDate != null &&
                dayDate.year == _startDate!.year &&
                dayDate.month == _startDate!.month &&
                dayDate.day == _startDate!.day;

            final effectiveEnd = _endDate ?? _startDate;
            final isEnd = effectiveEnd != null &&
                dayDate.year == effectiveEnd.year &&
                dayDate.month == effectiveEnd.month &&
                dayDate.day == effectiveEnd.day;

            final isInRange = _startDate != null &&
                effectiveEnd != null &&
                dayDate.isAfter(_startDate!) &&
                dayDate.isBefore(effectiveEnd);

            return Expanded(
              child: GestureDetector(
                onTap: () => _onDayTapped(dayDate),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: (isInRange || (isStart && _endDate != null) || (isEnd && _startDate != null && _startDate != effectiveEnd))
                        ? const Color(0xFF6366F1).withValues(alpha: 0.14)
                        : Colors.transparent,
                    borderRadius: BorderRadius.horizontal(
                      left: isStart ? const Radius.circular(19) : Radius.zero,
                      right: isEnd ? const Radius.circular(19) : Radius.zero,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (isStart || isEnd)
                            ? const Color(0xFF6366F1)
                            : (isToday
                                ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))
                                : Colors.transparent),
                        border: isToday && !isStart && !isEnd
                            ? Border.all(color: const Color(0xFF6366F1), width: 1.5)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '$dayIndex',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: (isStart || isEnd || isToday) ? FontWeight.w800 : FontWeight.w500,
                            color: (isStart || isEnd)
                                ? Colors.white
                                : (isDark ? Colors.white : const Color(0xFF0F172A)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      }),
    );
  }

  Widget _buildFooter(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            icon: const Icon(Icons.clear_all_rounded, size: 16),
            label: const Text('Clear Filter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(
              foregroundColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
            onPressed: () {
              Navigator.of(context).pop(const DateRangeResult(isCleared: true));
            },
          ),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                  label: const Text('Apply Range', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    if (_startDate != null) {
                      final effectiveEnd = _endDate ?? _startDate!;
                      Navigator.of(context).pop(DateRangeResult(start: _startDate!, end: effectiveEnd));
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

