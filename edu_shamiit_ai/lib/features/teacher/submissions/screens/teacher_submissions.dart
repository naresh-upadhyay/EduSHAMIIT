import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/services/teacher_api_service.dart';
import 'package:edu_shamiit_ai/core/models/teacher_models.dart';

class TeacherSubmissions extends StatefulWidget {
  const TeacherSubmissions({super.key});

  @override
  State<TeacherSubmissions> createState() => _TeacherSubmissionsState();
}

class _TeacherSubmissionsState extends State<TeacherSubmissions> {
  final TeacherApiService _apiService = TeacherApiService();
  
  String _selectedClass = 'X-A';
  String _selectedSubject = 'Mathematics';
  final List<String> _classes = ['X-A', 'X-B', 'X-C', 'IX-A', 'IX-B'];
  final List<String> _subjects = ['Mathematics', 'Physics', 'Chemistry', 'Biology', 'English'];

  String _selectedTab = 'All';
  final List<String> _tabs = ['All', 'Pending', 'Graded', 'Late'];

  bool _isLoading = false;
  List<HomeworkSubmission> _submissions = [];

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    setState(() => _isLoading = true);
    
    try {
      // Load homework assignments for the selected class
      final homeworks = await _apiService.getHomework(
        classId: _selectedClass,
        subject: _selectedSubject,
      );
      
      // Load submissions for each homework
      final allSubmissions = <HomeworkSubmission>[];
      for (final homework in homeworks) {
        final submissions = await _apiService.getHomeworkSubmissions(homework.id);
        allSubmissions.addAll(submissions);
      }
      
      setState(() {
        _submissions = allSubmissions;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading submissions: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load submissions. Please try again.')),
        );
      }
    }
  }

  List<HomeworkSubmission> get _filteredSubmissions {
    var filtered = _submissions;
    
    if (_selectedTab != 'All') {
      final statusFilter = _selectedTab.toLowerCase();
      filtered = filtered.where((s) => s.status == statusFilter).toList();
    }
    
    return filtered;
  }

  int get _pendingCount => _submissions.where((s) => s.status == 'pending').length;
  int get _gradedCount => _submissions.where((s) => s.status == 'graded').length;
  int get _lateCount => _submissions.where((s) => s.status == 'late').length;

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return const Color(0xFFF59E0B);
      case 'graded': return const Color(0xFF059669);
      case 'late': return const Color(0xFFEF4444);
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
                  'Student Submissions',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _loadSubmissions,
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
                    setState(() {
                      _selectedClass = value!;
                      _loadSubmissions();
                    });
                  }),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown('Subject', _selectedSubject, _subjects, (value) {
                    setState(() {
                      _selectedSubject = value!;
                      _loadSubmissions();
                    });
                  }),
                ),
              ],
            ),
          ),

          // Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _buildStatChip('Pending', _pendingCount, Colors.orange)),
                const SizedBox(width: 8),
                Expanded(child: _buildStatChip('Graded', _gradedCount, Colors.green)),
                const SizedBox(width: 8),
                Expanded(child: _buildStatChip('Late', _lateCount, Colors.red)),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Tabs
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: _tabs.length,
              itemBuilder: (context, index) {
                final tab = _tabs[index];
                final isSelected = _selectedTab == tab;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTab = tab),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF0EA5E9) : const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tab,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF0369A1),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // Submissions list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredSubmissions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('📥', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 16),
                            Text(
                              _selectedTab == 'All' 
                                  ? 'No submissions found' 
                                  : 'No $_selectedTab submissions',
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
                        itemCount: _filteredSubmissions.length,
                        itemBuilder: (context, index) {
                          return _buildSubmissionCard(_filteredSubmissions[index]);
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

  Widget _buildStatChip(String label, int count, Color color) {
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
            '$count',
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 22,
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

  Widget _buildSubmissionCard(HomeworkSubmission submission) {
    final statusColor = _getStatusColor(submission.status);
    final isGraded = submission.status == 'graded';

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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    submission.studentName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0EA5E9),
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
                      submission.studentName,
                      style: const TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Homework Submission',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  submission.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // File and time info
          Row(
            children: [
              Icon(Icons.insert_drive_file, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                submission.fileUrl ?? 'submission.pdf',
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
                _formatTimeAgo(submission.submittedAt),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          // Grade info if graded
          if (isGraded && submission.marks != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, size: 14, color: Color(0xFF059669)),
                  const SizedBox(width: 8),
                  Text(
                    'Scored ${submission.marks}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Actions
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () {
                    // TODO: Navigate to view submission detail
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Opening submission viewer...')),
                    );
                  },
                  icon: const Icon(Icons.visibility, size: 14),
                  label: const Text(
                    'View',
                    style: TextStyle(fontSize: 12, color: Color(0xFF0EA5E9)),
                  ),
                ),
              ),
              if (!isGraded)
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {
                      _showGradeDialog(submission);
                    },
                    icon: const Icon(Icons.grade, size: 14),
                    label: const Text(
                      'Grade',
                      style: TextStyle(fontSize: 12, color: Color(0xFFF59E0B)),
                    ),
                  ),
                ),
              if (isGraded)
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {
                      _showGradeDialog(submission);
                    },
                    icon: const Icon(Icons.edit, size: 14),
                    label: const Text(
                      'Edit Grade',
                      style: TextStyle(fontSize: 12, color: Color(0xFF059669)),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showGradeDialog(HomeworkSubmission submission) {
    final marksController = TextEditingController();
    final remarksController = TextEditingController();
    
    // Pre-fill if already graded
    if (submission.marks != null) {
      marksController.text = submission.marks.toString();
    }
    if (submission.teacherRemarks != null) {
      remarksController.text = submission.teacherRemarks!;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Grade Submission'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Student: ${submission.studentName}'),
            const SizedBox(height: 8),
            Text('Submitted: ${_formatTimeAgo(submission.submittedAt)}'),
            const SizedBox(height: 16),
            TextField(
              controller: marksController,
              decoration: InputDecoration(
                labelText: 'Marks',
                hintText: 'Enter marks',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: remarksController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Feedback (Optional)',
                hintText: 'Enter feedback...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Show loading
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Submitting grade...')),
              );
              
              final marks = double.tryParse(marksController.text) ?? 0;
              final grade = marks >= 90 ? 'A+' : marks >= 80 ? 'A' : marks >= 70 ? 'B+' : marks >= 60 ? 'B' : marks >= 50 ? 'C' : 'D';
              
              try {
                final success = await _apiService.gradeSubmission(
                  submissionId: submission.id,
                  marks: marks,
                  grade: grade,
                  remarks: remarksController.text.isEmpty ? null : remarksController.text,
                );
                
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Grade submitted successfully!')),
                  );
                  _loadSubmissions(); // Refresh the list
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to submit grade')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Error submitting grade')),
                  );
                }
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}