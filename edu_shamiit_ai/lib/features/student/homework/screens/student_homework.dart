import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';

class StudentHomework extends ConsumerStatefulWidget {
  const StudentHomework({super.key});

  @override
  ConsumerState<StudentHomework> createState() => _StudentHomeworkState();
}

class _StudentHomeworkState extends ConsumerState<StudentHomework> {
  String _selectedStatus = 'All';
  final List<String> _statuses = ['All', 'Pending', 'Submitted', 'Graded'];
  List<dynamic> _homework = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHomework();
  }

  Future<void> _loadHomework() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 300));

    setState(() {
      _homework = [
        {
          "id": "uuid-hw-1",
          "title": "Trigonometry Problems Ch-8",
          "subject": "Mathematics",
          "icon": "📐",
          "due_date": "2026-04-05",
          "max_marks": 25,
          "status": "pending",
          "submission_status": null
        },
        {
          "id": "uuid-hw-2",
          "title": "Newton's Laws Worksheet",
          "subject": "Physics",
          "icon": "⚛️",
          "due_date": "2026-04-03",
          "max_marks": 20,
          "status": "submitted",
          "submission_status": "submitted"
        },
        {
          "id": "uuid-hw-3",
          "title": "Chemical Equations",
          "subject": "Chemistry",
          "icon": "⚗️",
          "due_date": "2026-04-02",
          "max_marks": 30,
          "status": "graded",
          "submission_status": "graded",
          "marks_obtained": 27,
          "grade": "A"
        },
      ];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F8),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFBE185D), Color(0xFFDB2777)],
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
                  'Homework',
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
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _statuses.length,
              itemBuilder: (context, index) {
                final status = _statuses[index];
                final isSelected = status == _selectedStatus;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedStatus = status);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFBE185D) : StudentColors.surface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: isSelected ? Colors.white : StudentColors.text,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _homework.length,
                    itemBuilder: (context, index) {
                      final hw = _homework[index];
                      return _buildHomeworkCard(hw);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeworkCard(Map<String, dynamic> hw) {
    final isUrgent = hw['status'] == 'pending';
    final isGraded = hw['status'] == 'graded';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
          Text(hw['icon'], style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hw['title'],
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${hw['subject']} • Due: ${hw['due_date']}',
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 13,
                    color: StudentColors.text3,
                  ),
                ),
                if (isGraded) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Marks: ${hw['marks_obtained']}/${hw['max_marks']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: StudentColors.success,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Grade: ${hw['grade']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: StudentColors.success,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isUrgent
                  ? StudentColors.warningBg
                  : isGraded
                      ? StudentColors.successBg
                      : StudentColors.infoBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              hw['status'].toUpperCase(),
              style: TextStyle(
                color: isUrgent
                    ? StudentColors.warning
                    : isGraded
                        ? StudentColors.success
                        : StudentColors.info,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}