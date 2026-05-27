import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/services/student_api_service.dart';
import 'package:edu_shamiit_ai/core/models/student_models.dart';
import 'package:edu_shamiit_ai/shared/widgets/calendar_picker.dart';

class StudentTimetable extends ConsumerStatefulWidget {
  const StudentTimetable({super.key});

  @override
  ConsumerState<StudentTimetable> createState() => _StudentTimetableState();
}

class _StudentTimetableState extends ConsumerState<StudentTimetable> {
  final StudentApiService _apiService = StudentApiService();
  
  DateTime _selectedDate = DateTime.now();
  List<TimetablePeriod> _timetablePeriods = [];
  bool _isLoading = true;
  String? _error;
  String _studentClass = ''; // Loaded from API response

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dateStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
      final periods = await _apiService.getTimetable(date: dateStr);
      // Also fetch raw response to get the class field
      final classFromResponse = await _apiService.getStudentClass();
      if (!mounted) return;
      setState(() {
        _timetablePeriods = periods;
        if (classFromResponse.isNotEmpty) _studentClass = classFromResponse;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PremiumCalendarPicker(
        initialDate: _selectedDate,
        primaryColor: const Color(0xFF1D4ED8),
        onDateSelected: (date) {
          setState(() {
            _selectedDate = date;
          });
          _loadSchedule();
        },
      ),
    );
  }

  String _formatFullDate(DateTime date) {
    const weekdays = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return "${weekdays[date.weekday]}, ${months[date.month]} ${date.day}";
  }

  String _getWeekdayAbbr(int weekday) {
    const days = ['', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return days[weekday];
  }

  bool _isPeriodNow(String startStr, String endStr) {
    try {
      final now = DateTime.now();
      final startTime = _parseTimeStringToTimeOfDay(startStr);
      final endTime = _parseTimeStringToTimeOfDay(endStr);
      
      if (startTime == null || endTime == null) return false;
      
      final nowMinutes = now.hour * 60 + now.minute;
      final startMinutes = startTime.hour * 60 + startTime.minute;
      final endMinutes = endTime.hour * 60 + endTime.minute;
      
      return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
    } catch (_) {
      return false;
    }
  }

  TimeOfDay? _parseTimeStringToTimeOfDay(String timeStr) {
    try {
      var cleaned = timeStr.toUpperCase().replaceAll('Z', '').trim();
      bool isPM = cleaned.contains('PM');
      bool isAM = cleaned.contains('AM');
      cleaned = cleaned.replaceAll('AM', '').replaceAll('PM', '').trim();
      
      final parts = cleaned.split(':');
      if (parts.isEmpty) return null;
      
      var hour = int.parse(parts[0]);
      var minute = parts.length > 1 ? int.parse(parts[1].split(' ')[0]) : 0;
      
      if (isPM && hour < 12) hour += 12;
      if (isAM && hour == 12) hour = 0;
      
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> _getSchedule() {
    final dayPeriods = List<TimetablePeriod>.from(_timetablePeriods);
    dayPeriods.sort((a, b) => a.startTime.compareTo(b.startTime));

    final schedule = <Map<String, dynamic>>[];
    
    for (int i = 0; i < dayPeriods.length; i++) {
      final period = dayPeriods[i];
      schedule.add({
        'start': _formatTimeString(period.startTime),
        'end': _formatTimeString(period.endTime),
        'subject': period.subject,
        'teacher': period.teacherName.isEmpty ? 'Teacher' : period.teacherName,
        'room': period.roomNumber.isEmpty ? 'Room 101' : period.roomNumber,
        'isBreak': false,
        'now': _isPeriodNow(period.startTime, period.endTime),
      });

      // Add break after this period if there's a gap
      if (i < dayPeriods.length - 1) {
        final nextPeriod = dayPeriods[i + 1];
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

  SubjectTheme _getSubjectTheme(String subject) {
    final s = subject.toLowerCase();
    if (s.contains('math')) {
      return const SubjectTheme(
        bg: Color(0xFFEFF6FF),
        border: Color(0xFFBFDBFE),
        accent: Color(0xFF4F46E5),
        icon: '📐',
      );
    } else if (s.contains('physics')) {
      return const SubjectTheme(
        bg: Color(0xFFECFDF5),
        border: Color(0xFFBBF7D0),
        accent: Color(0xFF059669),
        icon: '⚛️',
      );
    } else if (s.contains('chemistry')) {
      return const SubjectTheme(
        bg: Color(0xFFFFFBEB),
        border: Color(0xFFFDE68A),
        accent: Color(0xFFD97706),
        icon: '⚗️',
      );
    } else if (s.contains('english')) {
      return const SubjectTheme(
        bg: Color(0xFFFFF1F2),
        border: Color(0xFFFECDD3),
        accent: Color(0xFFE11D48),
        icon: '📖',
      );
    } else if (s.contains('computer') || s.contains('cs')) {
      return const SubjectTheme(
        bg: Color(0xFFECFDF5),
        border: Color(0xFFA7F3D0),
        accent: Color(0xFF10B981),
        icon: '💻',
      );
    } else if (s.contains('history') || s.contains('library')) {
      return const SubjectTheme(
        bg: Color(0xFFF5F3FF),
        border: Color(0xFFDDD6FE),
        accent: Color(0xFF8B5CF6),
        icon: '📜',
      );
    }
    return const SubjectTheme(
      bg: Color(0xFFF8FAFC),
      border: Color(0xFFE2E8F0),
      accent: Color(0xFF475569),
      icon: '📚',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final schedule = _getSchedule();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F1D) : const Color(0xFFF0F4FF),
      body: Column(
        children: [
          // Header styled exactly like student portal mockup
          Container(
            padding: EdgeInsets.fromLTRB(16, Responsive.headerTopPadding(context), 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E40AF), Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => safeGoBack(context, '/student/dashboard'),
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text(
                        'Timetable',
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => _selectDate(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_month, color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Select Date'.tr(ref),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _studentClass.isNotEmpty ? 'Class $_studentClass' : 'My Class',
                        style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _formatFullDate(_selectedDate),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Weekly dynamic scrolling date chips matching student portal mockup style
                SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 7,
                    itemBuilder: (context, index) {
                      final offset = index - 3;
                      final dateOfChoice = _selectedDate.add(Duration(days: offset));
                      final isSelected = offset == 0;
                      final dayName = _getWeekdayAbbr(dateOfChoice.weekday);
                      
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDate = dateOfChoice;
                          });
                          _loadSchedule();
                        },
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 54),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)])
                                : null,
                            color: isSelected ? null : Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? Colors.transparent : Colors.white.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                dayName,
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.white : Colors.white60,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${dateOfChoice.day}',
                                style: const TextStyle(
                                  fontFamily: AppFonts.heading,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
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
          
          const SizedBox(height: 12),
          
          // Main schedule view
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF1D4ED8)))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.red),
                            const SizedBox(height: 16),
                            Text('Error: $_error', style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadSchedule,
                              child: Text('Retry'.tr(ref)),
                            ),
                          ],
                        ),
                      )
                    : schedule.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('🏖️', style: TextStyle(fontSize: 48)),
                                const SizedBox(height: 12),
                                Text(
                                  _selectedDate.weekday == 7 ? 'No Classes Today (Sunday)' : 'No classes scheduled',
                                  style: TextStyle(
                                    fontFamily: AppFonts.heading,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white70 : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Enjoy your rest day!',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white30 : Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
    );
  }

  Widget _buildClassCard(Map<String, dynamic> item) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isNow = item['now'] == true;
    final subjectTheme = _getSubjectTheme(item['subject']);
    
    Color cardBg = isDark ? const Color(0xFF1E293B) : subjectTheme.bg;
    Color borderColor = isDark ? const Color(0xFF334155) : subjectTheme.border;
    Color accentColor = subjectTheme.accent;

    if (isNow) {
      cardBg = isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5);
      borderColor = isDark ? const Color(0xFF065F46) : const Color(0xFFBBF7D0);
      accentColor = const Color(0xFF059669);
    }

    return GestureDetector(
      onTap: () => _showDynModal(item, subjectTheme.icon),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            // Left accent bar
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            // Time info
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['start'],
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    fontFamily: AppFonts.heading,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  item['end'],
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // Dot
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            // Subject info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['subject'],
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      fontFamily: AppFonts.heading,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item['teacher'],
                    style: TextStyle(
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            // Room/NOW
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item['room'],
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                    ),
                  ),
                ),
                if (isNow) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Text(
                      'NOW',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakCard(Map<String, dynamic> item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF451A03).withValues(alpha: 0.3) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: isDark ? Border.all(color: const Color(0xFF78350F).withValues(alpha: 0.5)) : null,
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

  void _showDynModal(Map<String, dynamic> item, String icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            // Header
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(icon, style: const TextStyle(fontSize: 22)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['subject'],
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '${item['start']} – ${item['end']} · Room ${item['room']}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Details/Desc
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailItem('Teacher:', item['teacher']),
                  _buildDetailItem('Topic:', 'Integration by Parts (Ch. 7) & advanced calculus functions.'),
                  _buildDetailItem('Reference Material:', 'NCERT Calculus Textbook, Graph notebook.'),
                  _buildDetailItem('Homework:', 'Exercises 7.3 (Q1 - Q5) due on coming Monday.'),
                  _buildDetailItem('Important Notes:', 'Please carry geometry instruments for graphical plotting.'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Status bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Class notes will be uploaded after this session.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
              ),
            ),
            const SizedBox(height: 20),

            // Close button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E40AF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String val) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? Colors.white60 : Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              val,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF334155)),
            ),
          ),
        ],
      ),
    );
  }
}

class SubjectTheme {
  final Color bg;
  final Color border;
  final Color accent;
  final String icon;

  const SubjectTheme({
    required this.bg,
    required this.border,
    required this.accent,
    required this.icon,
  });
}
