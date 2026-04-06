import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';

class TeacherHomework extends StatefulWidget {
  const TeacherHomework({super.key});

  @override
  State<TeacherHomework> createState() => _TeacherHomeworkState();
}

class _TeacherHomeworkState extends State<TeacherHomework> {
  String _selectedTab = 'Active';
  final List<String> _tabs = ['Active', 'Pending', 'Completed'];

  final List<Map<String, dynamic>> _homework = [
    {
      'id': '1',
      'title': 'Trigonometry Problems Ch-8',
      'description': 'Solve problems 1-20 from Chapter 8',
      'class': 'X-A',
      'subject': 'Mathematics',
      'dueDate': DateTime.now().add(const Duration(days: 2)),
      'submitted': 32,
      'total': 42,
      'status': 'active',
    },
    {
      'id': '2',
      'title': 'Quadratic Equations',
      'description': 'Complete exercises from page 45-48',
      'class': 'X-B',
      'subject': 'Mathematics',
      'dueDate': DateTime.now().subtract(const Duration(days: 1)),
      'submitted': 35,
      'total': 38,
      'status': 'pending',
    },
    {
      'id': '3',
      'title': 'Statistics Project',
      'description': 'Create a project on data analysis',
      'class': 'X-C',
      'subject': 'Mathematics',
      'dueDate': DateTime.now().subtract(const Duration(days: 5)),
      'submitted': 40,
      'total': 40,
      'status': 'completed',
    },
  ];

  List<Map<String, dynamic>> get _filteredHomework {
    switch (_selectedTab) {
      case 'Pending':
        return _homework.where((h) => h['status'] == 'pending').toList();
      case 'Completed':
        return _homework.where((h) => h['status'] == 'completed').toList();
      default:
        return _homework.where((h) => h['status'] == 'active').toList();
    }
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _getRelativeDate(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now);
    
    if (diff.isNegative) return 'Overdue';
    if (diff.inDays == 0) return 'Due Today';
    if (diff.inDays == 1) return 'Due Tomorrow';
    return 'Due in ${diff.inDays} days';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F8),
      body: Column(
        children: [
          // Header
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
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: () => _showCreateHomeworkDialog(),
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
                      color: isSelected ? const Color(0xFFBE185D) : const Color(0xFFFCE7F3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tab,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFFBE185D),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Homework list
          Expanded(
            child: _filteredHomework.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('📭', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 16),
                        Text(
                          'No $_selectedTab homework',
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
                    itemCount: _filteredHomework.length,
                    itemBuilder: (context, index) {
                      return _buildHomeworkCard(_filteredHomework[index]);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateHomeworkDialog(),
        backgroundColor: const Color(0xFFBE185D),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Create Homework',
          style: TextStyle(
            fontFamily: AppFonts.heading,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildHomeworkCard(Map<String, dynamic> homework) {
    final isOverdue = _getRelativeDate(homework['dueDate'] as DateTime) == 'Overdue';
    final submissionRate = (homework['submitted'] as int) / (homework['total'] as int) * 100;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOverdue ? Colors.red.withOpacity(0.3) : const Color(0xFFE2E8F0),
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
          // Title and class
          Row(
            children: [
              Expanded(
                child: Text(
                  homework['title'] as String,
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
                  color: const Color(0xFFBE185D).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  homework['class'] as String,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFBE185D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Description
          Text(
            homework['description'] as String,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          // Meta info
          Row(
            children: [
              Icon(Icons.calendar_today, size: 12, color: isOverdue ? Colors.red : Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                _getRelativeDate(homework['dueDate'] as DateTime),
                style: TextStyle(
                  fontSize: 11,
                  color: isOverdue ? Colors.red : Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.people, size: 12, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                '${homework['submitted']}/${homework['total']} submitted',
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
              value: submissionRate / 100,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                isOverdue ? Colors.red : const Color(0xFFBE185D),
              ),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${submissionRate.toInt()}% submitted',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          // Actions
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.edit, size: 14),
                  label: const Text(
                    'Edit',
                    style: TextStyle(fontSize: 12, color: Color(0xFFBE185D)),
                  ),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.check_circle, size: 14),
                  label: const Text(
                    'Review',
                    style: TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCreateHomeworkDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Homework'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g., Trigonometry Problems',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter homework details...',
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
              TextField(
                decoration: InputDecoration(
                  labelText: 'Due Date',
                  hintText: 'Select date',
                  prefixIcon: const Icon(Icons.calendar_today),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                readOnly: true,
                onTap: () {
                  // Would show date picker in real app
                },
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
                const SnackBar(content: Text('✅ Homework created successfully!')),
              );
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}