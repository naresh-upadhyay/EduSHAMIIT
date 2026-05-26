import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/shared/widgets/responsive_content.dart';
import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/services/student_api_service.dart';
import 'package:edu_shamiit_ai/core/models/student_models.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';

class StudentHomework extends ConsumerStatefulWidget {
  const StudentHomework({super.key});

  @override
  ConsumerState<StudentHomework> createState() => _StudentHomeworkState();
}

class _StudentHomeworkState extends ConsumerState<StudentHomework> {
  final StudentApiService _apiService = StudentApiService();
  int _selectedTab = 0;
  final List<String> _tabs = ['Pending', 'Submitted', 'Graded'];
  // Load all statuses at once and filter client-side
  List<HomeworkAssignment> _allHomework = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHomework();
  }

  Future<void> _loadHomework() async {
    setState(() { _isLoading = true; _error = null; });

    try {
      // Load all statuses in parallel for instant tab switching
      final results = await Future.wait([
        _apiService.getHomeworkAssignments(status: 'pending'),
        _apiService.getHomeworkAssignments(status: 'submitted'),
        _apiService.getHomeworkAssignments(status: 'graded'),
        _apiService.getHomeworkAssignments(status: 'late'),
      ]);
      
      if (!mounted) return;
      
      setState(() {
        _allHomework = [...results[0], ...results[1], ...results[2], ...results[3]];
        // Deduplicate by id
        final seen = <String>{};
        _allHomework = _allHomework.where((h) => seen.add(h.id)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  List<HomeworkAssignment> get _filteredHomework {
    switch (_selectedTab) {
      case 0: // Pending
        return _allHomework.where((hw) {
          final s = hw.status.toLowerCase();
          return s == 'pending' || s == 'late';
        }).toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate)); // soonest first
      case 1: // Submitted
        return _allHomework.where((hw) => hw.status.toLowerCase() == 'submitted').toList()
          ..sort((a, b) => (b.submittedAt ?? b.dueDate).compareTo(a.submittedAt ?? a.dueDate));
      case 2: // Graded
        return _allHomework.where((hw) => hw.status.toLowerCase() == 'graded').toList()
          ..sort((a, b) => b.dueDate.compareTo(a.dueDate));
      default:
        return [];
    }
  }

  // Helper method to get status display text
  String _getStatusText(HomeworkAssignment hw) {
    final now = DateTime.now();
    final dueDate = hw.dueDate;
    
    if (hw.status == 'graded') {
      return 'Graded'.tr(ref);
    } else if (hw.status == 'submitted') {
      return 'Submitted'.tr(ref);
    } else if (hw.status == 'late') {
      return 'Late'.tr(ref);
    } else {
      // Pending - show due date
      final difference = dueDate.difference(now).inDays;
      if (difference == 0) {
        return 'Due TODAY'.tr(ref);
      } else if (difference == 1) {
        return 'Due Tomorrow'.tr(ref);
      } else if (difference < 0) {
        return 'Overdue'.tr(ref);
      } else {
        return '${'Due'.tr(ref)}: ${dueDate.day}/${dueDate.month}';
      }
    }
  }

  // Helper method to get due date color
  Color _getDueColor(HomeworkAssignment hw) {
    if (hw.status == 'graded') return StudentColors.success;
    if (hw.status == 'submitted') return StudentColors.primary;
    if (hw.status == 'late') return StudentColors.error;
    
    final now = DateTime.now();
    final difference = hw.dueDate.difference(now).inDays;
    if (difference == 0) return StudentColors.error;
    if (difference <= 2) return StudentColors.warning;
    return StudentColors.success;
  }

  // Helper method to get subject icon
  String _getSubjectIcon(String subject) {
    switch (subject.toLowerCase()) {
      case 'mathematics':
        return '📐';
      case 'physics':
        return '⚡';
      case 'chemistry':
        return '⚗️';
      case 'biology':
        return '🧬';
      case 'english':
        return '📖';
      case 'history':
        return '📜';
      case 'geography':
        return '🌍';
      case 'computer science':
        return '💻';
      default:
        return '📚';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(16, Responsive.headerTopPadding(context), 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFBE185D), Color(0xFFDB2777)],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => safeGoBack(context, '/student/dashboard'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Homework'.tr(ref),
                    style: const TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🤖', style: TextStyle(fontSize: 10)),
                      const SizedBox(width: 4),
                      Text(
                        'AI Help'.tr(ref),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: List.generate(_tabs.length, (index) {
                final isSelected = index == _selectedTab;
                final count = index == 0
                  ? _allHomework.where((h) { final s = h.status.toLowerCase(); return s == 'pending' || s == 'late'; }).length
                  : index == 1
                    ? _allHomework.where((h) => h.status.toLowerCase() == 'submitted').length
                    : _allHomework.where((h) => h.status.toLowerCase() == 'graded').length;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() { _selectedTab = index; });
                      // No extra API call - already have all data
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      margin: EdgeInsets.only(right: index < _tabs.length - 1 ? 6 : 0),
                      decoration: BoxDecoration(
                        color: isSelected
                          ? (isDark ? const Color(0xFFBE185D).withValues(alpha: 0.15) : const Color(0xFFFDF2F8))
                          : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                          ? Border.all(color: isDark ? const Color(0xFFF472B6).withValues(alpha: 0.3) : const Color(0xFFBE185D).withValues(alpha: 0.2))
                          : null,
                      ),
                      child: Column(
                        children: [
                          Text(
                            _tabs[index],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                ? (isDark ? const Color(0xFFF472B6) : const Color(0xFFBE185D))
                                : (isDark ? StudentColors.darkText3 : StudentColors.text3),
                            ),
                          ),
                          if (count > 0) ...[
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFBE185D) : (isDark ? StudentColors.darkText3 : StudentColors.text3),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$count',
                                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          // Content
          Expanded(
            child: ResponsiveContent(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFBE185D)))
                  : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('⚠️', style: TextStyle(fontSize: 40)),
                            const SizedBox(height: 12),
                            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12), textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _loadHomework,
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBE185D), foregroundColor: Colors.white),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                  : _filteredHomework.isEmpty
                      ? SingleChildScrollView(
                          padding: Responsive.contentPadding(context),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 48),
                              Text(
                                _selectedTab == 0 ? '🎉' : _selectedTab == 1 ? '📤' : '📊',
                                style: const TextStyle(fontSize: 48),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _selectedTab == 0
                                    ? 'No pending homework!'
                                    : _selectedTab == 1
                                        ? 'No submitted homework yet'
                                        : 'No graded homework yet',
                                style: TextStyle(
                                  color: isDark ? StudentColors.darkText3 : StudentColors.text3,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 24),
                              _buildAiHomeworkHelperCard(),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: Responsive.contentPadding(context),
                          itemCount: _filteredHomework.length + 1,
                          itemBuilder: (context, index) {
                            if (index == _filteredHomework.length) {
                              return _buildAiHomeworkHelperCard();
                            }
                            return _buildHomeworkCard(_filteredHomework[index]);
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeworkCard(HomeworkAssignment hw) {
    final dueText = _getStatusText(hw);
    final dueColor = _getDueColor(hw);
    final subjectIcon = _getSubjectIcon(hw.subject);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _showDetailSheet(context, hw),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
          border: Border(
            left: BorderSide(
              color: dueColor,
              width: 4,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(subjectIcon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: dueColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    hw.subject,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: dueColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (hw.maxMarks != null)
                  Text(
                    '${hw.maxMarks} marks',
                    style: TextStyle(color: isDark ? StudentColors.darkText3 : StudentColors.text3, fontSize: 10),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              hw.title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                fontFamily: AppFonts.heading,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              hw.description,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? StudentColors.darkText2 : StudentColors.text3,
                height: 1.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dueText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: dueColor,
                  ),
                ),
                if (hw.status == 'pending' || hw.status == 'late')
                  ElevatedButton(
                    onPressed: () => _showSubmitModal(context, hw),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: StudentColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      '📤 Submit',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  )
                else if (hw.status == 'graded' && hw.marksObtained != null)
                  Text(
                    'Score: ${hw.marksObtained}/${hw.maxMarks} (${hw.grade ?? ''})',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: StudentColors.success,
                    ),
                  )
                else
                  const Text(
                    'Submitted ✓',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: StudentColors.primary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiHomeworkHelperCard() {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFBE185D), Color(0xFFDB2777)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFBE185D).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🤖', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                'AI Homework Helper'.tr(ref),
                style: const TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Active'.tr(ref),
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Stuck on a tricky assignment? Ask Shami, your personal AI tutor, for step-by-step guidance, explanations, and practice hints!'.tr(ref),
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () => context.push('/student/ai-chat'),
            icon: const Icon(Icons.chat_bubble_outline, size: 14, color: Color(0xFFBE185D)),
            label: Text(
              'Ask AI Tutor'.tr(ref),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFFBE185D),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFBE185D),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailSheet(BuildContext context, HomeworkAssignment hw) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dueColor = _getDueColor(hw);
    final dueText = _getStatusText(hw);
    final subjectIcon = _getSubjectIcon(hw.subject);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Subject tag and due timer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: dueColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(subjectIcon, style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(
                          hw.subject,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: dueColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    dueText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: dueColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                hw.title,
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              if (hw.maxMarks != null)
                Text(
                  '${'Marks'.tr(ref)}: ${hw.maxMarks} ${'Max'.tr(ref)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? StudentColors.darkText3 : StudentColors.text3,
                  ),
                ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              // Structured Instructions Header
              Text(
                'Instructions'.tr(ref),
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hw.description,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? StudentColors.darkText2 : StudentColors.text2,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 16),
              // References / Rubrics section
              Text(
                'Reference Materials & Rubrics'.tr(ref),
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? StudentColors.darkBorder : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Text('📎', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Assignment_Guidelines.pdf'.tr(ref),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Rubrics & evaluation criteria included (1.4 MB)'.tr(ref),
                            style: TextStyle(
                              fontSize: 9,
                              color: isDark ? StudentColors.darkText3 : StudentColors.text3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.download, size: 16, color: isDark ? Colors.grey : Colors.grey.shade600),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Submission Area / Status Detail
              if (hw.status == 'pending' || hw.status == 'late') ...[
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  'Your Submission'.tr(ref),
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showSubmitModal(context, hw);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: StudentColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Upload & Submit Now'.tr(ref),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ),
              ] else ...[
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  'Submission Details'.tr(ref),
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${'Status'.tr(ref)}: ${hw.status.toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.green,
                            ),
                          ),
                          if (hw.submittedAt != null)
                            Text(
                              '${'Submitted'.tr(ref)}: ${hw.submittedAt!.day}/${hw.submittedAt!.month} at ${hw.submittedAt!.hour}:${hw.submittedAt!.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? StudentColors.darkText3 : StudentColors.text3,
                              ),
                            ),
                        ],
                      ),
                      if (hw.status == 'graded' && hw.marksObtained != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${'Score'.tr(ref)}: ${hw.marksObtained}/${hw.maxMarks} (${hw.grade ?? ''})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.green,
                          ),
                        ),
                        if (hw.teacherRemarks != null && hw.teacherRemarks!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Teacher Feedback:'.tr(ref),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isDark ? StudentColors.darkText2 : StudentColors.text2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hw.teacherRemarks!,
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: isDark ? StudentColors.darkText3 : StudentColors.text3,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'.tr(ref)),
              ),
            ],
          ),
        ),
      ),
    );
  }


  void _showSubmitModal(BuildContext context, HomeworkAssignment hw) {
    final notesController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '📤 Submit Homework',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : StudentColors.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  hw.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).brightness == Brightness.dark ? StudentColors.darkText : Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? StudentColors.darkBorder : const Color(0xFFE2E8F0), style: BorderStyle.solid),
                      borderRadius: BorderRadius.circular(16),
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC),
                    ),
                    child: Column(
                      children: [
                        const Text('📁', style: TextStyle(fontSize: 36)),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to upload file',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'PDF, DOC, JPG up to 10MB',
                          style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? StudentColors.darkText3 : StudentColors.text3, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Add notes for your teacher (optional)...',
                    hintStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? StudentColors.darkText3 : StudentColors.text3, fontSize: 13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? StudentColors.darkBorder : Colors.grey),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        // Submit homework to API
                        final success = await _apiService.submitHomework(
                          homeworkId: hw.id,
                          submissionText: notesController.text.isNotEmpty ? notesController.text : null,
                        );
                        if (mounted) {
                          navigator.pop();
                          if (success) {
                            // Move homework to submitted tab
                            setState(() {
                              final idx = _allHomework.indexWhere((h) => h.id == hw.id);
                              if (idx != -1) {
                                final updated = HomeworkAssignment(
                                  id: hw.id,
                                  title: hw.title,
                                  description: hw.description,
                                  subject: hw.subject,
                                  assignedDate: hw.assignedDate,
                                  dueDate: hw.dueDate,
                                  status: 'submitted',
                                  maxMarks: hw.maxMarks,
                                  submissionUrl: hw.submissionUrl,
                                  submittedAt: DateTime.now(),
                                );
                                _allHomework[idx] = updated;
                              }
                            });
                            _showSuccessModal(this.context);
                            // Also reload from server to sync with teacher
                            _loadHomework();
                          } else {
                            messenger.showSnackBar(
                              SnackBar(content: Text('Failed to submit homework'.tr(ref))),
                            );
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          navigator.pop();
                          messenger.showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: StudentColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      '📤 Submit Assignment'.tr(ref),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'.tr(ref)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSuccessModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('✅', style: TextStyle(fontSize: 60)),
                const SizedBox(height: 8),
                Text(
                  'Submitted Successfully!'.tr(ref),
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF059669),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your homework has been submitted. Your teacher will review it shortly.'.tr(ref),
                  style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? StudentColors.darkText3 : const Color(0xFF64748B)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: StudentColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text('Done'.tr(ref)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
