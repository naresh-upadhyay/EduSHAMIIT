import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/services/teacher_api_service.dart';
import 'package:edu_shamiit_ai/core/models/teacher_models.dart';
import 'package:edu_shamiit_ai/shared/widgets/azure_grid.dart';

class TeacherExams extends ConsumerStatefulWidget {
  const TeacherExams({super.key});

  @override
  ConsumerState<TeacherExams> createState() => _TeacherExamsState();
}

class _TeacherExamsState extends ConsumerState<TeacherExams> {
  final TeacherApiService _apiService = TeacherApiService();
  
  List<TeacherExam> _allExams = [];
  List<String> _categories = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  Future<void> _loadExams() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final exams = await _apiService.getExams();
      
      // Sort exams in sorted order most recent first by default
      exams.sort((a, b) {
        final dateA = a.createdAt ?? a.startTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = b.createdAt ?? b.startTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });
      
      final Set<String> catSet = {};
      for (var e in exams) {
        if (e.examCategory.trim().isNotEmpty) {
          catSet.add(e.examCategory.trim());
        }
      }
      final dynamicCats = catSet.toList()..sort();

      setState(() {
        _allExams = exams;
        _categories = dynamicCats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Color _getTypeColor(String category) {
    switch (category.toLowerCase()) {
      case 'term':
      case 'mid term':
        return Colors.blue;
      case 'unit':
      case 'unit test':
      case 'weekly test':
        return Colors.green;
      case 'quiz':
      case 'practice test':
        return Colors.orange;
      case 'final':
      case 'final exam':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatExamDateTime(TeacherExam exam) {
    if (exam.startTime == null) {
      return 'Not scheduled';
    }
    final dateStr = exam.examDate.toString().split(' ')[0];
    final localStart = exam.startTime!.toLocal();
    final hour = localStart.hour;
    final minute = localStart.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$dateStr at $formattedHour:$minute $period';
  }

  String _formatReleaseDateTime(DateTime releaseTime) {
    final localRelease = releaseTime.toLocal();
    final dateStr = localRelease.toString().split(' ')[0];
    final hour = localRelease.hour;
    final minute = localRelease.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$dateStr at $formattedHour:$minute $period';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return Colors.blue;
      case 'in_progress':
        return Colors.orange;
      case 'ready':
      case 'scheduled':
        return Colors.green;
      case 'published':
        return Colors.purple;
      case 'completed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return 'New';
      case 'in_progress':
        return 'In progress';
      case 'ready':
      case 'scheduled':
        return 'Ready';
      case 'published':
        return 'Published';
      case 'completed':
        return 'Completed';
      default:
        if (status.isEmpty) return 'New';
        return status[0].toUpperCase() + status.substring(1);
    }
  }

  IconData _getPrimaryActionIcon(TeacherExam exam) {
    final now = DateTime.now();
    final start = exam.startTime ?? exam.examDate;
    final digits = exam.duration.replaceAll(RegExp(r'[^0-9]'), '');
    final durationMins = int.tryParse(digits) ?? 90;
    final end = exam.endTime ?? start.add(Duration(minutes: durationMins));
    
    if (exam.questionCount == 0) {
      return Icons.build_circle_outlined;
    }
    
    final status = exam.status.toLowerCase();
    if (status == 'new' || status == 'in_progress' || status == 'draft') {
      return Icons.assignment_ind_outlined;
    }
    
    if (now.isBefore(start)) {
      return Icons.assignment_ind_outlined;
    }
    
    if (now.isAfter(start) && now.isBefore(end)) {
      return exam.examType.toLowerCase() == 'online' ? Icons.security_outlined : Icons.people_outline;
    }
    
    return Icons.check_circle_outline;
  }

  String _getPrimaryActionLabel(TeacherExam exam) {
    final now = DateTime.now();
    final start = exam.startTime ?? exam.examDate;
    final digits = exam.duration.replaceAll(RegExp(r'[^0-9]'), '');
    final durationMins = int.tryParse(digits) ?? 90;
    final end = exam.endTime ?? start.add(Duration(minutes: durationMins));
    
    if (exam.questionCount == 0) {
      return 'Build Paper';
    }
    
    final status = exam.status.toLowerCase();
    if (status == 'new' || status == 'in_progress' || status == 'draft') {
      return 'Assign';
    }
    
    if (now.isBefore(start)) {
      return 'Assign';
    }
    
    if (now.isAfter(start) && now.isBefore(end)) {
      return exam.examType.toLowerCase() == 'online' ? 'Proctor' : 'Attendance';
    }
    
    return 'Evaluate';
  }

  Color _getPrimaryActionColor(TeacherExam exam) {
    final now = DateTime.now();
    final start = exam.startTime ?? exam.examDate;
    final digits = exam.duration.replaceAll(RegExp(r'[^0-9]'), '');
    final durationMins = int.tryParse(digits) ?? 90;
    final end = exam.endTime ?? start.add(Duration(minutes: durationMins));
    
    if (exam.questionCount == 0) {
      return const Color(0xFF6366F1);
    }
    
    final status = exam.status.toLowerCase();
    if (status == 'new' || status == 'in_progress' || status == 'draft') {
      return const Color(0xFF0EA5E9);
    }
    
    if (now.isBefore(start)) {
      return const Color(0xFF0F766E);
    }
    
    if (now.isAfter(start) && now.isBefore(end)) {
      return const Color(0xFFEF4444);
    }
    
    return const Color(0xFF10B981);
  }

  void _navigateByStatus(TeacherExam exam) {
    final now = DateTime.now();
    final start = exam.startTime ?? exam.examDate;
    final digits = exam.duration.replaceAll(RegExp(r'[^0-9]'), '');
    final durationMins = int.tryParse(digits) ?? 90;
    final end = exam.endTime ?? start.add(Duration(minutes: durationMins));
    
    if (exam.questionCount == 0) {
      context.push('/teacher/exams/paper-builder?examId=${exam.id}');
      return;
    }
    
    final status = exam.status.toLowerCase();
    if (status == 'new' || status == 'in_progress' || status == 'draft') {
      context.push('/teacher/exams/assign/${exam.id}');
      return;
    }
    
    if (now.isBefore(start)) {
      context.push('/teacher/exams/assign/${exam.id}');
      return;
    }
    
    if (now.isAfter(start) && now.isBefore(end)) {
      context.push('/teacher/exams/monitor/${exam.id}');
      return;
    }
    
    context.push('/teacher/exams/evaluate/${exam.id}');
  }

  List<AzureGridColumn<TeacherExam>> _buildGridColumns() {
    return [
      AzureGridColumn<TeacherExam>(
        label: 'Exam Title',
        width: 170.0,
        compare: (a, b) => a.title.compareTo(b.title),
        cellBuilder: (exam) => Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: exam.examType.toLowerCase() == 'online'
                    ? const Color(0xFFEEF2FF)
                    : const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                exam.examType.toLowerCase() == 'online' ? '🖥️' : '📝',
                style: const TextStyle(fontSize: 10),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                exam.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      AzureGridColumn<TeacherExam>(
        label: 'Subject & Marks',
        width: 130.0,
        compare: (a, b) => a.subject.compareTo(b.subject),
        cellBuilder: (exam) => Text('${exam.subject} (${exam.totalMarks}M)'),
      ),
      AzureGridColumn<TeacherExam>(
        label: 'Class',
        width: 80.0,
        compare: (a, b) => a.class_.compareTo(b.class_),
        cellBuilder: (exam) => Text(exam.class_),
      ),
      AzureGridColumn<TeacherExam>(
        label: 'Date & Time',
        width: 160.0,
        cellBuilder: (exam) => Text(_formatExamDateTime(exam)),
      ),
      AzureGridColumn<TeacherExam>(
        label: 'Duration',
        width: 85.0,
        cellBuilder: (exam) => Text(exam.duration),
      ),
      AzureGridColumn<TeacherExam>(
        label: 'Qns',
        width: 60.0,
        compare: (a, b) => a.questionCount.compareTo(b.questionCount),
        cellBuilder: (exam) => Text(exam.questionCount.toString()),
      ),
      AzureGridColumn<TeacherExam>(
        label: 'Status',
        width: 100.0,
        compare: (a, b) => a.status.compareTo(b.status),
        cellBuilder: (exam) {
          final color = _getStatusColor(exam.status);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              _getStatusLabel(exam.status),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          );
        },
      ),
      AzureGridColumn<TeacherExam>(
        label: 'Join/Comp',
        width: 90.0,
        cellBuilder: (exam) {
          final now = DateTime.now();
          final start = exam.startTime ?? exam.examDate;
          final digits = exam.duration.replaceAll(RegExp(r'[^0-9]'), '');
          final durationMins = int.tryParse(digits) ?? 90;
          final end = exam.endTime ?? start.add(Duration(minutes: durationMins));
          final isCompleted = exam.status.toLowerCase() == 'completed' || now.isAfter(end);
          if (isCompleted) {
            return Text('${exam.joinedCount}/${exam.completedCount}');
          }
          return const Text('-');
        },
      ),
      AzureGridColumn<TeacherExam>(
        label: 'Actions',
        width: 160.0,
        cellBuilder: (exam) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 24,
              child: ElevatedButton.icon(
                onPressed: () => _navigateByStatus(exam),
                icon: Icon(_getPrimaryActionIcon(exam), size: 10, color: Colors.white),
                label: Text(
                  _getPrimaryActionLabel(exam),
                  style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getPrimaryActionColor(exam),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 14, color: Colors.blue),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => context.push('/teacher/exams/edit/${exam.id}'),
              tooltip: 'Edit Details',
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.more_vert_rounded, size: 14, color: Colors.grey),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _showExamActionsMenu(exam),
              tooltip: 'More Actions',
            ),
          ],
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
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
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
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _loadExams,
                  tooltip: 'Refresh',
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: () => context.push('/teacher/exams/create'),
                  tooltip: 'Create Exam',
                ),
              ],
            ),
          ),

          // Quick Actions Row
          _buildQuickActionsRow(),

          // Main data grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.red),
                            const SizedBox(height: 16),
                            Text('Error: $_error', style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadExams,
                              child: Text('Retry'.tr(ref)),
                            ),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                        child: AzureGrid<TeacherExam>(
                          title: 'Scheduled Exams',
                          items: _allExams,
                          columns: _buildGridColumns(),
                          searchMatcher: (exam) => '${exam.title} ${exam.subject} ${exam.class_} ${exam.examCategory}',
                          filters: [
                            if (_categories.isNotEmpty)
                              AzureGridFilter<TeacherExam>(
                                label: 'Category',
                                options: _categories,
                                filterFn: (exam, option) => exam.examCategory.trim().toLowerCase() == option.trim().toLowerCase(),
                              ),
                            AzureGridFilter<TeacherExam>(
                              label: 'Status',
                              options: ['New', 'In Progress', 'Ready', 'Published', 'Completed'],
                              filterFn: (exam, option) => exam.status.toLowerCase().replaceAll(' ', '_') == option.toLowerCase().replaceAll(' ', '_'),
                            ),
                            AzureGridFilter<TeacherExam>(
                              label: 'Mode',
                              options: ['Online', 'Offline'],
                              filterFn: (exam, option) => exam.examType.toLowerCase() == option.toLowerCase(),
                            ),
                          ],
                          onRefresh: _loadExams,
                          mobileCardBuilder: (context, exam) => _buildExamCard(exam),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'teacher_exams_fab',
        onPressed: () => context.push('/teacher/exams/create'),
        backgroundColor: const Color(0xFF6366F1),
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

  Widget _buildExamCard(TeacherExam exam) {
    final typeColor = _getTypeColor(exam.examCategory);
    
    final now = DateTime.now();
    final start = exam.startTime ?? exam.examDate;
    final digits = exam.duration.replaceAll(RegExp(r'[^0-9]'), '');
    final durationMins = int.tryParse(digits) ?? 90;
    final end = exam.endTime ?? start.add(Duration(minutes: durationMins));
    
    final isUpcoming = now.isBefore(start);
    final isCompleted = exam.status.toLowerCase() == 'completed' || now.isAfter(end);
    
    return GestureDetector(
      onTap: () => _navigateByStatus(exam),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUpcoming ? typeColor.withOpacity(0.3) : const Color(0xFFE2E8F0),
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
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exam.title,
                        style: const TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: exam.examType.toLowerCase() == 'online'
                                  ? const Color(0xFFEEF2FF)
                                  : const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: exam.examType.toLowerCase() == 'online'
                                    ? const Color(0xFFC7D2FE)
                                    : const Color(0xFFFED7AA),
                              ),
                            ),
                            child: Text(
                              exam.examType.toLowerCase() == 'online' ? '🖥️ Online' : '📝 Offline',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: exam.examType.toLowerCase() == 'online'
                                    ? const Color(0xFF4F46E5)
                                    : const Color(0xFFEA580C),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        exam.examCategory,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: typeColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(exam.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getStatusLabel(exam.status),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(exam.status),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      _formatExamDateTime(exam),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      exam.duration,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.class_, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Class ${exam.class_}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.help_outline, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '${exam.questionCount} ${exam.questionCount == 1 ? "Question" : "Questions"}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
            if ((exam.status.toLowerCase() == 'ready' || exam.status.toLowerCase() == 'scheduled') && exam.releaseTime != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.publish, size: 12, color: Colors.indigo),
                  const SizedBox(width: 4),
                  Text(
                     'Publish release: ${_formatReleaseDateTime(exam.releaseTime!)}',
                    style: const TextStyle(fontSize: 12, color: Colors.indigo, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
            if (isCompleted) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.people_alt_outlined, size: 12, color: Colors.teal),
                  const SizedBox(width: 4),
                  Text(
                    'Joined: ${exam.joinedCount} • Completed: ${exam.completedCount}',
                    style: const TextStyle(fontSize: 12, color: Colors.teal, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${exam.subject} • ${exam.totalMarks} marks',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (exam.roomNumber != null)
                  Text(
                    ' • Room ${exam.roomNumber}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                const Spacer(),
                if (isCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Completed',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(height: 24, thickness: 1, color: Color(0xFFF1F5F9)),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _navigateByStatus(exam),
                    icon: Icon(_getPrimaryActionIcon(exam), size: 14, color: Colors.white),
                    label: Text(
                      _getPrimaryActionLabel(exam),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getPrimaryActionColor(exam),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => context.push('/teacher/exams/edit/${exam.id}'),
                  icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF64748B)),
                  tooltip: 'Edit Details',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    padding: const EdgeInsets.all(8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => _showExamActionsMenu(exam),
                  icon: const Icon(Icons.more_horiz_rounded, size: 18, color: Color(0xFF64748B)),
                  tooltip: 'More Actions',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    padding: const EdgeInsets.all(8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: _buildActionCard(
              'Question Bank',
              '📚',
              const Color(0xFFEFF6FF),
              const Color(0xFF1E40AF),
              () => context.push('/teacher/exams/question-bank'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildActionCard(
              'Paper Builder',
              '🛠️',
              const Color(0xFFFDF2F8),
              const Color(0xFF9D174D),
              () => context.push('/teacher/exams/paper-builder'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildActionCard(
              'New Exam',
              '✍️',
              const Color(0xFFECFDF5),
              const Color(0xFF065F46),
              () => context.push('/teacher/exams/create'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(String title, String emoji, Color bgColor, Color textColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: textColor.withOpacity(0.15)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridActionItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color.withOpacity(0.9),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showExamActionsMenu(TeacherExam exam) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                exam.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: AppFonts.heading),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                '${exam.subject} • Class ${exam.class_}',
                style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
              const Divider(height: 24),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.6,
                        children: [
                          _buildGridActionItem(
                            icon: Icons.assignment_ind,
                            label: 'Assign Classes',
                            color: Colors.indigo,
                            onTap: () {
                              Navigator.pop(context);
                              context.push('/teacher/exams/assign/${exam.id}');
                            },
                          ),
                          _buildGridActionItem(
                            icon: Icons.edit,
                            label: 'Edit Details',
                            color: Colors.blue,
                            onTap: () {
                              Navigator.pop(context);
                              context.push('/teacher/exams/edit/${exam.id}');
                            },
                          ),
                          _buildGridActionItem(
                            icon: Icons.security,
                            label: 'Live Proctor',
                            color: Colors.redAccent,
                            onTap: () {
                              Navigator.pop(context);
                              context.push('/teacher/exams/monitor/${exam.id}');
                            },
                          ),
                          _buildGridActionItem(
                            icon: Icons.check_circle_outline,
                            label: 'Evaluate Answers',
                            color: Colors.green,
                            onTap: () {
                              Navigator.pop(context);
                              context.push('/teacher/exams/evaluate/${exam.id}');
                            },
                          ),
                          _buildGridActionItem(
                            icon: Icons.publish,
                            label: 'Publish Results',
                            color: Colors.orange,
                            onTap: () {
                              Navigator.pop(context);
                              context.push('/teacher/exams/publish/${exam.id}');
                            },
                          ),
                          _buildGridActionItem(
                            icon: Icons.analytics,
                            label: 'View Analytics',
                            color: Colors.purple,
                            onTap: () {
                              Navigator.pop(context);
                              context.push('/teacher/exams/analytics/${exam.id}');
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        tileColor: Colors.red.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.red.shade100),
                        ),
                        leading: const Icon(Icons.delete_forever, color: Colors.red),
                        title: const Text(
                          'Delete Exam Settings',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        trailing: const Icon(Icons.chevron_right, color: Colors.red),
                        onTap: () {
                          Navigator.pop(context);
                          _confirmDeleteExam(exam);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteExam(TeacherExam exam) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Exam'),
        content: Text('Are you sure you want to delete "${exam.title}"? This will also remove any student submissions and proctoring sessions.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                _isLoading = true;
              });
              try {
                await _apiService.deleteExam(exam.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Exam deleted successfully')),
                );
                _loadExams();
              } catch (e) {
                setState(() {
                  _isLoading = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to delete exam: $e')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
