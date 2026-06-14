import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';
import 'package:flutter/material.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/services/teacher_api_service.dart';
import 'package:edu_shamiit_ai/core/models/teacher_models.dart';
import 'package:edu_shamiit_ai/shared/widgets/azure_grid.dart';

class TeacherGrading extends ConsumerStatefulWidget {
  const TeacherGrading({super.key});

  @override
  ConsumerState<TeacherGrading> createState() => _TeacherGradingState();
}

class _TeacherGradingState extends ConsumerState<TeacherGrading> {
  final TeacherApiService _apiService = TeacherApiService();

  String _selectedClass = 'X-A';
  String _selectedSubject = 'Mathematics';
  final List<String> _classes = ['X-A', 'X-B', 'X-C', 'IX-A', 'IX-B'];
  List<String> _subjects = [
    'Mathematics',
    'Physics',
    'Chemistry',
    'Biology',
    'English'
  ];

  bool _isLoading = false;
  List<TeacherHomeworkAssignment> _assignments = [];

  @override
  void initState() {
    super.initState();
    _loadSubjects().then((_) {
      if (mounted) _loadAssignments();
    });
  }

  Future<void> _loadSubjects() async {
    try {
      final subjects = await _apiService.getSubjects(allSubjects: true);
      if (subjects.isNotEmpty) {
        setState(() {
          _subjects = subjects.map((s) => s.name).toList();
          if (!_subjects.contains(_selectedSubject)) {
            _selectedSubject = _subjects.first;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading subjects in grading: $e');
    }
  }

  Future<void> _loadAssignments() async {
    setState(() => _isLoading = true);

    try {
      final assignments = await _apiService.getHomeworkAssignments(
        classId: _selectedClass,
      );
      setState(() {
        _assignments = assignments;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading assignments: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to load assignments. Please try again.'.tr(ref))),
        );
      }
    }
  }

  List<TeacherHomeworkAssignment> get _pendingSubmissions {
    return _assignments.where((a) => a.status != 'completed').toList();
  }

  String _getRelativeDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }

  List<AzureGridColumn<TeacherHomeworkAssignment>> _buildGridColumns() {
    return [
      AzureGridColumn<TeacherHomeworkAssignment>(
        label: 'Assignment Title',
        width: 180.0,
        compare: (a, b) => a.title.compareTo(b.title),
        cellBuilder: (a) => Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      AzureGridColumn<TeacherHomeworkAssignment>(
        label: 'Subject',
        width: 110.0,
        compare: (a, b) => a.subject.compareTo(b.subject),
        cellBuilder: (a) => Text(a.subject),
      ),
      AzureGridColumn<TeacherHomeworkAssignment>(
        label: 'Class',
        width: 80.0,
        compare: (a, b) => a.class_.compareTo(b.class_),
        cellBuilder: (a) => Text(a.class_),
      ),
      AzureGridColumn<TeacherHomeworkAssignment>(
        label: 'Graded',
        width: 100.0,
        compare: (a, b) => a.submittedCount.compareTo(b.submittedCount),
        cellBuilder: (a) => Text('${a.submittedCount} / ${a.totalCount}'),
      ),
      AzureGridColumn<TeacherHomeworkAssignment>(
        label: 'Pending',
        width: 90.0,
        compare: (a, b) => (a.totalCount - a.submittedCount).compareTo(b.totalCount - b.submittedCount),
        cellBuilder: (a) => Text('${a.totalCount - a.submittedCount}'),
      ),
      AzureGridColumn<TeacherHomeworkAssignment>(
        label: 'Due Date',
        width: 120.0,
        compare: (a, b) => a.dueDate.compareTo(b.dueDate),
        cellBuilder: (a) => Text('${a.dueDate.day}/${a.dueDate.month}/${a.dueDate.year}'),
      ),
      AzureGridColumn<TeacherHomeworkAssignment>(
        label: 'Max Marks',
        width: 90.0,
        compare: (a, b) => (a.maxMarks ?? 0).compareTo(b.maxMarks ?? 0),
        cellBuilder: (a) => Text('${a.maxMarks ?? 25}'),
      ),
      AzureGridColumn<TeacherHomeworkAssignment>(
        label: 'Actions',
        width: 130.0,
        cellBuilder: (a) => SizedBox(
          height: 24,
          child: ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Opening grading interface...'.tr(ref))),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0EA5E9),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              elevation: 0,
            ),
            child: const Text('Grade', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(16, Responsive.headerTopPadding(context), 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0EA5E9), Color(0xFF0369A1)],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => safeGoBack(context, '/teacher/dashboard'),
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
                  child: _buildDropdown('Class', _selectedClass, _classes,
                      (value) {
                    setState(() => _selectedClass = value!);
                    _loadAssignments();
                  }),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown('Subject', _selectedSubject, _subjects,
                      (value) {
                    setState(() => _selectedSubject = value!);
                    _loadAssignments();
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
                        '${_pendingSubmissions.fold<int>(0, (sum, a) => sum + (a.totalCount - a.submittedCount))}',
                        Colors.orange)),
                const SizedBox(width: 8),
                Expanded(
                    child: _buildStatChip(
                        'Graded',
                        '${_assignments.fold<int>(0, (sum, a) => sum + a.submittedCount)}',
                        Colors.green)),
                const SizedBox(width: 8),
                Expanded(
                    child: _buildStatChip(
                        'Total',
                        '${_assignments.fold<int>(0, (sum, a) => sum + a.totalCount)}',
                        Colors.blue)),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Assignments list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _pendingSubmissions.isEmpty
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
                    : Responsive.isWide(context)
                        ? Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: AzureGrid<TeacherHomeworkAssignment>(
                              title: 'Assignments Needing Grading',
                              items: _pendingSubmissions,
                              columns: _buildGridColumns(),
                              searchMatcher: (a) => '${a.title} ${a.subject} ${a.class_}',
                              onRefresh: _loadAssignments,
                              mobileCardBuilder: (context, a) => _buildAssignmentCard(a),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _pendingSubmissions.length,
                            itemBuilder: (context, index) {
                              return _buildAssignmentCard(
                                  _pendingSubmissions[index]);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> options,
      Function(String?) onChanged) {
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
              items: options
                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
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

  Widget _buildAssignmentCard(TeacherHomeworkAssignment assignment) {
    final submitted = assignment.submittedCount;
    final total = assignment.totalCount;
    final pending = total - submitted;
    final progress = total > 0 ? submitted.toDouble() / total : 0.0;

    return Container(
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
          Row(
            children: [
              Expanded(
                child: Text(
                  assignment.title,
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
                  '${assignment.maxMarks} marks',
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
          Row(
            children: [
              _buildMiniStat('$submitted', 'Graded', Colors.green),
              const SizedBox(width: 12),
              _buildMiniStat('$pending', 'Pending', Colors.orange),
              const SizedBox(width: 12),
              _buildMiniStat('$total', 'Total', Colors.blue),
              const Spacer(),
              Text(
                _getRelativeDate(assignment.dueDate),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF0EA5E9)),
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Opening grading interface...'.tr(ref))),
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
