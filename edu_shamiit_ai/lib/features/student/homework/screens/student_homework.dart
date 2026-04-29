import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  List<HomeworkAssignment> _homework = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHomework();
  }

  Future<void> _loadHomework() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final statusMap = {
        'Pending': 'pending',
        'Submitted': 'submitted',
        'Graded': 'graded',
      };
      
      final status = statusMap[_tabs[_selectedTab]];
      final homework = await _apiService.getHomeworkAssignments(status: status);
      
      setState(() {
        _homework = homework;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<HomeworkAssignment> get _filteredHomework {
    final currentStatus = _tabs[_selectedTab].toLowerCase();
    return _homework.where((hw) => hw.status.toLowerCase() == currentStatus).toList();
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
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      margin: EdgeInsets.only(right: index < _tabs.length - 1 ? 6 : 0),
                      decoration: BoxDecoration(
                        color: isSelected 
                          ? (isDark ? const Color(0xFFBE185D).withOpacity(0.15) : const Color(0xFFFDF2F8)) 
                          : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _tabs[index].tr(ref),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected 
                            ? (isDark ? const Color(0xFFF472B6) : const Color(0xFFBE185D)) 
                            : (isDark ? StudentColors.darkText3 : StudentColors.text3),
                        ),
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
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredHomework.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('📝', style: TextStyle(fontSize: 48)),
                              const SizedBox(height: 12),
                              Text(
                                'No ${_tabs[_selectedTab].tr(ref).toLowerCase()} ${'Homework'.tr(ref).toLowerCase()}',
                                style: TextStyle(color: isDark ? StudentColors.darkText3 : StudentColors.text3, fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: Responsive.contentPadding(context),
                          itemCount: _filteredHomework.length,
                          itemBuilder: (context, index) {
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

    return Container(
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
    );
  }


  void _showSubmitModal(BuildContext context, HomeworkAssignment hw) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
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
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.03) : const Color(0xFFF8FAFC),
                ),
                child: Column(
                  children: [
                    Text('📁', style: TextStyle(fontSize: 36)),
                    SizedBox(height: 8),
                    Text(
                      'Tap to upload file',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                    ),
                    SizedBox(height: 4),
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
                      submissionText: null, // Would get from text field
                    );
                    if (mounted) {
                      navigator.pop();
                      if (success) {
                        _showSuccessModal(this.context);
                        _loadHomework(); // Refresh the list
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
    );
  }

  void _showSuccessModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
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
    );
  }
}
