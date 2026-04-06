import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';

class TeacherMyClasses extends StatefulWidget {
  const TeacherMyClasses({super.key});

  @override
  State<TeacherMyClasses> createState() => _TeacherMyClassesState();
}

class _TeacherMyClassesState extends State<TeacherMyClasses> {
  final List<Map<String, dynamic>> _classes = [
    {
      'id': '1',
      'name': 'X-A',
      'subject': 'Mathematics',
      'students': 42,
      'periods': 6,
      'nextClass': 'Today, 10:00 AM',
      'room': 'Room 101',
      'progress': 75,
    },
    {
      'id': '2',
      'name': 'X-B',
      'subject': 'Mathematics',
      'students': 38,
      'periods': 5,
      'nextClass': 'Today, 11:00 AM',
      'room': 'Room 102',
      'progress': 68,
    },
    {
      'id': '3',
      'name': 'X-C',
      'subject': 'Mathematics',
      'students': 40,
      'periods': 5,
      'nextClass': 'Tomorrow, 9:00 AM',
      'room': 'Room 103',
      'progress': 82,
    },
    {
      'id': '4',
      'name': 'IX-A',
      'subject': 'Physics',
      'students': 35,
      'periods': 4,
      'nextClass': 'Tomorrow, 10:00 AM',
      'room': 'Lab 1',
      'progress': 55,
    },
    {
      'id': '5',
      'name': 'IX-B',
      'subject': 'Physics',
      'students': 36,
      'periods': 4,
      'nextClass': 'Wed, 9:00 AM',
      'room': 'Lab 1',
      'progress': 60,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
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
                  'My Classes',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.info_outline, color: Colors.white),
                  onPressed: () {},
                ),
              ],
            ),
          ),

          // Summary cards
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: _buildSummaryCard('${_classes.length}', 'Classes', Colors.blue)),
                const SizedBox(width: 12),
                Expanded(child: _buildSummaryCard('${_classes.fold<int>(0, (s, c) => s + (c['students'] as int))}', 'Students', Colors.green)),
              ],
            ),
          ),

          // Classes list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _classes.length,
              itemBuilder: (context, index) {
                return _buildClassCard(_classes[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> classInfo) {
    return GestureDetector(
      onTap: () {
        // Navigate to class detail
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      classInfo['name'] as String,
                      style: const TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        classInfo['subject'] as String,
                        style: const TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${classInfo['students']} students · ${classInfo['periods']} periods/week',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
            const SizedBox(height: 12),
            // Meta info
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  classInfo['nextClass'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.meeting_room, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  classInfo['room'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Progress
            Row(
              children: [
                Text(
                  'Syllabus Progress',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                Text(
                  '${classInfo['progress']}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF4F46E5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (classInfo['progress'] as int) / 100,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}