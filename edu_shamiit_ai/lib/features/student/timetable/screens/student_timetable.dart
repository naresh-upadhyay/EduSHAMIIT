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
  int _selectedDay = DateTime.now().weekday - 1;
  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  List<dynamic> _schedule = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTimetable();
  }

  Future<void> _loadTimetable() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 300));

    setState(() {
      _schedule = [
        {
          "start_time": "08:00",
          "end_time": "08:45",
          "subject": "Mathematics",
          "icon": "📐",
          "room": "101",
          "teacher": "Mr. Sharma"
        },
        {
          "start_time": "08:45",
          "end_time": "09:00",
          "is_break": true,
          "break_name": "Short Break"
        },
        {
          "start_time": "09:00",
          "end_time": "09:45",
          "subject": "Physics",
          "icon": "⚛️",
          "room": "Lab-1",
          "teacher": "Ms. Gupta"
        },
        {
          "start_time": "09:45",
          "end_time": "10:30",
          "subject": "Chemistry",
          "icon": "⚗️",
          "room": "Lab-2",
          "teacher": "Mr. Verma"
        },
        {
          "start_time": "10:30",
          "end_time": "10:45",
          "is_break": true,
          "break_name": "Recess"
        },
        {
          "start_time": "10:45",
          "end_time": "11:30",
          "subject": "English",
          "icon": "📚",
          "room": "205",
          "teacher": "Mrs. Sharma"
        },
        {
          "start_time": "11:30",
          "end_time": "12:15",
          "subject": "Computer Science",
          "icon": "💻",
          "room": "IT Lab",
          "teacher": "Mr. Kumar"
        },
      ];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E40AF), Color(0xFF1D4ED8)],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Timetable',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (index) {
                final isSelected = index == _selectedDay;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedDay = index);
                    _loadTimetable();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? StudentColors.primary : StudentColors.surface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _days[index],
                      style: TextStyle(
                        color: isSelected ? Colors.white : StudentColors.text,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _schedule.length,
                    itemBuilder: (context, index) {
                      final item = _schedule[index];
                      if (item['is_break'] == true) {
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: StudentColors.surface,
        borderRadius: BorderRadius.circular(14),
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
          Column(
            children: [
              Text(item['start_time'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Text(item['end_time'], style: TextStyle(color: StudentColors.text3, fontSize: 12)),
            ],
          ),
          const SizedBox(width: 14),
          Container(width: 4, height: 50, decoration: BoxDecoration(color: StudentColors.primary, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(item['icon'], style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Text(item['subject'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))
                ]),
                const SizedBox(height: 4),
                Text('Room ${item['room']} • ${item['teacher']}', style: TextStyle(color: StudentColors.text3, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakCard(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Text('☕', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Text(item['break_name'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const Spacer(),
          Text('${item['start_time']} - ${item['end_time']}', style: TextStyle(color: StudentColors.text2, fontSize: 13)),
        ],
      ),
    );
  }
}