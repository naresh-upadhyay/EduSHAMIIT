import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';

class StudentTimetable extends ConsumerStatefulWidget {
  const StudentTimetable({super.key});

  @override
  ConsumerState<StudentTimetable> createState() => _StudentTimetableState();
}

class _StudentTimetableState extends ConsumerState<StudentTimetable> {
  int _selectedDay = 2; // Wednesday (0-indexed from Monday)
  final List<Map<String, dynamic>> _dayData = [
    {'name': 'MON', 'date': '24', 'full': 'Monday'},
    {'name': 'TUE', 'date': '25', 'full': 'Tuesday'},
    {'name': 'WED', 'date': '26', 'full': 'Wednesday'},
    {'name': 'THU', 'date': '27', 'full': 'Thursday'},
    {'name': 'FRI', 'date': '28', 'full': 'Friday'},
    {'name': 'SAT', 'date': '29', 'full': 'Saturday'},
  ];

  final Map<int, List<Map<String, dynamic>>> _schedules = {
    0: [ // Monday
      {'start': '8:00', 'end': '9:00', 'subject': 'Mathematics', 'teacher': 'Mr. R. Sharma', 'room': '301', 'color': const Color(0xFF4F46E5), 'icon': '📐'},
      {'start': '9:00', 'end': '10:00', 'subject': 'Physics', 'teacher': 'Dr. A. Verma', 'room': 'Lab 2', 'color': const Color(0xFF059669), 'icon': '⚛️', 'now': true},
      {'isBreak': true, 'type': 'break', 'label': '☕ Break', 'time': '10:00 – 10:20'},
      {'start': '10:20', 'end': '11:20', 'subject': 'English', 'teacher': 'Ms. P. Gupta', 'room': '204', 'color': const Color(0xFFEF4444), 'icon': '📖'},
      {'start': '11:20', 'end': '12:20', 'subject': 'Chemistry', 'teacher': 'Dr. S. Mehta', 'room': 'Lab 1', 'color': const Color(0xFFF59E0B), 'icon': '⚗️'},
      {'isBreak': true, 'type': 'lunch', 'label': '🍱 Lunch', 'time': '12:20 – 1:00'},
      {'start': '1:00', 'end': '2:00', 'subject': 'History', 'teacher': 'Mrs. K. Rao', 'room': '102', 'color': const Color(0xFF8B5CF6), 'icon': '📜'},
      {'start': '2:00', 'end': '3:00', 'subject': 'Computer Sci.', 'teacher': 'Mr. V. Jain', 'room': 'Lab 3', 'color': const Color(0xFF10B981), 'icon': '💻'},
    ],
    1: [ // Tuesday
      {'start': '8:00', 'end': '9:00', 'subject': 'Physics', 'teacher': 'Dr. A. Verma', 'room': '301', 'color': const Color(0xFF059669), 'icon': '⚛️'},
      {'start': '9:00', 'end': '10:00', 'subject': 'Mathematics', 'teacher': 'Mr. R. Sharma', 'room': '204', 'color': const Color(0xFF4F46E5), 'icon': '📐'},
      {'isBreak': true, 'type': 'break', 'label': '☕ Break', 'time': '10:00 – 10:20'},
      {'start': '10:20', 'end': '11:20', 'subject': 'Chemistry', 'teacher': 'Dr. S. Mehta', 'room': 'Lab 1', 'color': const Color(0xFFF59E0B), 'icon': '⚗️'},
      {'start': '11:20', 'end': '12:20', 'subject': 'English', 'teacher': 'Ms. P. Gupta', 'room': '204', 'color': const Color(0xFFEF4444), 'icon': '📖'},
      {'isBreak': true, 'type': 'lunch', 'label': '🍱 Lunch', 'time': '12:20 – 1:00'},
      {'start': '1:00', 'end': '2:00', 'subject': 'Physical Ed.', 'teacher': 'Coach Singh', 'room': 'Ground', 'color': const Color(0xFF06B6D4), 'icon': '⚽'},
      {'start': '2:00', 'end': '3:00', 'subject': 'Art', 'teacher': 'Ms. Devi', 'room': 'Art Room', 'color': const Color(0xFFF472B6), 'icon': '🎨'},
    ],
    2: [ // Wednesday
      {'start': '8:00', 'end': '9:00', 'subject': 'Mathematics', 'teacher': 'Mr. R. Sharma', 'room': '301', 'color': const Color(0xFF4F46E5), 'icon': '📐'},
      {'start': '9:00', 'end': '10:00', 'subject': 'Physics', 'teacher': 'Dr. A. Verma', 'room': 'Lab 2', 'color': const Color(0xFF059669), 'icon': '⚛️', 'now': true},
      {'isBreak': true, 'type': 'break', 'label': '☕ Break', 'time': '10:00 – 10:20'},
      {'start': '10:20', 'end': '11:20', 'subject': 'English', 'teacher': 'Ms. P. Gupta', 'room': '204', 'color': const Color(0xFFEF4444), 'icon': '📖'},
      {'start': '11:20', 'end': '12:20', 'subject': 'Chemistry', 'teacher': 'Dr. S. Mehta', 'room': 'Lab 1', 'color': const Color(0xFFF59E0B), 'icon': '⚗️'},
      {'isBreak': true, 'type': 'lunch', 'label': '🍱 Lunch', 'time': '12:20 – 1:00'},
      {'start': '1:00', 'end': '2:00', 'subject': 'History', 'teacher': 'Mrs. K. Rao', 'room': '102', 'color': const Color(0xFF8B5CF6), 'icon': '📜'},
      {'start': '2:00', 'end': '3:00', 'subject': 'Computer Sci.', 'teacher': 'Mr. V. Jain', 'room': 'Lab 3', 'color': const Color(0xFF10B981), 'icon': '💻'},
    ],
    3: [ // Thursday
      {'start': '8:00', 'end': '9:00', 'subject': 'Chemistry', 'teacher': 'Dr. S. Mehta', 'room': 'Lab 1', 'color': const Color(0xFFF59E0B), 'icon': '⚗️'},
      {'start': '9:00', 'end': '10:00', 'subject': 'English', 'teacher': 'Ms. P. Gupta', 'room': '204', 'color': const Color(0xFFEF4444), 'icon': '📖'},
      {'isBreak': true, 'type': 'break', 'label': '☕ Break', 'time': '10:00 – 10:20'},
      {'start': '10:20', 'end': '11:20', 'subject': 'Mathematics', 'teacher': 'Mr. R. Sharma', 'room': '301', 'color': const Color(0xFF4F46E5), 'icon': '📐'},
      {'start': '11:20', 'end': '12:20', 'subject': 'Physics', 'teacher': 'Dr. A. Verma', 'room': 'Lab 2', 'color': const Color(0xFF059669), 'icon': '⚛️'},
      {'isBreak': true, 'type': 'lunch', 'label': '🍱 Lunch', 'time': '12:20 – 1:00'},
      {'start': '1:00', 'end': '2:00', 'subject': 'Biology', 'teacher': 'Dr. Patel', 'room': 'Lab 4', 'color': const Color(0xFF22C55E), 'icon': '🧬'},
      {'start': '2:00', 'end': '3:00', 'subject': 'Music', 'teacher': 'Mr. Rahman', 'room': 'Music Room', 'color': const Color(0xFFEC4899), 'icon': '🎵'},
    ],
    4: [ // Friday
      {'start': '8:00', 'end': '9:00', 'subject': 'English', 'teacher': 'Ms. P. Gupta', 'room': '204', 'color': const Color(0xFFEF4444), 'icon': '📖'},
      {'start': '9:00', 'end': '10:00', 'subject': 'Mathematics', 'teacher': 'Mr. R. Sharma', 'room': '301', 'color': const Color(0xFF4F46E5), 'icon': '📐'},
      {'isBreak': true, 'type': 'break', 'label': '☕ Break', 'time': '10:00 – 10:20'},
      {'start': '10:20', 'end': '11:20', 'subject': 'Physics', 'teacher': 'Dr. A. Verma', 'room': 'Lab 2', 'color': const Color(0xFF059669), 'icon': '⚛️'},
      {'start': '11:20', 'end': '12:20', 'subject': 'Social Studies', 'teacher': 'Mrs. Reddy', 'room': '102', 'color': const Color(0xFF6366F1), 'icon': '🌍'},
      {'isBreak': true, 'type': 'lunch', 'label': '🍱 Lunch', 'time': '12:20 – 1:00'},
      {'start': '1:00', 'end': '2:00', 'subject': 'Computer Sci.', 'teacher': 'Mr. V. Jain', 'room': 'Lab 3', 'color': const Color(0xFF10B981), 'icon': '💻'},
      {'start': '2:00', 'end': '3:00', 'subject': 'Library', 'teacher': 'Ms. Bookwalter', 'room': 'Library', 'color': const Color(0xFF8B5CF6), 'icon': '📚'},
    ],
    5: [ // Saturday
      {'start': '8:00', 'end': '9:00', 'subject': 'Mathematics', 'teacher': 'Mr. R. Sharma', 'room': '301', 'color': const Color(0xFF4F46E5), 'icon': '📐'},
      {'start': '9:00', 'end': '10:00', 'subject': 'Science Lab', 'teacher': 'Dr. Verma', 'room': 'Lab 2', 'color': const Color(0xFF059669), 'icon': '🔬'},
      {'isBreak': true, 'type': 'break', 'label': '☕ Break', 'time': '10:00 – 10:20'},
      {'start': '10:20', 'end': '11:20', 'subject': 'Language', 'teacher': 'Ms. Kumar', 'room': '204', 'color': const Color(0xFF06B6D4), 'icon': '🗣️'},
      {'start': '11:20', 'end': '12:20', 'subject': 'Moral Science', 'teacher': 'Mr. Sharma', 'room': '102', 'color': const Color(0xFFF59E0B), 'icon': '🙏'},
      {'isBreak': true, 'type': 'lunch', 'label': '🍱 Lunch', 'time': '12:20 – 1:00'},
      {'start': '1:00', 'end': '2:00', 'subject': 'Extra Curricular', 'teacher': 'Various', 'room': 'Various', 'color': const Color(0xFFEC4899), 'icon': '🎭'},
    ],
  };

  List<dynamic> _schedule = [];

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  void _loadSchedule() {
    setState(() {
      _schedule = _schedules[_selectedDay] ?? [];
    });
  }

  Color _getSubjectColor(String subject) {
    final colors = {
      'Mathematics': const Color(0xFFEEF2FF),
      'Physics': const Color(0xFFEFF6FF),
      'Chemistry': const Color(0xFFFFF7ED),
      'English': const Color(0xFFFFF0F0),
      'History': const Color(0xFFF0FDF4),
      'Computer Sci.': const Color(0xFFEFF6FF),
      'Computer Science': const Color(0xFFEFF6FF),
      'Biology': const Color(0xFFECFDF5),
      'Physical Ed.': const Color(0xFFE0F2FE),
      'Art': const Color(0xFFFCE7F3),
      'Music': const Color(0xFFFCE7F3),
      'Social Studies': const Color(0xFFE0E7FF),
      'Science Lab': const Color(0xFFEFF6FF),
      'Language': const Color(0xFFE0F2FE),
      'Moral Science': const Color(0xFFFFF7ED),
      'Extra Curricular': const Color(0xFFFCE7F3),
      'Library': const Color(0xFFF3E8FF),
    };
    return colors[subject] ?? const Color(0xFFF8FAFC);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
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
                      onPressed: () => context.pop(),
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
                        color: Colors.white.withOpacity(0.15),
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
                  height: 52,
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
                          _loadSchedule();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            border: isSelected ? Border.all(color: Colors.white.withOpacity(0.3)) : null,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                day['name'],
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                  color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                day['date'],
                                style: TextStyle(
                                  fontFamily: AppFonts.heading,
                                  fontSize: 16,
                                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                  color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
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
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _schedule.length,
              itemBuilder: (context, index) {
                final item = _schedule[index];
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/student/aichat'),
        backgroundColor: const Color(0xFF4F46E5),
        child: const Text('🤖', style: TextStyle(fontSize: 20)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      // Bottom nav placeholder
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> item) {
    final bgColor = _getSubjectColor(item['subject']);
    final isNow = item['now'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isNow ? const Color(0xFFECFDF5) : StudentColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: isNow ? Border.all(color: const Color(0xFFBBF7D0), width: 1.5) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, fontFamily: AppFonts.heading),
              ),
              Text(
                item['end'],
                style: TextStyle(color: StudentColors.text3, fontSize: 9),
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
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, fontFamily: AppFonts.heading),
                ),
                const SizedBox(height: 2),
                Text(
                  item['teacher'],
                  style: TextStyle(color: StudentColors.text3, fontSize: 10),
                ),
              ],
            ),
          ),
          // Room
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              item['room'],
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Text('☕', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item['label'],
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Color(0xFF92400E)),
            ),
          ),
          Text(
            item['time'],
            style: const TextStyle(fontSize: 10, color: Color(0xFFB45309)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem('🏠', 'Home', false, () => context.go('/student/dashboard')),
          _buildNavItem('🗓️', 'Timetable', true, null),
          _buildNavItem('📊', 'Results', false, () => context.go('/student/results')),
          _buildNavItem('📝', 'Homework', false, () => context.go('/student/homework')),
          _buildNavItem('👤', 'Profile', false, () => context.go('/student/profile')),
        ],
      ),
    );
  }

  Widget _buildNavItem(String icon, String label, bool isActive, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 28,
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFFEEF2FF) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 16))),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? StudentColors.primary : StudentColors.text3,
            ),
          ),
        ],
      ),
    );
  }
}