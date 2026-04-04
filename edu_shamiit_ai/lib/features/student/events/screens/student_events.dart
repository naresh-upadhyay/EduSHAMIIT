import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';

class StudentEvents extends ConsumerStatefulWidget {
  const StudentEvents({super.key});

  @override
  ConsumerState<StudentEvents> createState() => _StudentEventsState();
}

class _StudentEventsState extends ConsumerState<StudentEvents> {
  List<dynamic> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 300));

    setState(() {
      _events = [
        {
          "id": "uuid-event-1",
          "title": "Annual Sports Day",
          "date": "2026-04-20",
          "time": "09:00",
          "venue": "School Ground",
          "max_participants": 200,
          "current_participants": 156,
          "icon": "🏃"
        },
        {
          "id": "uuid-event-2",
          "title": "Science Exhibition",
          "date": "2026-04-25",
          "time": "10:00",
          "venue": "Main Auditorium",
          "max_participants": 100,
          "current_participants": 78,
          "icon": "🔬"
        },
        {
          "id": "uuid-event-3",
          "title": "Annual Function",
          "date": "2026-05-05",
          "time": "17:00",
          "venue": "School Auditorium",
          "max_participants": 500,
          "current_participants": 320,
          "icon": "🎭"
        },
      ];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF1F5),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF831843), Color(0xFFBE185D)],
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
                  'Events',
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

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _events.length,
                    itemBuilder: (context, index) {
                      final event = _events[index];
                      return _buildEventCard(event);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final progress = event['current_participants'] / event['max_participants'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
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
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(event['icon'], style: const TextStyle(fontSize: 28))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event['title'],
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 14, color: StudentColors.text3),
                    const SizedBox(width: 4),
                    Text(
                      '${event['date']} • ${event['time']}',
                      style: TextStyle(
                        fontFamily: AppFonts.body,
                        fontSize: 12,
                        color: StudentColors.text3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 14, color: StudentColors.text3),
                    const SizedBox(width: 4),
                    Text(
                      event['venue'],
                      style: TextStyle(
                        fontFamily: AppFonts.body,
                        fontSize: 12,
                        color: StudentColors.text3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: StudentColors.border,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFBE185D)),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${event['current_participants']}/${event['max_participants']}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}