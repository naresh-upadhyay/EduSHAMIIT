import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';

class TeacherExams extends StatefulWidget {
  const TeacherExams({super.key});

  @override
  State<TeacherExams> createState() => _TeacherExamsState();
}

class _TeacherExamsState extends State<TeacherExams> {
  String _selectedTab = 'Upcoming';
  final List<String> _tabs = ['Upcoming', 'Active', 'Completed'];

  final List<Map<String, dynamic>> _exams = [
    {
      'id': '1',
      'title': 'Term 2 Mathematics',
      'class': 'X-A',
      'subject': 'Mathematics',
      'date': DateTime.now().add(const Duration(days: 5)),
      'time': '09:00 AM - 12:00 PM',
      'duration': '3 hours',
      'students': 42,
      'status': 'upcoming',
      'type': 'Term Exam',
    },
    {
      'id': '2',
      'title': 'Unit Test 3 - Physics',
      'class': 'IX-A',
      'subject': 'Physics',
      'date': DateTime.now().add(const Duration(days: 2)),
      'time': '10:00 AM - 11:00 AM',
      'duration': '1 hour',
      'students': 35,
      'status': 'upcoming',
      'type': 'Unit Test',
    },
    {
      'id': '3',
      'title': 'Term 2 Mathematics',
      'class': 'X-B',
      'subject': 'Mathematics',
      'date': DateTime.now().subtract(const Duration(days: 1)),
      'time': '09:00 AM - 12:00 PM',
      'duration': '3 hours',
      'students': 38,
      'status': 'active',
      'type': 'Term Exam',
    },
    {
      'id': '4',
      'title': 'Term 1 Mathematics',
      'class': 'X-A',
      'subject': 'Mathematics',
      'date': DateTime.now().subtract(const Duration(days: 30)),
      'time': '09:00 AM - 12:00 PM',
      'duration': '3 hours',
      'students': 42,
      'status': 'completed',
      'type': 'Term Exam',
      'avgScore': 78.5,
    },
    {
      'id': '5',
      'title': 'Unit Test 2 - Physics',
      'class': 'IX-A',
      'subject': 'Physics',
      'date': DateTime.now().subtract(const Duration(days: 15)),
      'time': '10:00 AM - 11:00 AM',
      'duration': '1 hour',
      'students': 35,
      'status': 'completed',
      'type': 'Unit Test',
      'avgScore': 72.3,
    },
  ];

  List<Map<String, dynamic>> get _filteredExams {
    return _exams.where((e) => e['status'] == _selectedTab.toLowerCase()).toList();
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _getRelativeDate(DateTime date) {
    final diff = date.difference(DateTime.now());
    if (diff.isNegative) {
      final days = (-diff.inDays);
      return '$days days ago';
    }
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Tomorrow';
    return 'In ${diff.inDays} days';
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Term Exam': return const Color(0xFF4F46E5);
      case 'Unit Test': return const Color(0xFF0EA5E9);
      case 'Quiz': return const Color(0xFFF59E0B);
      default: return Colors.grey;
    }
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
                  'Exams',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: () => _showCreateExamDialog(),
                ),
              ],
            ),
          ),

          // Tabs
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _tabs.length,
              itemBuilder: (context, index) {
                final tab = _tabs[index];
                final isSelected = _selectedTab == tab;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTab = tab),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tab,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF4F46E5),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Exams list
          Expanded(
            child: _filteredExams.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('📋', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 16),
                        Text(
                          'No $_selectedTab exams',
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
                    itemCount: _filteredExams.length,
                    itemBuilder: (context, index) {
                      return _buildExamCard(_filteredExams[index]);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateExamDialog(),
        backgroundColor: const Color(0xFF4F46E5),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Create Exam',
          style: TextStyle(
            fontFamily: AppFonts.heading,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildExamCard(Map<String, dynamic> exam) {
    final typeColor = _getTypeColor(exam['type'] as String);
    final isUpcoming = exam['status'] == 'upcoming';
    final isActive = exam['status'] == 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? const Color(0xFF059669).withOpacity(0.3) : const Color(0xFFE2E8F0),
        ),
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
              Expanded(
                child: Text(
                  exam['title'] as String,
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
                  color: typeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  exam['type'] as String,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: typeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Subject and class
          Row(
            children: [
              Text(
                exam['subject'] as String,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Class ${exam['class']}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Date and time
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                _formatDate(exam['date'] as DateTime),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                exam['time'] as String,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Additional info
          Row(
            children: [
              Icon(Icons.people, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                '${exam['students']} students',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.timer, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                exam['duration'] as String,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
              const Spacer(),
              if (isUpcoming)
                Text(
                  _getRelativeDate(exam['date'] as DateTime),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF4F46E5),
                  ),
                ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'ONGOING',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF059669),
                    ),
                  ),
                ),
              if (exam['status'] == 'completed' && exam['avgScore'] != null)
                Text(
                  'Avg: ${exam['avgScore']}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF059669),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Actions
          Row(
            children: [
              if (isUpcoming) ...[
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.edit, size: 14),
                    label: const Text(
                      'Edit',
                      style: TextStyle(fontSize: 12, color: Color(0xFF4F46E5)),
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.send, size: 14),
                    label: const Text(
                      'Send',
                      style: TextStyle(fontSize: 12, color: Color(0xFF059669)),
                    ),
                  ),
                ),
              ],
              if (isActive) ...[
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Monitor',
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
              if (exam['status'] == 'completed') ...[
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.bar_chart, size: 14),
                    label: const Text(
                      'Results',
                      style: TextStyle(fontSize: 12, color: Color(0xFF4F46E5)),
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.download, size: 14),
                    label: const Text(
                      'Export',
                      style: TextStyle(fontSize: 12, color: Color(0xFF059669)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showCreateExamDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Exam'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'Exam Title',
                  hintText: 'e.g., Term 2 Mathematics',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Class',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: ['X-A', 'X-B', 'X-C', 'IX-A', 'IX-B']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) {},
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Subject',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: ['Mathematics', 'Physics', 'Chemistry', 'Biology', 'English']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (value) {},
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Date',
                  hintText: 'Select date',
                  prefixIcon: const Icon(Icons.calendar_today),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                readOnly: true,
                onTap: () {
                  // Would show date picker
                },
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Duration',
                  hintText: 'e.g., 3 hours',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Exam created successfully!')),
              );
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}