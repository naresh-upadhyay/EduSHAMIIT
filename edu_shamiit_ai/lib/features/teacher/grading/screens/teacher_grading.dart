import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';

class TeacherGrading extends StatefulWidget {
  const TeacherGrading({super.key});

  @override
  State<TeacherGrading> createState() => _TeacherGradingState();
}

class _TeacherGradingState extends State<TeacherGrading> {
  String _selectedClass = 'X-A';
  String _selectedSubject = 'Mathematics';
  final List<String> _classes = ['X-A', 'X-B', 'X-C', 'IX-A', 'IX-B'];
  final List<String> _subjects = ['Mathematics', 'Physics', 'Chemistry', 'Biology', 'English'];

  final List<Map<String, dynamic>> _assignments = [
    {
      'id': '1',
      'title': 'Chapter 8 Trigonometry Test',
      'totalMarks': 50,
      'submitted': 38,
      'graded': 25,
      'dueDate': DateTime.now().subtract(const Duration(days: 2)),
      'status': 'grading',
    },
    {
      'id': '2',
      'title': 'Quadratic Equations Quiz',
      'totalMarks': 30,
      'submitted': 42,
      'graded': 42,
      'dueDate': DateTime.now().subtract(const Duration(days: 5)),
      'status': 'completed',
    },
    {
      'id': '3',
      'title': 'Statistics Project',
      'totalMarks': 100,
      'submitted': 35,
      'graded': 10,
      'dueDate': DateTime.now().subtract(const Duration(days: 1)),
      'status': 'grading',
    },
  ];

  List<Map<String, dynamic>> get _pendingSubmissions {
    return _assignments.where((a) => a['status'] == 'grading').toList();
  }

  String _getRelativeDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }

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
                colors: [Color(0xFF0EA5E9), Color(0xFF0369A1)],
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
                  'Grade Papers',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.filter_list, color: Colors.white),
                  onPressed: () {},
                ),
              ],
            ),
          ),

          // Filters
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildDropdown('Class', _selectedClass, _classes, (value) {
                    setState(() => _selectedClass = value!);
                  }),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown('Subject', _selectedSubject, _subjects, (value) {
                    setState(() => _selectedSubject = value!);
                  }),
                ),
              ],
            ),
          ),

          // Stats overview
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                    child: _buildStatChip(
                        'Pending',
                        '${_pendingSubmissions.fold<int>(0, (sum, a) => sum + (a['submitted'] as int) - (a['graded'] as int))}',
                        Colors.orange)),
                const SizedBox(width: 8),
                Expanded(
                    child: _buildStatChip(
                        'Graded',
                        '${_assignments.fold<int>(0, (sum, a) => sum + (a['graded'] as int))}',
                        Colors.green)),
                const SizedBox(width: 8),
                Expanded(
                    child: _buildStatChip(
                        'Total',
                        '${_assignments.fold<int>(0, (sum, a) => sum + (a['submitted'] as int))}',
                        Colors.blue)),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Assignments list
          Expanded(
            child: _pendingSubmissions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('📝', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 16),
                        Text(
                          'No pending grading',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pendingSubmissions.length,
                    itemBuilder: (context, index) {
                      return _buildAssignmentCard(_pendingSubmissions[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> options, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
              onChanged: onChanged,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              icon: const Icon(Icons.arrow_drop_down, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentCard(Map<String, dynamic> assignment) {
    final submitted = assignment['submitted'] as int;
    final graded = assignment['graded'] as int;
    final pending = submitted - graded;
    final progress = submitted > 0 ? graded / submitted : 0.0;

    return Container(
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
          // Title and class
          Row(
            children: [
              Expanded(
                child: Text(
                  assignment['title'] as String,
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${assignment['totalMarks']} marks',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0EA5E9),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Stats row
          Row(
            children: [
              _buildMiniStat('${graded}', 'Graded', Colors.green),
              const SizedBox(width: 12),
              _buildMiniStat('${pending}', 'Pending', Colors.orange),
              const SizedBox(width: 12),
              _buildMiniStat('${submitted}', 'Total', Colors.blue),
              const Spacer(),
              Text(
                _getRelativeDate(assignment['dueDate'] as DateTime),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0EA5E9)),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(progress * 100).toInt()}% graded',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          // Action button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // Navigate to grading interface
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening grading interface...')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Continue Grading',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String value, String label, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: AppFonts.heading,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}