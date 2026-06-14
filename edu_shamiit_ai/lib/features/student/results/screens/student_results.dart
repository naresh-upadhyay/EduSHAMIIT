import 'package:edu_shamiit_ai/core/utils/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/services/student_api_service.dart';
import 'package:edu_shamiit_ai/core/models/student_models.dart';
import 'package:edu_shamiit_ai/shared/widgets/azure_grid.dart';

class StudentResults extends ConsumerStatefulWidget {
  const StudentResults({super.key});

  @override
  ConsumerState<StudentResults> createState() => _StudentResultsState();
}

class _StudentResultsState extends ConsumerState<StudentResults> {
  final StudentApiService _apiService = StudentApiService();
  
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Mid-Term', 'End-Term', 'Class Test'];

  List<ExamResult> _examResults = [];
  bool _isLoading = true;
  String? _error;
  bool _isStatsCollapsed = false;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await _apiService.getExamResults();
      setState(() {
        _examResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  // Calculate overall statistics from exam results
  Map<String, dynamic> _calculateOverallStats() {
    if (_examResults.isEmpty) {
      return {
        "avg_score": 0.0,
        "grade": "N/A",
        "class_rank": "-",
        "total_marks": "0/0",
        "improvement": "0%"
      };
    }

    double totalScore = 0;
    double maxScore = 0;

    for (var result in _examResults) {
      totalScore += result.marksObtained;
      maxScore += result.maxMarks;
    }

    double avgPercentage = maxScore > 0 ? (totalScore / maxScore) * 100 : 0;
    String grade = _getGradeFromPercentage(avgPercentage);

    return {
      "avg_score": avgPercentage.toStringAsFixed(1),
      "grade": grade,
      "class_rank": _examResults.isNotEmpty ? "${_examResults.length + 1}th" : "-",
      "total_marks": "${totalScore.toInt()}/${maxScore.toInt()}",
      "improvement": "+0%"
    };
  }

  String _getGradeFromPercentage(double percentage) {
    if (percentage >= 90) return "A+";
    if (percentage >= 80) return "A";
    if (percentage >= 70) return "B";
    if (percentage >= 60) return "C";
    if (percentage >= 50) return "D";
    return "F";
  }

  // Get subject-wise results (aggregated by subject)
  List<Map<String, dynamic>> _getSubjectWiseResults() {
    Map<String, Map<String, dynamic>> subjectMap = {};

    for (var result in _examResults) {
      // Filter by exam title if category is selected (using examTitle instead of examType)
      if (_selectedCategory != 'All' && !result.examTitle.toLowerCase().contains(_selectedCategory.toLowerCase())) {
        continue;
      }

      if (!subjectMap.containsKey(result.subject)) {
        subjectMap[result.subject] = {
          "name": result.subject,
          "icon": _getSubjectIcon(result.subject),
          "score": 0.0,
          "max": 0,
          "grade": "N/A",
          "color": _getSubjectColor(result.subject),
          "count": 0
        };
      }

      subjectMap[result.subject]!['score'] += result.marksObtained;
      subjectMap[result.subject]!['max'] += result.maxMarks;
      subjectMap[result.subject]!['count'] += 1;
    }

    return subjectMap.values.map((subject) {
      double avgScore = subject['max'] > 0 ? subject['score'] / subject['count'] : 0;
      subject['score'] = avgScore;
      subject['grade'] = _getGradeFromPercentage((avgScore / subject['max']) * 100);
      return subject;
    }).toList();
  }

  String _getSubjectIcon(String subject) {
    const icons = {
      'Mathematics': '📐',
      'Physics': '⚛️',
      'Chemistry': '⚗️',
      'English': '📖',
      'Computer Science': '💻',
      'History': '📜',
      'Biology': '🧬',
      'Geography': '🌍',
    };
    return icons[subject] ?? '📚';
  }

  Color _getSubjectColor(String subject) {
    const colors = {
      'Mathematics': Color(0xFF4F46E5),
      'Physics': Color(0xFF3B82F6),
      'Chemistry': Color(0xFF10B981),
      'English': Color(0xFFEF4444),
      'Computer Science': Color(0xFF10B981),
      'History': Color(0xFF8B5CF6),
      'Biology': Color(0xFF06B6D4),
      'Geography': Color(0xFF84CC16),
    };
    return colors[subject] ?? const Color(0xFF6B7280);
  }

  Color _getGradeColor(String grade) {
    if (grade == 'A+') return const Color(0xFF059669);
    if (grade == 'A') return const Color(0xFF10B981);
    if (grade == 'B') return const Color(0xFF3B82F6);
    if (grade == 'C') return const Color(0xFFF59E0B);
    if (grade == 'D') return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Color _getGradeBg(String grade) {
    if (grade == 'A+') return const Color(0xFFECFDF5);
    if (grade == 'A') return const Color(0xFFECFDF5);
    if (grade == 'B') return const Color(0xFFEFF6FF);
    if (grade == 'C') return const Color(0xFFFFF7ED);
    if (grade == 'D') return const Color(0xFFFFF7ED);
    return const Color(0xFFFEF2F2);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading results: $_error', style: TextStyle(color: isDark ? StudentColors.darkText2 : StudentColors.text2)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadResults,
                child: Text('Retry'.tr(ref)),
              ),
            ],
          ),
        ),
      );
    }

    if (_examResults.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.insert_chart_outlined, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No exam results available',
                style: TextStyle(color: StudentColors.text3, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    final overall = _calculateOverallStats();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(16, Responsive.headerTopPadding(context) + (Responsive.isWide(context) ? 0 : 8), 16, Responsive.isWide(context) ? 8 : 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => safeGoBack(context, '/student/dashboard'),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Academic Results',
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
                  tooltip: 'Refresh',
                  onPressed: _loadResults,
                ),
                GestureDetector(
                  onTap: () => _showYearPicker(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Year 2026',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 10),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.expand_more, color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Collapsible Toggle Button for Performance Stats
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => _isStatsCollapsed = !_isStatsCollapsed),
                  icon: Icon(_isStatsCollapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up, size: 16),
                  label: Text(_isStatsCollapsed ? 'Show Stats Details' : 'Hide Stats Details', style: const TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF4F46E5),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ],
            ),
          ),

          // Overall Performance Quick Cards Row
          if (!_isStatsCollapsed)
            Container(
              constraints: const BoxConstraints(maxWidth: 800),
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF2E2E38) : Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text('Overall Score', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('${overall['avg_score']}%', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF4F46E5))),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('Grade', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('${overall['grade']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.green)),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('Class Rank', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('${overall['class_rank']}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('Total Marks', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('${overall['total_marks']}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                    ],
                  ),
                ],
              ),
            ),

          // Exam Results Table Grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: AzureGrid<ExamResult>(
                title: 'Exam Results Ledger',
                items: _examResults,
                onRefresh: _loadResults,
                enableSelection: true,
                extraCommandActions: [
                  TextButton.icon(
                    onPressed: () => _showDownloadDialog(context),
                    icon: const Icon(Icons.picture_as_pdf, size: 14, color: Color(0xFF4F46E5)),
                    label: const Text('Consolidated Report', style: TextStyle(fontSize: 11, color: Color(0xFF4F46E5))),
                  ),
                ],
                bulkActions: (context, selected) {
                  return [
                    ElevatedButton.icon(
                      onPressed: () => _showDownloadDialog(context),
                      icon: const Icon(Icons.download, size: 14, color: Colors.white),
                      label: const Text('Download Selected Report', style: TextStyle(fontSize: 11, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                    )
                  ];
                },
                searchMatcher: (item) =>
                    '${item.examTitle} ${item.subject} ${item.grade} ${item.remarks ?? ""}',
                filters: [
                  AzureGridFilter<ExamResult>(
                    label: 'Exam Type',
                    options: const ['Mid-Term', 'End-Term', 'Class Test'],
                    filterFn: (item, option) =>
                        item.examTitle.toLowerCase().contains(option.toLowerCase()),
                  ),
                  AzureGridFilter<ExamResult>(
                    label: 'Subject',
                    options: _examResults.map((e) => e.subject).toSet().toList(),
                    filterFn: (item, option) => item.subject == option,
                  ),
                ],
                columns: [
                  AzureGridColumn<ExamResult>(
                    label: 'Exam Title',
                    width: 220,
                    compare: (a, b) => a.examTitle.compareTo(b.examTitle),
                    cellBuilder: (item) => Text(item.examTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  AzureGridColumn<ExamResult>(
                    label: 'Subject',
                    width: 140,
                    compare: (a, b) => a.subject.compareTo(b.subject),
                    cellBuilder: (item) => Row(
                      children: [
                        Text(_getSubjectIcon(item.subject)),
                        const SizedBox(width: 6),
                        Text(item.subject),
                      ],
                    ),
                  ),
                  AzureGridColumn<ExamResult>(
                    label: 'Exam Date',
                    width: 120,
                    compare: (a, b) => a.examDate.compareTo(b.examDate),
                    cellBuilder: (item) => Text(
                      '${item.examDate.day}/${item.examDate.month}/${item.examDate.year}',
                    ),
                  ),
                  AzureGridColumn<ExamResult>(
                    label: 'Marks',
                    width: 100,
                    compare: (a, b) => a.marksObtained.compareTo(b.marksObtained),
                    cellBuilder: (item) => Text('${item.marksObtained.toInt()} / ${item.maxMarks.toInt()}'),
                  ),
                  AzureGridColumn<ExamResult>(
                    label: 'Percentage',
                    width: 110,
                    compare: (a, b) =>
                        (a.marksObtained / a.maxMarks).compareTo(b.marksObtained / b.maxMarks),
                    cellBuilder: (item) {
                      final pct = item.maxMarks > 0 ? (item.marksObtained / item.maxMarks) * 100 : 0.0;
                      return Text('${pct.toStringAsFixed(1)}%');
                    },
                  ),
                  AzureGridColumn<ExamResult>(
                    label: 'Grade',
                    width: 90,
                    compare: (a, b) => a.grade.compareTo(b.grade),
                    cellBuilder: (item) {
                      final gradeColor = _getGradeColor(item.grade);
                      final gradeBg = _getGradeBg(item.grade);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: gradeBg,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: gradeColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          item.grade,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: gradeColor,
                          ),
                        ),
                      );
                    },
                  ),
                  AzureGridColumn<ExamResult>(
                    label: 'Remarks',
                    width: 200,
                    compare: (a, b) => (a.remarks ?? '').compareTo(b.remarks ?? ''),
                    cellBuilder: (item) => Text(
                      item.remarks ?? '-',
                      style: TextStyle(
                        color: item.remarks != null ? Colors.black87 : Colors.grey,
                        fontStyle: item.remarks != null ? FontStyle.normal : FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                mobileCardBuilder: (context, item) {
                  final gradeColor = _getGradeColor(item.grade);
                  return Card(
                    color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: isDark ? const Color(0xFF2E2E38) : Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(item.examTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getGradeBg(item.grade),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(item.grade, style: TextStyle(color: gradeColor, fontWeight: FontWeight.bold, fontSize: 9)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('${_getSubjectIcon(item.subject)} ${item.subject}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Marks: ${item.marksObtained.toInt()} / ${item.maxMarks.toInt()}', style: const TextStyle(fontSize: 11)),
                              Text('Date: ${item.examDate.day}/${item.examDate.month}/${item.examDate.year}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                          if (item.remarks != null) ...[
                            const SizedBox(height: 6),
                            Text('Remarks: ${item.remarks}', style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey)),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getSubjectBg(String subject) {
    final colors = {
      'Mathematics': const Color(0xFFEEF2FF),
      'Physics': const Color(0xFFEFF6FF),
      'Chemistry': const Color(0xFFECFDF5),
      'English': const Color(0xFFFFF0F0),
      'Computer Sci.': const Color(0xFFEFF6FF),
      'History': const Color(0xFFF0FDF4),
    };
    return colors[subject] ?? const Color(0xFFF8FAFC);
  }

  Widget _buildStatItem(String value, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: AppFonts.heading,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: isDark ? StudentColors.darkText3 : StudentColors.text3, fontSize: 9),
        ),
      ],
    );
  }


  void _showYearPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
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
                    'Select Academic Year',
                    style: TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white : StudentColors.text,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildYearOption('2026', true),
                  _buildYearOption('2025', false),
                  _buildYearOption('2024', false),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'.tr(ref)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildYearOption(String year, bool isCurrent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ElevatedButton(
        onPressed: () {
          Navigator.pop(context);
          // Handle year change
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isCurrent 
            ? (Theme.of(context).brightness == Brightness.dark ? StudentColors.primary.withValues(alpha: 0.2) : const Color(0xFFEEF2FF)) 
            : (Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC)),
          foregroundColor: isCurrent ? StudentColors.primary : (Theme.of(context).brightness == Brightness.dark ? StudentColors.darkText : StudentColors.text),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: isCurrent 
              ? const BorderSide(color: Color(0xFF4F46E5), width: 2) 
              : BorderSide(color: Theme.of(context).brightness == Brightness.dark ? StudentColors.darkBorder : Colors.grey.shade200),
          ),
          minimumSize: const Size(double.infinity, 48),
        ),
        child: Text(
          'Year $year ${isCurrent ? '(Current)' : ''}',
          style: TextStyle(
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showDownloadDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('📄', style: TextStyle(fontSize: 50)),
                  const SizedBox(height: 8),
                  Text(
                    'Report Card Ready!',
                    style: TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white : StudentColors.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your consolidated academic ledger for 2026 has been generated',
                    style: TextStyle(color: StudentColors.text3, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF065F46).withValues(alpha: 0.2) : const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                      border: isDark ? Border.all(color: const Color(0xFF059669).withValues(alpha: 0.4)) : null,
                    ),
                    child: const Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('📥 ReportCard_2026_Arjun.pdf', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Color(0xFF059669))),
                            Text('Size: 312 KB', style: TextStyle(color: StudentColors.text3, fontSize: 10)),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text('Format: PDF', style: TextStyle(color: StudentColors.text3, fontSize: 10)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: StudentColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: Text('✅ Download Successfully'.tr(ref)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
