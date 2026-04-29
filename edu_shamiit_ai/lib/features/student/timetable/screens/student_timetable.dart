import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/services/student_api_service.dart';
import 'package:edu_shamiit_ai/core/models/student_models.dart';

class StudentTimetable extends ConsumerStatefulWidget {
  const StudentTimetable({super.key});

  @override
  ConsumerState<StudentTimetable> createState() => _StudentTimetableState();
}

class _StudentTimetableState extends ConsumerState<StudentTimetable> {
  final StudentApiService _apiService = StudentApiService();
  
  int _selectedDay = DateTime.now().weekday - 1; // Current day (0=Monday)
  final List<Map<String, dynamic>> _dayData = [
    {'name': 'MON', 'date': '', 'full': 'Monday'},
    {'name': 'TUE', 'date': '', 'full': 'Tuesday'},
    {'name': 'WED', 'date': '', 'full': 'Wednesday'},
    {'name': 'THU', 'date': '', 'full': 'Thursday'},
    {'name': 'FRI', 'date': '', 'full': 'Friday'},
    {'name': 'SAT', 'date': '', 'full': 'Saturday'},
  ];

  List<TimetablePeriod> _timetablePeriods = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _updateDates();
    _loadSchedule();
  }

  void _updateDates() {
    final now = DateTime.now();
    for (int i = 0; i < _dayData.length; i++) {
      final dayDate = now.subtract(Duration(days: (now.weekday - 1 - i) % 7));
      _dayData[i]['date'] = dayDate.day.toString();
    }
  }

  Future<void> _loadSchedule() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get full week timetable
      final periods = await _apiService.getTimetable(day: 'all');
      setState(() {
        _timetablePeriods = periods;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  List<Map<String, dynamic>> _getScheduleForDay(int dayIndex) {
    // dayIndex: 0=Sunday, 1=Monday, etc.
    final dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    final dayName = dayIndex < dayNames.length ? dayNames[dayIndex] : '';
    final dayPeriods = _timetablePeriods.where((p) => p.day == dayName).toList();
    dayPeriods.sort((a, b) => a.startTime.compareTo(b.startTime));

    final schedule = <Map<String, dynamic>>[];
    
    for (int i = 0; i < dayPeriods.length; i++) {
      final period = dayPeriods[i];
      schedule.add({
        'start': _formatTimeString(period.startTime),
        'end': _formatTimeString(period.endTime),
        'subject': period.subject,
        'teacher': period.teacherName,
        'room': period.roomNumber,
        'color': _getSubjectColor(period.subject),
        'icon': _getSubjectIcon(period.subject),
        'isBreak': false,
      });

      // Add break after this period if there's a gap
      if (i < dayPeriods.length - 1) {
        final nextPeriod = dayPeriods[i + 1];
        // Parse time strings to calculate gap
        final endTimeParts = period.endTime.split(':');
        final nextStartTimeParts = nextPeriod.startTime.split(':');
        final endHour = int.tryParse(endTimeParts[0]) ?? 0;
        final endMinute = int.tryParse(endTimeParts.length > 1 ? endTimeParts[1] : '0') ?? 0;
        final nextStartHour = int.tryParse(nextStartTimeParts[0]) ?? 0;
        final nextStartMinute = int.tryParse(nextStartTimeParts.length > 1 ? nextStartTimeParts[1] : '0') ?? 0;
        final gapMinutes = (nextStartHour * 60 + nextStartMinute) - (endHour * 60 + endMinute);
        
        if (gapMinutes >= 20) {
          final isLunch = endHour >= 12;
          schedule.add({
            'isBreak': true,
            'type': isLunch ? 'lunch' : 'break',
            'label': isLunch ? '🍱 Lunch' : '☕ Break',
            'time': '${_formatTimeString(period.endTime)} – ${_formatTimeString(nextPeriod.startTime)}',
          });
        }
      }
    }

    return schedule;
  }

  String _formatTimeString(String timeStr) {
    // timeStr is like "09:00" or "9:00 AM"
    final parts = timeStr.split(':');
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = parts[1].split(' ')[0];
      final ampm = parts.length > 2 ? parts[2] : (parts[1].contains('AM') ? 'AM' : (parts[1].contains('PM') ? 'PM' : ''));
      if (ampm.isNotEmpty) {
        return '$hour:$minute $ampm';
      }
      return '$hour:${minute.padLeft(2, '0')}';
    }
    return timeStr;
  }

  String _getSubjectIcon(String subject) {
    const icons = {
      'Mathematics': '📐',
      'Physics': '⚛️',
      'Chemistry': '⚗️',
      'English': '📖',
      'Computer Science': '💻',
      'Computer Sci.': '💻',
      'History': '📜',
      'Biology': '🧬',
      'Physical Education': '⚽',
      'Art': '🎨',
      'Music': '🎵',
      'Library': '📚',
      'Science Lab': '🔬',
    };
    return icons[subject] ?? '📚';
  }

  Color _getSubjectColor(String subject) {
    final colors = {
      'Mathematics': const Color(0xFF4F46E5),
      'Physics': const Color(0xFF059669),
      'Chemistry': const Color(0xFFF59E0B),
      'English': const Color(0xFFEF4444),
      'Computer Science': const Color(0xFF10B981),
      'Computer Sci.': const Color(0xFF10B981),
      'History': const Color(0xFF8B5CF6),
      'Biology': const Color(0xFF22C55E),
      'Physical Education': const Color(0xFF06B6D4),
      'Art': const Color(0xFFF472B6),
      'Music': const Color(0xFFEC4899),
      'Library': const Color(0xFF8B5CF6),
      'Science Lab': const Color(0xFF059669),
      'Language': const Color(0xFF06B6D4),
      'Moral Science': const Color(0xFFF59E0B),
      'Extra Curricular': const Color(0xFFEC4899),
      'Social Studies': const Color(0xFF6366F1),
    };
    return colors[subject] ?? const Color(0xFF6B7280);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading timetable: $_error', style: TextStyle(color: isDark ? StudentColors.darkText2 : StudentColors.text2)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadSchedule,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final schedule = _getScheduleForDay(_selectedDay);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E40AF), Color(0xFF1D4ED8)],
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => safeGoBack(context, '/student/dashboard'),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Timetable',
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Class X-A',
                        style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                // Day chips
                const SizedBox(height: 12),
                SizedBox(
                  height: 56,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _dayData.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final isSelected = index == _selectedDay;
                      final day = _dayData[index];
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedDay = index);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            border: isSelected ? Border.all(color: Colors.white.withValues(alpha: 0.3)) : null,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  day['name'],
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                    color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  day['date'],
                                  style: TextStyle(
                                    fontFamily: AppFonts.heading,
                                    fontSize: 16,
                                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                    color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Schedule list
          Expanded(
            child: schedule.isEmpty
                ? Center(child: Text('No classes scheduled for this day', style: TextStyle(color: isDark ? StudentColors.darkText3 : StudentColors.text3)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: schedule.length,
                    itemBuilder: (context, index) {
                      final item = schedule[index];
                      if (item['isBreak'] == true) {
                        return _buildBreakCard(item);
                      }
                      return _buildClassCard(item);
                    },
                  ),
          ),
        ],
      ),
      // AI FAB
      
    );
  }

  Widget _buildClassCard(Map<String, dynamic> item) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isNow = item['now'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isNow 
          ? (isDark ? const Color(0xFF065F46) : const Color(0xFFECFDF5)) 
          : theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: isNow ? Border.all(color: isDark ? const Color(0xFF059669) : const Color(0xFFBBF7D0), width: 1.5) : null,
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Row(
        children: [
          // Left accent bar
          Container(
            width: 4,
            height: 50,
            decoration: BoxDecoration(
              color: item['color'] ?? StudentColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          // Time
          Column(
            children: [
              Text(
                item['start'],
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, fontFamily: AppFonts.heading, color: isDark ? Colors.white : Colors.black),
              ),
              Text(
                item['end'],
                style: TextStyle(color: isDark ? StudentColors.darkText3 : StudentColors.text3, fontSize: 9),
              ),
            ],
          ),
          const SizedBox(width: 10),
          // Dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: item['color'] ?? StudentColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          // Subject info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['subject'],
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, fontFamily: AppFonts.heading, color: isDark ? Colors.white : Colors.black),
                ),
                const SizedBox(height: 2),
                Text(
                  item['teacher'],
                  style: TextStyle(color: isDark ? StudentColors.darkText3 : StudentColors.text3, fontSize: 10),
                ),
              ],
            ),
          ),
          // Room
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              item['room'],
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? StudentColors.darkText2 : const Color(0xFF475569)),
            ),
          ),
          if (isNow) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Text(
                '● NOW',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBreakCard(Map<String, dynamic> item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF451A03).withOpacity(0.3) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: isDark ? Border.all(color: const Color(0xFF78350F).withOpacity(0.5)) : null,
      ),
      child: Row(
        children: [
          const Text('☕', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item['label'],
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E)),
            ),
          ),
          Text(
            item['time'],
            style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309)),
          ),
        ],
      ),
    );
  }

}
