import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';

class StudentNotices extends ConsumerStatefulWidget {
  const StudentNotices({super.key});

  @override
  ConsumerState<StudentNotices> createState() => _StudentNoticesState();
}

class _StudentNoticesState extends ConsumerState<StudentNotices> {
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Urgent', 'General', 'Events'];

  final List<Map<String, dynamic>> _notices = [
    {
      'id': '1',
      'title': 'Exam Hall Ticket Collection',
      'content': 'Collect your hall tickets from the school office between 9:00 AM — 3:00 PM. This is mandatory for all students appearing in the final examination starting March 28, 2025. Students without hall tickets will NOT be permitted to enter the exam hall. Please carry your school ID card for verification.',
      'category': 'Urgent',
      'isUrgent': true,
      'publishedAt': DateTime.now().subtract(const Duration(hours: 2)),
      'author': 'Principal',
    },
    {
      'id': '2',
      'title': 'Fee Payment Deadline Extended',
      'content': 'Fee submission deadline has been extended to April 5, 2025 for all students. Students must pay via the EduShamiit app or school counter. Late fees have been waived until this date. After April 5, a penalty of ₹50/day will apply. EMI options are also available through the app.',
      'category': 'Urgent',
      'isUrgent': true,
      'publishedAt': DateTime.now().subtract(const Duration(days: 1)),
      'author': 'Accounts Department',
    },
    {
      'id': '3',
      'title': 'Annual Sports Day Registration',
      'content': 'Register for Sports Day events by March 29. Events include 100m Sprint, Long Jump, Relay Race, Cricket & Badminton. Contact the Sports Department for more details.',
      'category': 'Events',
      'isUrgent': false,
      'publishedAt': DateTime.now().subtract(const Duration(days: 3)),
      'author': 'Sports Dept.',
    },
    {
      'id': '4',
      'title': 'Science Exhibition — 2025',
      'content': 'Submit project proposals by April 1. Top 3 winners get scholarships. Open to all classes. Project categories: Working Model, Chart, PowerPoint Presentation.',
      'category': 'Events',
      'isUrgent': false,
      'publishedAt': DateTime.now().subtract(const Duration(days: 5)),
      'author': 'Science Dept.',
    },
    {
      'id': '5',
      'title': 'Summer Uniform — Mandatory',
      'content': 'All students must switch to summer uniform starting April 1st. Summer uniform includes white half-sleeve shirt, grey trousers/skirt, and school ID. Winter blazers are no longer required.',
      'category': 'General',
      'isUrgent': false,
      'publishedAt': DateTime.now().subtract(const Duration(days: 1)),
      'author': 'Administration',
    },
    {
      'id': '6',
      'title': 'Parent-Teacher Meeting Date',
      'content': 'PTM scheduled for March 30, 2025 (Saturday) from 10:00 AM - 1:00 PM. Parents are requested to attend to discuss Term 2 results and academic progress. Bring the student diary.',
      'category': 'General',
      'isUrgent': false,
      'publishedAt': DateTime.now().subtract(const Duration(days: 2)),
      'author': 'Principal',
    },
  ];

  List<Map<String, dynamic>> get _filteredNotices {
    if (_selectedCategory == 'All') return _notices;
    return _notices.where((n) => n['category'] == _selectedCategory).toList();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getColorForCategory(String category) {
    switch (category) {
      case 'Urgent':
        return StudentColors.error;
      case 'Events':
        return StudentColors.warning;
      case 'General':
        return StudentColors.primary;
      default:
        return StudentColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBEB),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF92400E), Color(0xFFD97706)],
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: StudentColors.error,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_notices.where((n) => n['isUrgent']).length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Category Chips
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = category),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? StudentColors.warning : StudentColors.surface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : StudentColors.warning,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Notices List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredNotices.length,
              itemBuilder: (context, index) {
                final notice = _filteredNotices[index];
                return _buildNoticeCard(notice);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeCard(Map<String, dynamic> notice) {
    final color = _getColorForCategory(notice['category'] as String);
    
    return GestureDetector(
      onTap: () => _showNoticeDetail(notice),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: StudentColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
            ),
          ],
          border: Border(
            left: BorderSide(
              color: color,
              width: 4,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (notice['isUrgent'] == true)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '🚨 URGENT',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                if (notice['category'] == 'Events')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '🎉 EVENT',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                if (notice['category'] == 'General')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '📋 GENERAL',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              notice['title'] as String,
              style: const TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: StudentColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              notice['content'] as String,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: StudentColors.text2,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '📅 ${_formatDate(notice['publishedAt'] as DateTime)} · By ${notice['author']}',
              style: TextStyle(
                fontSize: 9,
                color: StudentColors.text3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNoticeDetail(Map<String, dynamic> notice) {
    final color = _getColorForCategory(notice['category'] as String);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: StudentColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: StudentColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (notice['isUrgent'] == true)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '🚨 URGENT',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      notice['title'] as String,
                      style: const TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: StudentColors.text,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      notice['content'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        color: StudentColors.text2,
                        height: 1.7,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: StudentColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16, color: StudentColors.text3),
                          const SizedBox(width: 8),
                          Text(
                            'Published: ${_formatDate(notice['publishedAt'] as DateTime)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: StudentColors.text3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: StudentColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person, size: 16, color: StudentColors.text3),
                          const SizedBox(width: 8),
                          Text(
                            'By ${notice['author']}',
                            style: TextStyle(
                              fontSize: 11,
                              color: StudentColors.text3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StudentColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}