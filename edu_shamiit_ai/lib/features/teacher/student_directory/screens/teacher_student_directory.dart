import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';

class TeacherStudentDirectory extends StatefulWidget {
  const TeacherStudentDirectory({super.key});

  @override
  State<TeacherStudentDirectory> createState() => _TeacherStudentDirectoryState();
}

class _TeacherStudentDirectoryState extends State<TeacherStudentDirectory> {
  String _selectedClass = 'All';
  final List<String> _classes = ['All', 'X-A', 'X-B', 'X-C', 'IX-A', 'IX-B'];

  String _searchQuery = '';

  final List<Map<String, dynamic>> _students = [
    {
      'id': '1',
      'name': 'Aarav Sharma',
      'rollNo': '1',
      'class': 'X-A',
      'email': 'aarav.sharma@edushamiit.edu',
      'phone': '+91 98765 43210',
      'attendance': 95,
      'avgMarks': 88,
      'parentName': 'Rajesh Sharma',
      'parentPhone': '+91 98765 43211',
    },
    {
      'id': '2',
      'name': 'Vivaan Patel',
      'rollNo': '2',
      'class': 'X-A',
      'email': 'vivaan.patel@edushamiit.edu',
      'phone': '+91 98765 43212',
      'attendance': 92,
      'avgMarks': 85,
      'parentName': 'Kiran Patel',
      'parentPhone': '+91 98765 43213',
    },
    {
      'id': '3',
      'name': 'Aditya Singh',
      'rollNo': '3',
      'class': 'X-A',
      'email': 'aditya.singh@edushamiit.edu',
      'phone': '+91 98765 43214',
      'attendance': 88,
      'avgMarks': 76,
      'parentName': 'Vikram Singh',
      'parentPhone': '+91 98765 43215',
    },
    {
      'id': '4',
      'name': 'Sai Reddy',
      'rollNo': '4',
      'class': 'X-B',
      'email': 'sai.reddy@edushamiit.edu',
      'phone': '+91 98765 43216',
      'attendance': 97,
      'avgMarks': 92,
      'parentName': 'Lakshmi Reddy',
      'parentPhone': '+91 98765 43217',
    },
    {
      'id': '5',
      'name': 'Arjun Kumar',
      'rollNo': '5',
      'class': 'X-B',
      'email': 'arjun.kumar@edushamiit.edu',
      'phone': '+91 98765 43218',
      'attendance': 90,
      'avgMarks': 71,
      'parentName': 'Suresh Kumar',
      'parentPhone': '+91 98765 43219',
    },
    {
      'id': '6',
      'name': 'Ishaan Gupta',
      'rollNo': '6',
      'class': 'X-C',
      'email': 'ishaan.gupta@edushamiit.edu',
      'phone': '+91 98765 43220',
      'attendance': 85,
      'avgMarks': 65,
      'parentName': 'Neha Gupta',
      'parentPhone': '+91 98765 43221',
    },
    {
      'id': '7',
      'name': 'Reyansh Yadav',
      'rollNo': '7',
      'class': 'IX-A',
      'email': 'reyansh.yadav@edushamiit.edu',
      'phone': '+91 98765 43222',
      'attendance': 93,
      'avgMarks': 58,
      'parentName': 'Amit Yadav',
      'parentPhone': '+91 98765 43223',
    },
    {
      'id': '8',
      'name': 'Ayaan Khan',
      'rollNo': '8',
      'class': 'IX-A',
      'email': 'ayaan.khan@edushamiit.edu',
      'phone': '+91 98765 43224',
      'attendance': 96,
      'avgMarks': 92,
      'parentName': 'Farhan Khan',
      'parentPhone': '+91 98765 43225',
    },
  ];

  List<Map<String, dynamic>> get _filteredStudents {
    var filtered = _students;
    if (_selectedClass != 'All') {
      filtered = filtered.where((s) => s['class'] == _selectedClass).toList();
    }
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((s) {
        final name = s['name'].toString().toLowerCase();
        final rollNo = s['rollNo'].toString().toLowerCase();
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || rollNo.contains(query);
      }).toList();
    }
    return filtered;
  }

  int get _totalStudents => _filteredStudents.length;
  double get _avgAttendance => _filteredStudents.isEmpty
      ? 0
      : _filteredStudents.fold<double>(0, (sum, s) => sum + (s['attendance'] as int)) / _filteredStudents.length;
  double get _avgMarks => _filteredStudents.isEmpty
      ? 0
      : _filteredStudents.fold<double>(0, (sum, s) => sum + (s['avgMarks'] as int)) / _filteredStudents.length;

  Color _getAttendanceColor(int attendance) {
    if (attendance >= 90) return const Color(0xFF059669);
    if (attendance >= 75) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Color _getMarksColor(int marks) {
    if (marks >= 80) return const Color(0xFF059669);
    if (marks >= 60) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
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
                  'Student Directory',
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

          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search by name or roll number...',
                        border: InputBorder.none,
                      ),
                      onChanged: (value) => setState(() => _searchQuery = value),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () => setState(() => _searchQuery = ''),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),
          ),

          // Class filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _classes.map((cls) {
                  final isSelected = _selectedClass == cls;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedClass = cls),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8, bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF0EA5E9) : const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        cls,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF0369A1),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _buildStatChip('Students', '$_totalStudents', Colors.blue)),
                const SizedBox(width: 8),
                Expanded(child: _buildStatChip('Avg Attendance', '${_avgAttendance.toInt()}%', Colors.green)),
                const SizedBox(width: 8),
                Expanded(child: _buildStatChip('Avg Marks', '${_avgMarks.toInt()}%', Colors.purple)),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Students list
          Expanded(
            child: _filteredStudents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('👥', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 16),
                        Text(
                          'No students found',
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
                    itemCount: _filteredStudents.length,
                    itemBuilder: (context, index) {
                      return _buildStudentCard(_filteredStudents[index]);
                    },
                  ),
          ),
        ],
      ),
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

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final attendanceColor = _getAttendanceColor(student['attendance'] as int);
    final marksColor = _getMarksColor(student['avgMarks'] as int);

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
          // Header row
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0EA5E9), Color(0xFF0369A1)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    student['rollNo'].toString(),
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
                      student['name'] as String,
                      style: const TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Class ${student['class']} • Roll #${student['rollNo']}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.grey),
                onPressed: () => _showStudentDetail(student),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Stats row
          Row(
            children: [
              _buildMiniStat('Attendance', '${student['attendance']}%', attendanceColor),
              const SizedBox(width: 16),
              _buildMiniStat('Avg Marks', '${student['avgMarks']}%', marksColor),
              const Spacer(),
              Text(
                student['email'] as String,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[500],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Actions
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.message, size: 14),
                  label: const Text(
                    'Message',
                    style: TextStyle(fontSize: 12, color: Color(0xFF0EA5E9)),
                  ),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.call, size: 14),
                  label: const Text(
                    'Call Parent',
                    style: TextStyle(fontSize: 12, color: Color(0xFF059669)),
                  ),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _showStudentDetail(student),
                  icon: const Icon(Icons.visibility, size: 14),
                  label: const Text(
                    'View',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6366F1)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: AppFonts.heading,
            fontSize: 14,
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

  void _showStudentDetail(Map<String, dynamic> student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0EA5E9), Color(0xFF0369A1)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      student['rollNo'].toString(),
                      style: const TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  student['name'] as String,
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Center(
                child: Text(
                  'Class ${student['class']} • Roll #${student['rollNo']}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildDetailSection('Academic Performance', [
                _buildDetailRow('Average Marks', '${student['avgMarks']}%'),
                _buildDetailRow('Attendance', '${student['attendance']}%'),
              ]),
              const SizedBox(height: 16),
              _buildDetailSection('Contact Information', [
                _buildDetailRow('Email', student['email'] as String),
                _buildDetailRow('Phone', student['phone'] as String),
              ]),
              const SizedBox(height: 16),
              _buildDetailSection('Parent/Guardian', [
                _buildDetailRow('Name', student['parentName'] as String),
                _buildDetailRow('Phone', student['parentPhone'] as String),
              ]),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.message),
                      label: const Text('Message'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0EA5E9),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.call),
                      label: const Text('Call'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: AppFonts.heading,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}