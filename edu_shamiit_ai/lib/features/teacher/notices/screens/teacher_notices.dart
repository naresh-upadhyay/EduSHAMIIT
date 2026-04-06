import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';

class TeacherNotices extends StatefulWidget {
  const TeacherNotices({super.key});

  @override
  State<TeacherNotices> createState() => _TeacherNoticesState();
}

class _TeacherNoticesState extends State<TeacherNotices> {
  String _selectedTab = 'All';
  final List<String> _tabs = ['All', 'School', 'Class', 'Exam', 'Event'];

  final List<Map<String, dynamic>> _notices = [
    {
      'id': '1',
      'title': 'Staff Meeting Tomorrow',
      'content': 'All teachers are requested to attend the staff meeting at 2:00 PM in the conference room.',
      'category': 'School',
      'date': DateTime.now().subtract(const Duration(hours: 2)),
      'priority': 'high',
      'read': false,
    },
    {
      'id': '2',
      'title': 'X-A Parent-Teacher Meeting',
      'content': 'PTM scheduled for next Saturday. Please prepare progress reports for all students.',
      'category': 'Class',
      'date': DateTime.now().subtract(const Duration(days: 1)),
      'priority': 'medium',
      'read': true,
    },
    {
      'id': '3',
      'title': 'Term 2 Exam Schedule',
      'content': 'The exam schedule has been released. Please check the staff portal for details.',
      'category': 'Exam',
      'date': DateTime.now().subtract(const Duration(days: 3)),
      'priority': 'high',
      'read': true,
    },
    {
      'id': '4',
      'title': 'Annual Sports Day',
      'content': 'All teachers are requested to encourage students to participate in the upcoming Sports Day.',
      'category': 'Event',
      'date': DateTime.now().subtract(const Duration(days: 5)),
      'priority': 'low',
      'read': true,
    },
    {
      'id': '5',
      'title': 'New LMS Training',
      'content': 'Training session for the new Learning Management System will be held on Monday.',
      'category': 'School',
      'date': DateTime.now().subtract(const Duration(days: 7)),
      'priority': 'medium',
      'read': false,
    },
  ];

  List<Map<String, dynamic>> get _filteredNotices {
    if (_selectedTab == 'All') return _notices;
    return _notices.where((n) => n['category'] == _selectedTab).toList();
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high': return Colors.red;
      case 'medium': return const Color(0xFFF59E0B);
      case 'low': return Colors.green;
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
                colors: [Color(0xFF9F1239), Color(0xFFE11D48)],
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
                  'Notices',
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
                  onPressed: () => _showCreateNoticeDialog(),
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
                      color: isSelected ? const Color(0xFF9F1239) : const Color(0xFFFDF2F8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tab,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF9F1239),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Notices list
          Expanded(
            child: _filteredNotices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('📭', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 16),
                        Text(
                          'No $_selectedTab notices',
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
                    itemCount: _filteredNotices.length,
                    itemBuilder: (context, index) {
                      return _buildNoticeCard(_filteredNotices[index]);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateNoticeDialog(),
        backgroundColor: const Color(0xFF9F1239),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'New Notice',
          style: TextStyle(
            fontFamily: AppFonts.heading,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildNoticeCard(Map<String, dynamic> notice) {
    final priorityColor = _getPriorityColor(notice['priority'] as String);
    final isUnread = !(notice['read'] as bool);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnread ? priorityColor.withOpacity(0.3) : const Color(0xFFE2E8F0),
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
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: priorityColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: priorityColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        notice['category'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: priorityColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTimeAgo(notice['date'] as DateTime),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (isUnread)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9F1239),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Title
          Text(
            notice['title'] as String,
            style: const TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          // Content preview
          Text(
            notice['content'] as String,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          // Actions
          Row(
            children: [
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.visibility, size: 14),
                label: const Text(
                  'View',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9F1239)),
                ),
              ),
              if (isUnread)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      notice['read'] = true;
                    });
                  },
                  icon: const Icon(Icons.done, size: 14),
                  label: const Text(
                    'Mark Read',
                    style: TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCreateNoticeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Notice'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'Title',
                  hintText: 'Enter notice title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Content',
                  hintText: 'Enter notice details...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: ['School', 'Class', 'Exam', 'Event']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) {},
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Priority',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: ['High', 'Medium', 'Low']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) {},
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
                const SnackBar(content: Text('✅ Notice published successfully!')),
              );
            },
            child: const Text('Publish'),
          ),
        ],
      ),
    );
  }
}