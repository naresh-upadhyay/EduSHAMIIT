import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';

class TeacherGradebook extends StatefulWidget {
  const TeacherGradebook({super.key});

  @override
  State<TeacherGradebook> createState() => _TeacherGradebookState();
}

class _TeacherGradebookState extends State<TeacherGradebook> {
  String _selectedClass = 'X-A';
  String _selectedAssessment = 'All';
  final List<String> _classes = ['X-A', 'X-B', 'X-C', 'IX-A', 'IX-B'];
  final List<String> _assessments = ['All', 'Term 1', 'Term 2', 'Unit Test 1', 'Unit Test 2'];

  final List<Map<String, dynamic>> _students = [
    {'id': '1', 'name': 'Aarav Sharma', 'rollNo': '1', 'marks': 95, 'grade': 'A1', 'trend': 'up'},
    {'id': '2', 'name': 'Vivaan Patel', 'rollNo': '2', 'marks': 88, 'grade': 'A1', 'trend': 'stable'},
    {'id': '3', 'name': 'Aditya Singh', 'rollNo': '3', 'marks': 76, 'grade': 'A2', 'trend': 'down'},
    {'id': '4', 'name': 'Sai Reddy', 'rollNo': '4', 'marks': 82, 'grade': 'A1', 'trend': 'up'},
    {'id': '5', 'name': 'Arjun Kumar', 'rollNo': '5', 'marks': 71, 'grade': 'A2', 'trend': 'stable'},
    {'id': '6', 'name': 'Ishaan Gupta', 'rollNo': '6', 'marks': 65, 'grade': 'B1', 'trend': 'up'},
    {'id': '7', 'name': 'Reyansh Yadav', 'rollNo': '7', 'marks': 58, 'grade': 'B2', 'trend': 'down'},
    {'id': '8', 'name': 'Ayaan Khan', 'rollNo': '8', 'marks': 92, 'grade': 'A1', 'trend': 'stable'},
    {'id': '9', 'name': 'Vihaan Joshi', 'rollNo': '9', 'marks': 45, 'grade': 'C1', 'trend': 'down'},
    {'id': '10', 'name': 'Dhruv Mehta', 'rollNo': '10', 'marks': 78, 'grade': 'A2', 'trend': 'up'},
  ];

  double get _averageMarks {
    return _students.fold<double>(0, (sum, s) => sum + (s['marks'] as int)) / _students.length;
  }

  String get _averageGrade {
    final avg = _averageMarks;
    if (avg >= 90) return 'A1';
    if (avg >= 80) return 'A1';
    if (avg >= 70) return 'A2';
    if (avg >= 60) return 'B1';
    if (avg >= 50) return 'B2';
    if (avg >= 40) return 'C1';
    return 'C2';
  }

  Color _getGradeColor(String grade) {
    if (grade.startsWith('A')) return Colors.green;
    if (grade.startsWith('B')) return const Color(0xFF3B82F6);
    if (grade.startsWith('C')) return const Color(0xFFF59E0B);
    return Colors.red;
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
                  'Gradebook',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.download, color: Colors.white),
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
                  child: _buildDropdown('Assessment', _selectedAssessment, _assessments, (value) {
                    setState(() => _selectedAssessment = value!);
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
                Expanded(child: _buildStatChip('Average', '${_averageMarks.toInt()}%', Colors.blue)),
                const SizedBox(width: 8),
                Expanded(child: _buildStatChip('Grade', _averageGrade, _getGradeColor(_averageGrade))),
                const SizedBox(width: 8),
                Expanded(child: _buildStatChip('Students', '${_students.length}', Colors.purple)),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Student grades list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _students.length,
              itemBuilder: (context, index) {
                return _buildStudentGradeTile(_students[index]);
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

  Widget _buildStudentGradeTile(Map<String, dynamic> student) {
    final grade = student['grade'] as String;
    final gradeColor = _getGradeColor(grade);
    final trend = student['trend'] as String;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Roll number
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                student['rollNo'] as String,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4F46E5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student['name'] as String,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      trend == 'up' ? Icons.trending_up : trend == 'down' ? Icons.trending_down : Icons.remove,
                      size: 12,
                      color: trend == 'up' ? Colors.green : trend == 'down' ? Colors.red : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      trend == 'up' ? 'Improving' : trend == 'down' ? 'Declining' : 'Stable',
                      style: TextStyle(
                        fontSize: 10,
                        color: trend == 'up' ? Colors.green : trend == 'down' ? Colors.red : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Marks
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${student['marks']}%',
                style: const TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: gradeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  grade,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: gradeColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}