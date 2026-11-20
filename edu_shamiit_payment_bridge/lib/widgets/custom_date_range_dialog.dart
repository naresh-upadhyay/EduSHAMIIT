import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';

class CustomDateRangeResult {
  final DateTime startDateTime;
  final DateTime endDateTime;
  final String label;

  const CustomDateRangeResult({
    required this.startDateTime,
    required this.endDateTime,
    required this.label,
  });
}

class CustomDateRangeDialog extends StatefulWidget {
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final TimeOfDay? initialStartTime;
  final TimeOfDay? initialEndTime;

  const CustomDateRangeDialog({
    super.key,
    this.initialStartDate,
    this.initialEndDate,
    this.initialStartTime,
    this.initialEndTime,
  });

  static Future<CustomDateRangeResult?> show(
    BuildContext context, {
    DateTime? initialStartDate,
    DateTime? initialEndDate,
    TimeOfDay? initialStartTime,
    TimeOfDay? initialEndTime,
  }) {
    return showDialog<CustomDateRangeResult>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CustomDateRangeDialog(
        initialStartDate: initialStartDate,
        initialEndDate: initialEndDate,
        initialStartTime: initialStartTime,
        initialEndTime: initialEndTime,
      ),
    );
  }

  @override
  State<CustomDateRangeDialog> createState() => _CustomDateRangeDialogState();
}

class _CustomDateRangeDialogState extends State<CustomDateRangeDialog> {
  late DateTime _startDate;
  late DateTime _endDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late DateTime _displayedMonth;

  String? _selectedPreset;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = widget.initialStartDate ?? now.subtract(const Duration(days: 7));
    _endDate = widget.initialEndDate ?? now;
    _startTime = widget.initialStartTime ?? const TimeOfDay(hour: 0, minute: 0);
    _endTime = widget.initialEndTime ?? const TimeOfDay(hour: 23, minute: 59);

    _displayedMonth = DateTime(_endDate.year, _endDate.month, 1);
  }

  void _applyPreset(String key) {
    final now = DateTime.now();
    DateTime s;
    DateTime e = now;
    TimeOfDay st = const TimeOfDay(hour: 0, minute: 0);
    TimeOfDay et = const TimeOfDay(hour: 23, minute: 59);

    switch (key) {
      case 'today':
        s = DateTime(now.year, now.month, now.day);
        e = now;
        break;
      case 'yesterday':
        s = DateTime(now.year, now.month, now.day - 1);
        e = DateTime(now.year, now.month, now.day - 1, 23, 59, 59);
        break;
      case 'last7':
        s = now.subtract(const Duration(days: 7));
        e = now;
        break;
      case 'this_week':
        final weekday = now.weekday; // 1 = Monday
        s = DateTime(now.year, now.month, now.day - (weekday - 1));
        e = now;
        break;
      case 'this_month':
        s = DateTime(now.year, now.month, 1);
        e = now;
        break;
      case 'last_month':
        s = DateTime(now.year, now.month - 1, 1);
        final lastDay = DateTime(now.year, now.month, 0).day;
        e = DateTime(now.year, now.month - 1, lastDay, 23, 59, 59);
        break;
      case 'last30':
        s = now.subtract(const Duration(days: 30));
        e = now;
        break;
      case 'this_year':
        s = DateTime(now.year, 1, 1);
        e = now;
        break;
      default:
        s = now.subtract(const Duration(days: 7));
        e = now;
    }

    setState(() {
      _selectedPreset = key;
      _startDate = s;
      _endDate = e;
      _startTime = st;
      _endTime = et;
      _displayedMonth = DateTime(e.year, e.month, 1);
    });
  }

  void _onDateTapped(DateTime day) {
    setState(() {
      _selectedPreset = null; // custom pick
      if (day.isBefore(_startDate)) {
        _startDate = day;
      } else if (day.isAfter(_startDate) && day.isBefore(_endDate)) {
        // Tapped in between, reset end date
        _endDate = day;
      } else if (day.isAfter(_endDate)) {
        _endDate = day;
      } else {
        // Same as start date
        _startDate = day;
      }
    });
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      helpText: 'SELECT START TIME',
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
      helpText: 'SELECT END TIME',
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final durationDays = _endDate.difference(_startDate).inDays.abs() + 1;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 680),
        child: Column(
          children: [
            // Header with Gradient
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryNavy, AppColors.primaryBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.date_range_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Custom Date & Time Range',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Filter payments & trends with precision',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Quick Presets Chips Bar
                    const Text(
                      'QUICK PRESETS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildPresetChip('Today', 'today'),
                          _buildPresetChip('Yesterday', 'yesterday'),
                          _buildPresetChip('Last 7 Days', 'last7'),
                          _buildPresetChip('This Week', 'this_week'),
                          _buildPresetChip('This Month', 'this_month'),
                          _buildPresetChip('Last Month', 'last_month'),
                          _buildPresetChip('Last 30 Days', 'last30'),
                          _buildPresetChip('Year to Date', 'this_year'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. Selected Range Cards (Start & End Date/Time)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // Start Date Card
                              Expanded(
                                child: _buildDateSummaryBox(
                                  title: 'START DATE',
                                  date: _startDate,
                                  time: _startTime,
                                  onTimeTap: _pickStartTime,
                                  isStart: true,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 14,
                                    color: AppColors.primaryNavy,
                                  ),
                                ),
                              ),
                              // End Date Card
                              Expanded(
                                child: _buildDateSummaryBox(
                                  title: 'END DATE',
                                  date: _endDate,
                                  time: _endTime,
                                  onTimeTap: _pickEndTime,
                                  isStart: false,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryNavy.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.timelapse_rounded, size: 14, color: AppColors.primaryNavy),
                                const SizedBox(width: 6),
                                Text(
                                  '$durationDays ${durationDays == 1 ? "day" : "days"} duration selected',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryNavy,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. Interactive Month Calendar
                    _buildInlineCalendar(),
                  ],
                ),
              ),
            ),

            // Footer Buttons
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _applyPreset('last7'),
                    icon: const Icon(Icons.restart_alt_rounded, size: 16, color: AppColors.textMuted),
                    label: const Text(
                      'Reset',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      final startFull = DateTime(
                        _startDate.year,
                        _startDate.month,
                        _startDate.day,
                        _startTime.hour,
                        _startTime.minute,
                      );
                      final endFull = DateTime(
                        _endDate.year,
                        _endDate.month,
                        _endDate.day,
                        _endTime.hour,
                        _endTime.minute,
                      );

                      final label =
                          '${DateFormat('dd MMM').format(startFull)} - ${DateFormat('dd MMM').format(endFull)}';

                      Navigator.of(context).pop(
                        CustomDateRangeResult(
                          startDateTime: startFull,
                          endDateTime: endFull,
                          label: label,
                        ),
                      );
                    },
                    icon: const Icon(Icons.check_circle_rounded, size: 16),
                    label: const Text(
                      'Apply Range',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
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

  Widget _buildPresetChip(String label, String key) {
    final isSelected = _selectedPreset == key;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => _applyPreset(key),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryNavy : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primaryNavy : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateSummaryBox({
    required String title,
    required DateTime date,
    required TimeOfDay time,
    required VoidCallback onTimeTap,
    required bool isStart,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: isStart ? AppColors.primaryBlue : AppColors.primaryNavy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('dd MMM yyyy').format(date),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: onTimeTap,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time_rounded, size: 11, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    time.format(context),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineCalendar() {
    final year = _displayedMonth.year;
    final month = _displayedMonth.month;
    final monthName = DateFormat('MMMM yyyy').format(_displayedMonth);

    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday % 7; // Sunday = 0

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Month navigation bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 20, color: AppColors.primaryNavy),
                onPressed: () {
                  setState(() {
                    _displayedMonth = DateTime(year, month - 1, 1);
                  });
                },
              ),
              Text(
                monthName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.primaryNavy),
                onPressed: () {
                  setState(() {
                    _displayedMonth = DateTime(year, month + 1, 1);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Days of Week Row
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _WeekdayLabel('S'),
              _WeekdayLabel('M'),
              _WeekdayLabel('T'),
              _WeekdayLabel('W'),
              _WeekdayLabel('T'),
              _WeekdayLabel('F'),
              _WeekdayLabel('S'),
            ],
          ),
          const Divider(height: 12, color: AppColors.border),

          // Calendar Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: firstWeekday + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 3,
              crossAxisSpacing: 3,
              childAspectRatio: 1.15,
            ),
            itemBuilder: (context, index) {
              if (index < firstWeekday) {
                return const SizedBox.shrink();
              }
              final dayNumber = index - firstWeekday + 1;
              final currentDay = DateTime(year, month, dayNumber);

              final isStart = currentDay.year == _startDate.year &&
                  currentDay.month == _startDate.month &&
                  currentDay.day == _startDate.day;

              final isEnd = currentDay.year == _endDate.year &&
                  currentDay.month == _endDate.month &&
                  currentDay.day == _endDate.day;

              final isInRange = currentDay.isAfter(_startDate) && currentDay.isBefore(_endDate);

              Color bgColor = Colors.transparent;
              Color textColor = AppColors.textPrimary;
              FontWeight fontWeight = FontWeight.normal;
              BorderRadius borderRadius = BorderRadius.circular(6);

              if (isStart || isEnd) {
                bgColor = AppColors.primaryNavy;
                textColor = Colors.white;
                fontWeight = FontWeight.bold;
                borderRadius = BorderRadius.circular(8);
              } else if (isInRange) {
                bgColor = AppColors.primaryBlue.withValues(alpha: 0.12);
                textColor = AppColors.primaryNavy;
                fontWeight = FontWeight.w600;
              }

              return InkWell(
                onTap: () => _onDateTapped(currentDay),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: borderRadius,
                  ),
                  child: Text(
                    '$dayNumber',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: fontWeight,
                      color: textColor,
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
}

class _WeekdayLabel extends StatelessWidget {
  final String label;
  const _WeekdayLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
