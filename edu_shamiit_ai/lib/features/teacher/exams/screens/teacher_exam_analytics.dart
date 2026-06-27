import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/services/teacher_api_service.dart';

class TeacherExamAnalyticsScreen extends ConsumerStatefulWidget {
  final String examId;
  const TeacherExamAnalyticsScreen({super.key, required this.examId});

  @override
  ConsumerState<TeacherExamAnalyticsScreen> createState() =>
      _TeacherExamAnalyticsScreenState();
}

class _TeacherExamAnalyticsScreenState
    extends ConsumerState<TeacherExamAnalyticsScreen> {
  final TeacherApiService _apiService = TeacherApiService();

  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _analytics;

  static const _primary = Color(0xFF6366F1);
  static const _success = Color(0xFF10B981);
  static const _warning = Color(0xFFF59E0B);
  static const _danger = Color(0xFFEF4444);
  static const _surface = Color(0xFFF8FAFC);
  static const _border = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _apiService.getExamAnalytics(widget.examId);
      if (mounted) {
        setState(() {
          _analytics = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1024;
    final examTitle = _analytics?['exam']?['title']?.toString() ?? 'Exam';

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: Text(
          _isLoading ? 'Exam Analytics' : 'Analytics: $examTitle',
          style: const TextStyle(
            fontFamily: AppFonts.heading,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        backgroundColor: _primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => safeGoBack(context, '/teacher/exams'),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _primary))
            : _error != null
                ? _buildErrorWidget()
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: isDesktop
                        ? _buildDesktopLayout()
                        : _buildMobileLayout(),
                  ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsCardsGrid(),
                  const SizedBox(height: 20),
                  _buildGradeDistributionCard(),
                  const SizedBox(height: 20),
                  _buildQuestionAccuracyCard(),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHistogramCard(),
                  const SizedBox(height: 20),
                  _buildPerformersCard(),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatsCardsGrid(),
        const SizedBox(height: 20),
        _buildHistogramCard(),
        const SizedBox(height: 20),
        _buildGradeDistributionCard(),
        const SizedBox(height: 20),
        _buildQuestionAccuracyCard(),
        const SizedBox(height: 20),
        _buildPerformersCard(),
        const SizedBox(height: 24),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildStatsCardsGrid() {
    final stats = _analytics?['stats'] as Map<String, dynamic>? ?? {};
    final totalMarks = _analytics?['total_marks'] ?? 100.0;

    final avg = (stats['avg_score'] ?? 0.0) as num;
    final highest = (stats['highest_score'] ?? 0.0) as num;
    final lowest = (stats['lowest_score'] ?? 0.0) as num;
    final passRate = (stats['pass_rate'] ?? 0.0) as num;
    final submitted = stats['submitted'] ?? 0;
    final total = stats['total_submissions'] ?? 0;

    return GridView.count(
      crossAxisCount: Responsive.isMobile(context) ? 2 : 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: Responsive.isMobile(context) ? 1.5 : 1.35,
      children: [
        _buildStatCard(
          'Average Score',
          '${avg.toStringAsFixed(1)} / ${totalMarks.toInt()}',
          '${((avg / totalMarks) * 100).toStringAsFixed(1)}% Avg',
          Icons.analytics_rounded,
          _primary,
        ),
        _buildStatCard(
          'Pass Rate',
          '${passRate.toStringAsFixed(1)}%',
          'Passing: ${_analytics?['passing_marks']?.toString() ?? ''}M',
          Icons.check_circle_outline_rounded,
          _success,
        ),
        _buildStatCard(
          'Participation',
          '$submitted / $total',
          '${total > 0 ? ((submitted / total) * 100).toStringAsFixed(1) : 0}% Turned in',
          Icons.people_rounded,
          _warning,
        ),
        _buildStatCard(
          'Score Spread',
          '${highest.toStringAsFixed(1)} / ${lowest.toStringAsFixed(1)}',
          'Highest vs Lowest',
          Icons.compare_arrows_rounded,
          _danger,
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey),
              ),
              Icon(icon, size: 18, color: color),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                    fontSize: 9.5, color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGradeDistributionCard() {
    final gradeDist =
        _analytics?['grade_distribution'] as Map<String, dynamic>? ?? {};
    final total = gradeDist.values.fold(0, (sum, val) => sum + (val as int));

    // Grades palette
    final colors = {
      'A+': const Color(0xFF10B981), // Green
      'A': const Color(0xFF34D399), // Light Green
      'B+': const Color(0xFF3B82F6), // Blue
      'B': const Color(0xFF60A5FA), // Light Blue
      'C': const Color(0xFFF59E0B), // Orange
      'D': const Color(0xFFFB923C), // Light Orange
      'F': const Color(0xFFEF4444), // Red
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Grade Distribution',
            style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 14,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          if (total == 0)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('No grades data available',
                    style: TextStyle(color: Colors.grey)),
              ),
            )
          else ...[
            // Horizontal Segmented Bar Chart
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 24,
                child: Row(
                  children: gradeDist.entries.map((e) {
                    final count = e.value as int;
                    if (count == 0) return const SizedBox.shrink();
                    final pct = count / total;
                    return Expanded(
                      flex: (pct * 1000).toInt(),
                      child: Container(
                        color: colors[e.key] ?? Colors.grey,
                        child: Center(
                          child: Text(
                            e.key,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Legend
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: gradeDist.entries.map((e) {
                final count = e.value as int;
                final pct =
                    total > 0 ? (count / total * 100).toStringAsFixed(1) : '0';
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colors[e.key] ?? Colors.grey,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${e.key}: $count ($pct%)',
                      style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistogramCard() {
    final dist =
        _analytics?['score_distribution'] as Map<String, dynamic>? ?? {};
    final maxVal = dist.values
        .fold(0, (maxVal, val) => val as int > maxVal ? val : maxVal);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Score Distribution',
            style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 14,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          if (dist.isEmpty)
            const Center(
                child: Text('No submissions graded yet',
                    style: TextStyle(color: Colors.grey)))
          else ...[
            SizedBox(
              height: 160,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: dist.entries.map((e) {
                  final val = e.value as int;
                  final pct = maxVal > 0 ? val / maxVal : 0.0;
                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (val > 0)
                          Text(
                            '$val',
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _primary),
                          ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: pct * 110 > 4.0 ? pct * 110 : 4.0,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_primary, Color(0xFF818CF8)],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Label (show only start of range for compactness)
                        Text(
                          e.key.replaceAll('%', ''),
                          style: TextStyle(
                              fontSize: 7.5,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestionAccuracyCard() {
    final qStats = _analytics?['question_stats'] as List? ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Question Performance Analysis',
            style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 14,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (qStats.isEmpty)
            const Text('No question statistics available',
                style: TextStyle(color: Colors.grey))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: qStats.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 20, color: _border),
              itemBuilder: (context, idx) {
                final q = qStats[idx] as Map<String, dynamic>;
                final acc = q['accuracy'] != null
                    ? (q['accuracy'] as num).toDouble()
                    : null;
                final text = q['text'] ?? 'Question';
                final marks = q['marks'] ?? 0;
                final type = q['type'] ?? 'mcq';

                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: _primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        type.toString().toUpperCase(),
                        style: const TextStyle(
                            fontSize: 8.5,
                            color: _primary,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            text,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text('Weight: $marks Marks',
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          acc != null ? '${acc.toStringAsFixed(0)}%' : 'Manual',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: acc == null
                                ? Colors.grey
                                : acc >= 75
                                    ? _success
                                    : acc >= 50
                                        ? _warning
                                        : _danger,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          acc == null ? 'Subjective' : 'Accuracy',
                          style: TextStyle(
                              fontSize: 8.5, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPerformersCard() {
    final top = _analytics?['top_performers'] as List? ?? [];
    final bottom = _analytics?['bottom_performers'] as List? ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: DefaultTabController(
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Student Standings',
              style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 14,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const TabBar(
              labelColor: _primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: _primary,
              labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              tabs: [
                Tab(text: 'Top Performers'),
                Tab(text: 'Needs Support'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 250,
              child: TabBarView(
                children: [
                  _buildPerformersList(top, isTop: true),
                  _buildPerformersList(bottom, isTop: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformersList(List list, {required bool isTop}) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          isTop ? 'No toppers data' : 'No support candidates data',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, idx) {
        final p = list[idx] as Map<String, dynamic>;
        final name = p['name'] ?? 'Student';
        final roll = p['roll'] ?? '';
        final score = p['score'] ?? 0.0;
        final pct = p['percentage'] ?? 0.0;
        final grade = p['grade'] ?? '';

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: isTop
                ? _success.withValues(alpha: 0.1)
                : _danger.withValues(alpha: 0.1),
            child: Text(
              '${idx + 1}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isTop ? _success : _danger,
              ),
            ),
          ),
          title: Text(
            name,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            'Roll No: $roll',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$score Marks',
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Text(
                'Grade $grade ($pct%)',
                style: TextStyle(
                    fontSize: 9.5,
                    color: isTop ? _success : _danger,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Downloading PDF analytics report...')),
              );
            },
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
            label: const Text('Export PDF Report'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, color: _danger, size: 48),
          const SizedBox(height: 16),
          Text(_error ?? 'An unexpected error occurred',
              style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadData,
            style: ElevatedButton.styleFrom(
                backgroundColor: _primary, foregroundColor: Colors.white),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
