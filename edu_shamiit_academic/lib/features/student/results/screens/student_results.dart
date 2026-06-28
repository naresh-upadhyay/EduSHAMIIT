
import 'package:edu_shamiit_core/utils/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:edu_shamiit_academic/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_core/utils/responsive.dart';
import 'package:edu_shamiit_core/constants/student_colors.dart';
import 'package:edu_shamiit_core/constants/app_fonts.dart';
import 'package:edu_shamiit_academic/core/services/student_api_service.dart';
import 'package:edu_shamiit_core/models/student_models.dart';
import 'package:edu_shamiit_academic/shared/widgets/azure_grid.dart';
import 'package:edu_shamiit_academic/core/utils/download_helper_stub.dart'
    if (dart.library.js) 'package:edu_shamiit_academic/core/utils/download_helper_web.dart'
    if (dart.library.io) 'package:edu_shamiit_academic/core/utils/download_helper_mobile.dart';

class StudentResults extends ConsumerStatefulWidget {
  const StudentResults({super.key});

  @override
  ConsumerState<StudentResults> createState() => _StudentResultsState();
}

class _StudentResultsState extends ConsumerState<StudentResults> with SingleTickerProviderStateMixin {
  final StudentApiService _apiService = StudentApiService();
  late TabController _tabController;
  
  List<ExamResult> _examResults = [];
  List<HomeworkAssignment> _homeworkAssignments = [];
  bool _isLoading = true;
  String? _error;
  // Premium Palette
  static const _darkBg = Color(0xFF0A0C1B);
  static const _cardBg = Color(0xFF12152A);
  static const _cardBorder = Color(0xFF1A1E35);
  static const _textMuted = Color(0xFF6E7AAB);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadResults();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadResults() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final futures = await Future.wait([
        _apiService.getExamResults(),
        _apiService.getHomeworkAssignments(),
      ]);

      if (mounted) {
        setState(() {
          _examResults = futures[0] as List<ExamResult>;
          
          // Filter homework assignments that are graded (status == 'graded' or has marks_obtained)
          final rawHomeworks = futures[1] as List<HomeworkAssignment>;
          _homeworkAssignments = rawHomeworks
              .where((hw) => hw.status == 'graded' || hw.marksObtained != null)
              .toList();
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  // Statistics Calculation
  Map<String, dynamic> _calculateCombinedStats() {
    double totalExamScore = 0;
    double maxExamScore = 0;
    for (var r in _examResults) {
      totalExamScore += r.marksObtained;
      maxExamScore += r.maxMarks;
    }
    double examAvg = maxExamScore > 0 ? (totalExamScore / maxExamScore) * 100 : 0.0;

    double totalHwScore = 0;
    double maxHwScore = 0;
    for (var hw in _homeworkAssignments) {
      totalHwScore += hw.marksObtained ?? 0;
      maxHwScore += (hw.maxMarks ?? 100).toDouble();
    }
    double hwAvg = maxHwScore > 0 ? (totalHwScore / maxHwScore) * 100 : 0.0;

    double combinedAvg = 0;
    if (maxExamScore > 0 && maxHwScore > 0) {
      // 60% Exam weight, 40% Homework weight
      combinedAvg = (examAvg * 0.6) + (hwAvg * 0.4);
    } else if (maxExamScore > 0) {
      combinedAvg = examAvg;
    } else if (maxHwScore > 0) {
      combinedAvg = hwAvg;
    }

    String grade = _getGradeFromPercentage(combinedAvg);

    return {
      "combined_avg": combinedAvg,
      "exam_avg": examAvg,
      "hw_avg": hwAvg,
      "grade": grade,
      "total_exams": _examResults.length,
      "total_hw": _homeworkAssignments.length,
      "total_assessments": _examResults.length + _homeworkAssignments.length,
      "exam_marks": "${totalExamScore.toInt()}/${maxExamScore.toInt()}",
      "hw_marks": "${totalHwScore.toInt()}/${maxHwScore.toInt()}",
    };
  }

  String _getGradeFromPercentage(double percentage) {
    if (percentage >= 90) return "A+";
    if (percentage >= 80) return "A";
    if (percentage >= 70) return "B+";
    if (percentage >= 60) return "B";
    if (percentage >= 50) return "C";
    if (percentage >= 40) return "D";
    return "F";
  }

  List<Map<String, dynamic>> _getCombinedSubjectWiseResults() {
    Map<String, Map<String, dynamic>> subjectMap = {};

    for (var result in _examResults) {
      final subject = result.subject;
      if (!subjectMap.containsKey(subject)) {
        subjectMap[subject] = {
          "name": subject,
          "icon": _getSubjectIcon(subject),
          "color": _getSubjectColor(subject),
          "exam_score": 0.0,
          "exam_max": 0.0,
          "exam_count": 0,
          "hw_score": 0.0,
          "hw_max": 0.0,
          "hw_count": 0,
        };
      }
      subjectMap[subject]!['exam_score'] += result.marksObtained;
      subjectMap[subject]!['exam_max'] += result.maxMarks;
      subjectMap[subject]!['exam_count'] += 1;
    }

    for (var hw in _homeworkAssignments) {
      final subject = hw.subject;
      if (!subjectMap.containsKey(subject)) {
        subjectMap[subject] = {
          "name": subject,
          "icon": _getSubjectIcon(subject),
          "color": _getSubjectColor(subject),
          "exam_score": 0.0,
          "exam_max": 0.0,
          "exam_count": 0,
          "hw_score": 0.0,
          "hw_max": 0.0,
          "hw_count": 0,
        };
      }
      subjectMap[subject]!['hw_score'] += hw.marksObtained ?? 0;
      subjectMap[subject]!['hw_max'] += (hw.maxMarks ?? 25).toDouble();
      subjectMap[subject]!['hw_count'] += 1;
    }

    return subjectMap.values.map((subj) {
      final double examAvg = subj['exam_max'] > 0 ? (subj['exam_score'] / subj['exam_max']) * 100 : 0.0;
      final double hwAvg = subj['hw_max'] > 0 ? (subj['hw_score'] / subj['hw_max']) * 100 : 0.0;
      
      double combined = 0.0;
      if (subj['exam_max'] > 0 && subj['hw_max'] > 0) {
        combined = (examAvg * 0.6) + (hwAvg * 0.4);
      } else if (subj['exam_max'] > 0) {
        combined = examAvg;
      } else if (subj['hw_max'] > 0) {
        combined = hwAvg;
      }

      subj['exam_avg'] = examAvg;
      subj['hw_avg'] = hwAvg;
      subj['combined_avg'] = combined;
      subj['grade'] = _getGradeFromPercentage(combined);
      return subj;
    }).toList();
  }

  // Combined Activity Log (Latest 5 items)
  List<Map<String, dynamic>> _getRecentActivity() {
    final List<Map<String, dynamic>> activities = [];
    
    for (var r in _examResults) {
      activities.add({
        "type": "Exam",
        "title": r.examTitle,
        "subject": r.subject,
        "date": r.examDate,
        "score": r.marksObtained,
        "max": r.maxMarks,
        "grade": r.grade,
      });
    }

    for (var hw in _homeworkAssignments) {
      activities.add({
        "type": "Homework",
        "title": hw.title,
        "subject": hw.subject,
        "date": hw.submittedAt ?? hw.dueDate,
        "score": hw.marksObtained ?? 0.0,
        "max": (hw.maxMarks ?? 25).toDouble(),
        "grade": hw.grade ?? "N/A",
      });
    }

    activities.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
    return activities.take(5).toList();
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
      'Mathematics': Color(0xFF6366F1),
      'Physics': Color(0xFF3B82F6),
      'Chemistry': Color(0xFF10B981),
      'English': Color(0xFFEF4444),
      'Computer Science': Color(0xFF8B5CF6),
      'History': Color(0xFFEC4899),
      'Biology': Color(0xFF06B6D4),
      'Geography': Color(0xFF84CC16),
    };
    return colors[subject] ?? const Color(0xFF6B7280);
  }

  Color _getGradeColor(String grade) {
    if (grade.startsWith('A')) return const Color(0xFF10B981);
    if (grade.startsWith('B')) return const Color(0xFF3B82F6);
    if (grade.startsWith('C')) return const Color(0xFFF59E0B);
    if (grade.startsWith('D')) return const Color(0xFFEF4444);
    return const Color(0xFF94A3B8);
  }

  Color _getGradeBg(String grade) {
    return _getGradeColor(grade).withValues(alpha: 0.12);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isDark ? const Color(0xFF6366F1) : const Color(0xFF4F46E5);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? _darkBg : const Color(0xFFF8FAFC),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: isDark ? _darkBg : const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading results: $_error', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
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

    final stats = _calculateCombinedStats();

    return Scaffold(
      backgroundColor: isDark ? _darkBg : const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Sleek Header
          Container(
            padding: EdgeInsets.fromLTRB(16, Responsive.headerTopPadding(context) + (Responsive.isWide(context) ? 0 : 8), 16, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF111326), const Color(0xFF080914)]
                    : [const Color(0xFF4F46E5), const Color(0xFF6366F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF1E2240) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => safeGoBack(context, '/student/dashboard'),
                ),
                const SizedBox(width: 8),
                Text(
                  'Academic Center'.tr(ref),
                  style: const TextStyle(
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
                      color: Colors.white.withValues(alpha: 0.15),
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

          // Custom Premium Segmented Tab Selector
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? _cardBg : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? _cardBorder : const Color(0xFFCBD5E1),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: isDark ? _textMuted : const Color(0xFF64748B),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: AppFonts.heading),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, fontFamily: AppFonts.heading),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Exams'),
                Tab(text: 'Homeworks'),
              ],
            ),
          ).animate().fade(duration: 300.ms).slideY(begin: 0.1, end: 0),

          // Tab Bar View content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(stats, isDark),
                _buildExamsTab(isDark),
                _buildHomeworksTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── OVERVIEW TAB ──────────────────────────────────────────
  Widget _buildOverviewTab(Map<String, dynamic> stats, bool isDark) {
    final isWide = Responsive.isWide(context);
    final results = _getCombinedSubjectWiseResults();
    final activities = _getRecentActivity();

    return RefreshIndicator(
      onRefresh: _loadResults,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row of stats cards
            LayoutBuilder(
              builder: (context, constraints) {
                final double width = (constraints.maxWidth - 24) / (isWide ? 4 : 2);
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildStatCard(
                      'Combined Average',
                      '${(stats['combined_avg'] as double).toStringAsFixed(1)}%',
                      'Grade: ${stats['grade']}',
                      [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
                      width,
                    ),
                    _buildStatCard(
                      'Exams Average',
                      '${(stats['exam_avg'] as double).toStringAsFixed(1)}%',
                      stats['exam_marks'],
                      [const Color(0xFF0EA5E9), const Color(0xFF2563EB)],
                      width,
                    ),
                    _buildStatCard(
                      'Homework Average',
                      '${(stats['hw_avg'] as double).toStringAsFixed(1)}%',
                      stats['hw_marks'],
                      [const Color(0xFF10B981), const Color(0xFF059669)],
                      width,
                    ),
                    _buildStatCard(
                      'Total Assessments',
                      '${stats['total_assessments']}',
                      '${stats['total_exams']} Exams + ${stats['total_hw']} HW',
                      [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)],
                      width,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // Subject Breakdown Grid Header
            Text(
              'Subject-wise Analytics'.tr(ref),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: AppFonts.heading,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ).animate().fade(delay: 100.ms),
            const SizedBox(height: 10),

            // Subject breakdown cards
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: results.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isWide ? 3 : 1,
                mainAxisExtent: 135,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemBuilder: (context, index) {
                final item = results[index];
                return _buildSubjectProgressCard(item, isDark);
              },
            ).animate().fade(delay: 200.ms).slideY(begin: 0.05, end: 0),
            
            const SizedBox(height: 24),

            // Recent activity log
            if (activities.isNotEmpty) ...[
              Text(
                'Recent Evaluations'.tr(ref),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: AppFonts.heading,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ).animate().fade(delay: 250.ms),
              const SizedBox(height: 10),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activities.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final act = activities[index];
                  return _buildActivityTile(act, isDark);
                },
              ).animate().fade(delay: 300.ms).slideY(begin: 0.05, end: 0),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, String sub, List<Color> colors, double width) {
    return Container(
      width: width,
      height: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fade(duration: 400.ms).scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1));
  }

  Widget _buildSubjectProgressCard(Map<String, dynamic> item, bool isDark) {
    final color = item['color'] as Color;
    final double examAvg = item['exam_avg'];
    final double hwAvg = item['hw_avg'];
    final double combinedAvg = item['combined_avg'];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? _cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? _cardBorder : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.grey.shade100,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(item['icon'], style: const TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Combined Average: ${combinedAvg.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? _textMuted : const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _getGradeBg(item['grade']),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item['grade'],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _getGradeColor(item['grade']),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Dual linear progress bars (Exams & Homework)
          Column(
            children: [
              // Exams Row
              Row(
                children: [
                  const SizedBox(
                    width: 50,
                    child: Text('Exams', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: examAvg / 100,
                        minHeight: 5,
                        backgroundColor: isDark ? const Color(0xFF1E2240) : const Color(0xFFF1F5F9),
                        color: const Color(0xFF0EA5E9),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 32,
                    child: Text(
                      '${examAvg.toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : Colors.black54),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Homeworks Row
              Row(
                children: [
                  const SizedBox(
                    width: 50,
                    child: Text('Homework', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: hwAvg / 100,
                        minHeight: 5,
                        backgroundColor: isDark ? const Color(0xFF1E2240) : const Color(0xFFF1F5F9),
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 32,
                    child: Text(
                      '${hwAvg.toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : Colors.black54),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTile(Map<String, dynamic> act, bool isDark) {
    final type = act['type'] as String;
    final isExam = type == 'Exam';
    final date = act['date'] as DateTime;
    final score = act['score'] as double;
    final max = act['max'] as double;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? _cardBg : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? _cardBorder : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isExam ? const Color(0xFF0EA5E9).withValues(alpha: 0.12) : const Color(0xFF10B981).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(isExam ? '📊' : '📝', style: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  act['title'],
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${act['subject']} • ${date.day}/${date.month}/${date.year}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${score.toInt()} / ${max.toInt()}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: _getGradeBg(act['grade']),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  act['grade'],
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: _getGradeColor(act['grade']),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  // ── EXAMS TAB ─────────────────────────────────────────────
  Widget _buildExamsTab(bool isDark) {
    if (_examResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.insert_chart_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('No exam results available', style: TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      child: AzureGrid<ExamResult>(
        title: 'Exams Score Ledger'.tr(ref),
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
              onPressed: () => _showDownloadDialog(context, selected: selected),
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
            options: _examResults.map((e) => e.examType ?? 'General').toSet().toList(),
            filterFn: (item, option) =>
                (item.examType ?? 'General') == option,
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
            width: 200,
            compare: (a, b) => a.examTitle.compareTo(b.examTitle),
            cellBuilder: (item) => Text(item.examTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          AzureGridColumn<ExamResult>(
            label: 'Type',
            width: 110,
            compare: (a, b) => (a.examType ?? '').compareTo(b.examType ?? ''),
            cellBuilder: (item) {
              final type = item.examType ?? 'General';
              final Color typeColor;
              if (type.toLowerCase().contains('mid')) {
                typeColor = const Color(0xFF8B5CF6);
              } else if (type.toLowerCase().contains('end') || type.toLowerCase().contains('final')) {
                typeColor = const Color(0xFFEF4444);
              } else if (type.toLowerCase().contains('class') || type.toLowerCase().contains('test')) {
                typeColor = const Color(0xFF0EA5E9);
              } else {
                typeColor = const Color(0xFF10B981);
              }
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  type,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: typeColor),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
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
                  border: Border.all(color: gradeColor.withValues(alpha: 0.3)),
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
            width: 160,
            compare: (a, b) => (a.remarks ?? '').compareTo(b.remarks ?? ''),
            cellBuilder: (item) {
              final isPass = item.isPass;
              final remarks = item.remarks ?? (isPass == true ? 'Pass' : isPass == false ? 'Fail' : '-');
              final passColor = isPass == true ? const Color(0xFF10B981) : isPass == false ? const Color(0xFFEF4444) : Colors.grey;
              return Text(
                remarks,
                style: TextStyle(
                  color: isPass != null ? passColor : Colors.grey,
                  fontStyle: FontStyle.normal,
                  fontWeight: isPass != null ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
            },
          ),
        ],
        mobileCardBuilder: (context, item) {
          final gradeColor = _getGradeColor(item.grade);
          final examType = item.examType ?? 'General';
          final Color typeColor;
          if (examType.toLowerCase().contains('mid')) {
            typeColor = const Color(0xFF8B5CF6);
          } else if (examType.toLowerCase().contains('end') || examType.toLowerCase().contains('final')) {
            typeColor = const Color(0xFFEF4444);
          } else if (examType.toLowerCase().contains('class') || examType.toLowerCase().contains('test')) {
            typeColor = const Color(0xFF0EA5E9);
          } else {
            typeColor = const Color(0xFF10B981);
          }
          return Card(
            color: isDark ? _cardBg : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: isDark ? _cardBorder : Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(item.examTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
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
                  Row(
                    children: [
                      Text('${_getSubjectIcon(item.subject)} ${item.subject}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(examType, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: typeColor)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Marks: ${item.marksObtained.toInt()} / ${item.maxMarks.toInt()}', style: const TextStyle(fontSize: 11)),
                      Text('Date: ${item.examDate.day}/${item.examDate.month}/${item.examDate.year}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                  if (item.isPass != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          item.isPass! ? Icons.check_circle : Icons.cancel,
                          size: 12,
                          color: item.isPass! ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.isPass! ? 'Passed' : 'Failed',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: item.isPass! ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          ),
                        ),
                        if (item.rank != null) ...[
                          const SizedBox(width: 12),
                          const Icon(Icons.emoji_events, size: 12, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 4),
                          Text('Rank #${item.rank}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFF59E0B))),
                        ],
                      ],
                    ),
                  ],
                  if (item.remarks != null && item.isPass == null) ...[
                    const SizedBox(height: 6),
                    Text('Remarks: ${item.remarks}', style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey)),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── HOMEWORKS TAB ─────────────────────────────────────────
  Widget _buildHomeworksTab(bool isDark) {
    if (_homeworkAssignments.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('No graded homework assignments available', style: TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      child: AzureGrid<HomeworkAssignment>(
        title: 'Homework Grades Ledger'.tr(ref),
        items: _homeworkAssignments,
        onRefresh: _loadResults,
        enableSelection: false,
        searchMatcher: (item) =>
            '${item.title} ${item.subject} ${item.grade ?? ""} ${item.teacherRemarks ?? ""}',
        filters: [
          AzureGridFilter<HomeworkAssignment>(
            label: 'Subject',
            options: _homeworkAssignments.map((h) => h.subject).toSet().toList(),
            filterFn: (item, option) => item.subject == option,
          ),
        ],
        columns: [
          AzureGridColumn<HomeworkAssignment>(
            label: 'Assignment Title',
            width: 200,
            compare: (a, b) => a.title.compareTo(b.title),
            cellBuilder: (item) => Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          AzureGridColumn<HomeworkAssignment>(
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
          AzureGridColumn<HomeworkAssignment>(
            label: 'Date Graded',
            width: 120,
            compare: (a, b) => (a.submittedAt ?? a.dueDate).compareTo(b.submittedAt ?? b.dueDate),
            cellBuilder: (item) {
              final date = item.submittedAt ?? item.dueDate;
              return Text('${date.day}/${date.month}/${date.year}');
            },
          ),
          AzureGridColumn<HomeworkAssignment>(
            label: 'Marks',
            width: 100,
            compare: (a, b) => (a.marksObtained ?? 0.0).compareTo(b.marksObtained ?? 0.0),
            cellBuilder: (item) => Text('${(item.marksObtained ?? 0).toInt()} / ${(item.maxMarks ?? 0)}'),
          ),
          AzureGridColumn<HomeworkAssignment>(
            label: 'Percentage',
            width: 110,
            compare: (a, b) {
              final aPct = (a.marksObtained ?? 0.0) / (a.maxMarks ?? 1) * 100;
              final bPct = (b.marksObtained ?? 0.0) / (b.maxMarks ?? 1) * 100;
              return aPct.compareTo(bPct);
            },
            cellBuilder: (item) {
              final max = item.maxMarks ?? 1;
              final pct = (item.marksObtained ?? 0) / max * 100;
              return Text('${pct.toStringAsFixed(1)}%');
            },
          ),
          AzureGridColumn<HomeworkAssignment>(
            label: 'Grade',
            width: 90,
            compare: (a, b) => (a.grade ?? '').compareTo(b.grade ?? ''),
            cellBuilder: (item) {
              final grade = item.grade ?? 'N/A';
              final gradeColor = _getGradeColor(grade);
              final gradeBg = _getGradeBg(grade);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: gradeBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: gradeColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  grade,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: gradeColor,
                  ),
                ),
              );
            },
          ),
          AzureGridColumn<HomeworkAssignment>(
            label: 'Feedback',
            width: 200,
            compare: (a, b) => (a.teacherRemarks ?? '').compareTo(b.teacherRemarks ?? ''),
            cellBuilder: (item) => Text(
              item.teacherRemarks ?? '-',
              style: TextStyle(
                color: item.teacherRemarks != null ? (isDark ? Colors.white70 : Colors.black87) : Colors.grey,
                fontStyle: item.teacherRemarks != null ? FontStyle.normal : FontStyle.italic,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        mobileCardBuilder: (context, item) {
          final grade = item.grade ?? 'N/A';
          final gradeColor = _getGradeColor(grade);
          return Card(
            color: isDark ? _cardBg : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: isDark ? _cardBorder : Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getGradeBg(grade),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(grade, style: TextStyle(color: gradeColor, fontWeight: FontWeight.bold, fontSize: 9)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${_getSubjectIcon(item.subject)} ${item.subject}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Marks: ${(item.marksObtained ?? 0).toInt()} / ${(item.maxMarks ?? 0)}', style: const TextStyle(fontSize: 11)),
                      Text(
                        'Date: ${(item.submittedAt ?? item.dueDate).day}/${(item.submittedAt ?? item.dueDate).month}/${(item.submittedAt ?? item.dueDate).year}',
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                  if (item.teacherRemarks != null) ...[
                    const SizedBox(height: 6),
                    Text('Feedback: ${item.teacherRemarks}', style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey)),
                  ],
                ],
              ),
            ),
          );
        },
      ),
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

  void _showDownloadDialog(BuildContext context, {List<ExamResult> selected = const []}) {
    String downloadState = 'ready'; // 'ready', 'downloading', 'success', 'error'
    String errorMessage = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final String filename = selected.isEmpty
                ? 'Consolidated_Academic_Report.pdf'
                : 'Selected_Exams_Report.pdf';
            final String subtitle = selected.isEmpty
                ? 'Your consolidated academic ledger for 2026 has been generated.'
                : '${selected.length} selected exams will be compiled into your report card.';

            Future<void> startDownload() async {
              setState(() {
                downloadState = 'downloading';
                errorMessage = '';
              });

              try {
                final List<String> selectedIds = selected.map((item) => item.id).toList();
                final bytes = await _apiService.downloadResultsPdf(selectedIds);

                await getDownloadHelper().downloadBytes(bytes, filename);

                if (context.mounted) {
                  setState(() {
                    downloadState = 'success';
                  });
                }
              } catch (e) {
                if (context.mounted) {
                  setState(() {
                    downloadState = 'error';
                    errorMessage = e.toString().replaceAll('ApiException: ', '');
                  });
                }
              }
            }

            Widget buildContent() {
              switch (downloadState) {
                case 'downloading':
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 20),
                      const SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Generating Report Card...'.tr(ref),
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : StudentColors.text,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Compiling grades and rendering official university-format PDF transcript.'.tr(ref),
                        style: const TextStyle(color: StudentColors.text3, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                    ],
                  );
                case 'success':
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('✅', style: TextStyle(fontSize: 50)),
                      const SizedBox(height: 12),
                      Text(
                        'Download Complete!'.tr(ref),
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : StudentColors.text,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your report card has been successfully saved to your device.'.tr(ref),
                        style: const TextStyle(color: StudentColors.text3, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        child: Text('Close'.tr(ref)),
                      ),
                    ],
                  );
                case 'error':
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('❌', style: TextStyle(fontSize: 50)),
                      const SizedBox(height: 12),
                      Text(
                        'Download Failed'.tr(ref),
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : StudentColors.text,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        errorMessage.isNotEmpty ? errorMessage : 'An unexpected error occurred during PDF compilation.'.tr(ref),
                        style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text('Cancel'.tr(ref)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: startDownload,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text('Retry'.tr(ref)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                case 'ready':
                default:
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('📄', style: TextStyle(fontSize: 50)),
                      const SizedBox(height: 8),
                      Text(
                        'Report Card Ready!'.tr(ref),
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : StudentColors.text,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: const TextStyle(color: StudentColors.text3, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF4F46E5).withValues(alpha: 0.12) : const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '📥 $filename',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                      color: Color(0xFF4F46E5),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text('Format: PDF', style: TextStyle(color: StudentColors.text3, fontSize: 10)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: startDownload,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        child: Text('Download Report Card'.tr(ref)),
                      ),
                    ],
                  );
              }
            }

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: buildContent(),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
