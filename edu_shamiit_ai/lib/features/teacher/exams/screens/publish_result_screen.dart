import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';

class PublishResultScreen extends ConsumerStatefulWidget {
  final String examId;
  const PublishResultScreen({super.key, required this.examId});

  @override
  ConsumerState<PublishResultScreen> createState() => _PublishResultScreenState();
}

class _PublishResultScreenState extends ConsumerState<PublishResultScreen> {
  // Mock graded students checklist
  final List<Map<String, dynamic>> _grades = [
    {'rank': 1, 'name': 'Sneha Sharma', 'score': 94.0, 'percentage': '94%', 'grade': 'A+', 'status': 'PASS'},
    {'rank': 2, 'name': 'Arjun Kumar', 'score': 86.5, 'percentage': '86.5%', 'grade': 'A', 'status': 'PASS'},
    {'rank': 3, 'name': 'Rahul Verma', 'score': 54.0, 'percentage': '54%', 'grade': 'C', 'status': 'PASS'},
    {'rank': 4, 'name': 'Pooja Patel', 'score': 32.0, 'percentage': '32%', 'grade': 'F', 'status': 'FAIL'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Publish Exam Results',
          style: TextStyle(
            fontFamily: AppFonts.heading,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF6366F1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => safeGoBack(context, '/teacher/dashboard'),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status Info Banner
            _buildNotificationStatusBanner(),

            // List of student ranks & grades preview
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _grades.length,
                itemBuilder: (context, index) {
                  return _buildStudentGradeRow(_grades[index]);
                },
              ),
            ),

            // Stepper progress action bar
            _buildActionFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationStatusBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: const Row(
        children: [
          Icon(Icons.mark_email_read_outlined, color: Color(0xFF10B981)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'All student answers have been graded. Review final ranks and marks before publishing.',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentGradeRow(Map<String, dynamic> gradeInfo) {
    final status = gradeInfo['status'] as String;
    final isPass = status == 'PASS';

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          children: [
            // Rank Badge
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: gradeInfo['rank'] == 1 ? Colors.amber.withValues(alpha: 0.15) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '#${gradeInfo['rank']}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: gradeInfo['rank'] == 1 ? Colors.amber.shade800 : Colors.grey,
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
                  Text(gradeInfo['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text('Grade: ${gradeInfo['grade']} • ${gradeInfo['percentage']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),

            // Pass/Fail status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isPass ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isPass ? Colors.green : Colors.red,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Downloading Excel worksheet report...')),
                );
              },
              icon: const Icon(Icons.file_download_outlined, size: 16),
              label: const Text('Export Excel'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _publishAndNotify,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Publish & Notify'),
            ),
          ),
        ],
      ),
    );
  }

  void _publishAndNotify() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Publish Results?'),
        content: const Text('This will make grades instantly visible on student portals and dispatch notification emails to parents.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('🎉 Exam results successfully published and notified!')),
              );
              // Push to analytics to close the flow
              context.pushReplacement('/teacher/exams/analytics/${widget.examId}');
            },
            child: const Text('Publish Now'),
          ),
        ],
      ),
    );
  }
}
