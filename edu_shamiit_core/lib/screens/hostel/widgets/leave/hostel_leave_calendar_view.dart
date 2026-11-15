import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/hostel_provider.dart';
import '../../models/hostel_leave_outing_models.dart';

class HostelLeaveCalendarView extends ConsumerStatefulWidget {
  const HostelLeaveCalendarView({super.key});

  @override
  ConsumerState<HostelLeaveCalendarView> createState() => _HostelLeaveCalendarViewState();
}

class _HostelLeaveCalendarViewState extends ConsumerState<HostelLeaveCalendarView> {
  late DateTime _currentMonth;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month, 1);
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  void _resetToToday() {
    final now = DateTime.now();
    setState(() {
      _currentMonth = DateTime(now.year, now.month, 1);
      _selectedDate = DateTime(now.year, now.month, now.day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hostelProvider);
    final notifier = ref.read(hostelProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final requests = state.leaveRequests;

    // Filter requests for currently displayed month
    final departuresMap = <int, List<LeaveOutingRequestItem>>{};
    final returnsMap = <int, List<LeaveOutingRequestItem>>{};

    for (final req in requests) {
      if (req.startAt != null &&
          req.startAt!.year == _currentMonth.year &&
          req.startAt!.month == _currentMonth.month) {
        departuresMap.putIfAbsent(req.startAt!.day, () => []).add(req);
      }
      if (req.expectedReturnAt != null &&
          req.expectedReturnAt!.year == _currentMonth.year &&
          req.expectedReturnAt!.month == _currentMonth.month) {
        returnsMap.putIfAbsent(req.expectedReturnAt!.day, () => []).add(req);
      }
    }

    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday; // 1 = Mon, 7 = Sun
    final leadingBlanks = firstWeekday - 1;

    final today = DateTime.now();
    final selectedDayRequests = <String, List<LeaveOutingRequestItem>>{
      'departures': [],
      'returns': [],
    };

    if (_selectedDate != null) {
      for (final req in requests) {
        if (req.startAt != null &&
            req.startAt!.year == _selectedDate!.year &&
            req.startAt!.month == _selectedDate!.month &&
            req.startAt!.day == _selectedDate!.day) {
          selectedDayRequests['departures']!.add(req);
        }
        if (req.expectedReturnAt != null &&
            req.expectedReturnAt!.year == _selectedDate!.year &&
            req.expectedReturnAt!.month == _selectedDate!.month &&
            req.expectedReturnAt!.day == _selectedDate!.day) {
          selectedDayRequests['returns']!.add(req);
        }
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Month Title & Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.calendar_month_rounded, color: Color(0xFF2563EB), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('MMMM yyyy').format(_currentMonth),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Scheduled departures and expected hostel returns',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: _resetToToday,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Today', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _prevMonth,
                    icon: const Icon(Icons.chevron_left_rounded, size: 22),
                    tooltip: 'Previous Month',
                  ),
                  IconButton(
                    onPressed: _nextMonth,
                    icon: const Icon(Icons.chevron_right_rounded, size: 22),
                    tooltip: 'Next Month',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          const SizedBox(height: 16),

          // Weekday headers
          Row(
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((day) {
              final isWeekend = day == 'Sat' || day == 'Sun';
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isWeekend
                          ? const Color(0xFFEF4444)
                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),

          // Days Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.15,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: leadingBlanks + daysInMonth,
            itemBuilder: (context, index) {
              if (index < leadingBlanks) {
                return const SizedBox.shrink();
              }
              final dayNum = index - leadingBlanks + 1;
              final dayDate = DateTime(_currentMonth.year, _currentMonth.month, dayNum);
              final isToday = dayDate.year == today.year && dayDate.month == today.month && dayDate.day == today.day;
              final isSelected = _selectedDate != null &&
                  _selectedDate!.year == dayDate.year &&
                  _selectedDate!.month == dayDate.month &&
                  _selectedDate!.day == dayDate.day;

              final deps = departuresMap[dayNum] ?? [];
              final rets = returnsMap[dayNum] ?? [];

              return InkWell(
                onTap: () {
                  setState(() => _selectedDate = dayDate);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF))
                        : (isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF2563EB)
                          : (isToday
                              ? const Color(0xFF3B82F6)
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isToday
                                  ? const Color(0xFF2563EB)
                                  : (isSelected ? const Color(0xFF2563EB).withValues(alpha: 0.15) : Colors.transparent),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$dayNum',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: (isToday || isSelected) ? FontWeight.w800 : FontWeight.w500,
                                color: isToday
                                    ? Colors.white
                                    : (isSelected
                                        ? const Color(0xFF2563EB)
                                        : (isDark ? Colors.white : const Color(0xFF0F172A))),
                              ),
                            ),
                          ),
                          if (deps.isNotEmpty || rets.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${deps.length + rets.length}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6366F1),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      if (deps.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            '🛫 ${deps.length} leaving',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2563EB),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (rets.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            '🛬 ${rets.length} returns',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF16A34A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // Selected Day Roster Section
          if (_selectedDate != null) ...[
            Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event_note_rounded, size: 18, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Text(
                      'Movements for ${DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate!)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${selectedDayRequests['departures']!.length} Departures • ${selectedDayRequests['returns']!.length} Returns',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (selectedDayRequests['departures']!.isEmpty && selectedDayRequests['returns']!.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No departures or expected returns scheduled for this day.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              )
            else
              Column(
                children: [
                  ...selectedDayRequests['departures']!.map((r) => _buildMovementItem(r, isDeparture: true, notifier: notifier, isDark: isDark)),
                  ...selectedDayRequests['returns']!.map((r) => _buildMovementItem(r, isDeparture: false, notifier: notifier, isDark: isDark)),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildMovementItem(
    LeaveOutingRequestItem req, {
    required bool isDeparture,
    required HostelNotifier notifier,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: (isDeparture ? const Color(0xFF2563EB) : const Color(0xFF16A34A)).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDeparture ? Icons.flight_takeoff_rounded : Icons.flight_land_rounded,
              size: 16,
              color: isDeparture ? const Color(0xFF2563EB) : const Color(0xFF16A34A),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      req.studentName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        req.requestType,
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF6366F1)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${req.hostelName ?? "Hostel"} • Room ${req.roomNumber ?? "-"} • Dest: ${req.destination}',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => notifier.selectLeaveRequest(req),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(60, 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('View Pass', style: TextStyle(fontSize: 11.5)),
          ),
        ],
      ),
    );
  }
}
