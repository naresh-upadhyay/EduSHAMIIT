import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/services/teacher_api_service.dart';
import 'package:edu_shamiit_ai/shared/widgets/azure_grid.dart';
import 'dart:convert';
import 'package:edu_shamiit_ai/core/utils/download_helper_stub.dart'
    if (dart.library.js) 'package:edu_shamiit_ai/core/utils/download_helper_web.dart'
    if (dart.library.io) 'package:edu_shamiit_ai/core/utils/download_helper_mobile.dart';

class PublishResultScreen extends ConsumerStatefulWidget {
  final String examId;
  const PublishResultScreen({super.key, required this.examId});

  @override
  ConsumerState<PublishResultScreen> createState() =>
      _PublishResultScreenState();
}

class _PublishResultScreenState extends ConsumerState<PublishResultScreen> {
  final TeacherApiService _apiService = TeacherApiService();

  List<Map<String, dynamic>> _submissions = [];
  bool _isLoading = true;
  bool _isPublishing = false;
  String? _error;

  String _examTitle = '';
  double _totalMarks = 100.0;
  double _passingMarks = 40.0;

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
      final submissions = await _apiService.getExamSubmissions(widget.examId);
      final exams = await _apiService.getExams();
      final exam = exams.firstWhere(
        (e) => e.id == widget.examId,
        orElse: () => throw Exception('Exam details not found'),
      );

      if (mounted) {
        setState(() {
          _submissions = submissions;
          _examTitle = exam.title;
          _totalMarks = exam.totalMarks.toDouble();
          _passingMarks = exam.totalMarks * 0.4;
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

  List<Map<String, dynamic>> _getProcessedGrades() {
    final list = _submissions
        .where((s) => s['status'] == 'submitted' || s['status'] == 'graded')
        .toList();

    // Sort by score desc, putting null scores at the end
    list.sort((a, b) {
      final aScore = a['score'] != null
          ? double.tryParse(a['score'].toString()) ?? -1.0
          : -1.0;
      final bScore = b['score'] != null
          ? double.tryParse(b['score'].toString()) ?? -1.0
          : -1.0;
      return bScore.compareTo(aScore);
    });

    final List<Map<String, dynamic>> processed = [];
    for (int i = 0; i < list.length; i++) {
      final sub = list[i];
      final profile = sub['profiles'] as Map<String, dynamic>? ?? {};
      final name = profile['full_name']?.toString() ?? 'Student';
      final roll = profile['roll_number']?.toString() ?? '';

      final scoreVal = sub['score'] != null
          ? double.tryParse(sub['score'].toString())
          : null;

      String gradeLetter = '—';
      bool isPass = false;
      String percentageStr = '—';

      if (scoreVal != null) {
        final pct = (scoreVal / _totalMarks) * 100;
        percentageStr = '${pct.toStringAsFixed(1)}%';
        isPass = scoreVal >= _passingMarks;
        if (pct >= 90) {
          gradeLetter = 'A+';
        } else if (pct >= 80)
          gradeLetter = 'A';
        else if (pct >= 70)
          gradeLetter = 'B+';
        else if (pct >= 60)
          gradeLetter = 'B';
        else if (pct >= 50)
          gradeLetter = 'C';
        else if (pct >= 40)
          gradeLetter = 'D';
        else
          gradeLetter = 'F';
      }

      processed.add({
        'rank': scoreVal != null ? i + 1 : null,
        'name': name,
        'roll': roll,
        'score': scoreVal != null ? scoreVal.toStringAsFixed(1) : 'Not Graded',
        'percentage': percentageStr,
        'grade': gradeLetter,
        'status': scoreVal != null ? (isPass ? 'PASS' : 'FAIL') : 'UNGRADED',
      });
    }
    return processed;
  }

  Future<void> _publishResults() async {
    setState(() => _isPublishing = true);
    try {
      await _apiService.publishExamResults(widget.examId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('🎉 Exam results successfully published and notified!'),
            backgroundColor: _success,
          ),
        );
        context.pushReplacement('/teacher/exams/analytics/${widget.examId}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to publish results: $e'),
            backgroundColor: _danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  void _exportResultsAsCSV() {
    try {
      final processed = _getProcessedGrades();
      if (processed.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No results available to export.')),
        );
        return;
      }

      // Build CSV content
      final csvBuffer = StringBuffer();
      // Headers
      csvBuffer
          .writeln('Rank,Roll No,Student Name,Score,Percentage,Grade,Status');

      // Rows
      for (final item in processed) {
        final rank = item['rank'] != null ? '#${item['rank']}' : '—';
        final roll = item['roll'] ?? '';
        final name = item['name'] ?? '';
        final score = item['score'] ?? '';
        final percentage = item['percentage'] ?? '';
        final grade = item['grade'] ?? '';
        final status = item['status'] ?? '';

        // Escape quotes if name has commas
        final escapedName = name.contains(',') ? '"$name"' : name;

        csvBuffer.writeln(
            '$rank,$roll,$escapedName,$score,$percentage,$grade,$status');
      }

      // Convert to UTF-8 bytes
      final bytes = utf8.encode(csvBuffer.toString());

      // Get filename
      final filename =
          'Exam_Results_${_examTitle.replaceAll(RegExp(r'[^\w\s\-]'), '_')}.csv';

      // Trigger download
      getDownloadHelper().downloadBytes(bytes, filename);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 Results exported successfully as $filename'),
          backgroundColor: _success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Export failed: $e'),
          backgroundColor: _danger,
        ),
      );
    }
  }

  void _showPublishConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Publish Results?',
            style: TextStyle(
                fontFamily: AppFonts.heading, fontWeight: FontWeight.bold)),
        content: const Text(
          'This will make grades instantly visible on student portals and dispatch notifications to students & parents. Ranks will be finalized.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _primary, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _publishResults();
            },
            child: const Text('Publish Now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalSubs = _submissions.length;
    final gradedSubs =
        _submissions.where((s) => s['status'] == 'graded').length;
    final ungradedSubs = totalSubs - gradedSubs;

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: Text(
          _examTitle.isNotEmpty ? 'Publish: $_examTitle' : 'Publish Results',
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
                : Column(
                    children: [
                      _buildSummaryBanner(totalSubs, gradedSubs, ungradedSubs),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: AzureGrid<Map<String, dynamic>>(
                            title: 'Leaderboard Preview',
                            items: _getProcessedGrades(),
                            columns: [
                              AzureGridColumn<Map<String, dynamic>>(
                                label: 'Rank',
                                width: 70,
                                cellBuilder: (item) {
                                  final rank = item['rank'];
                                  if (rank == null) {
                                    return const Text('—',
                                        style: TextStyle(color: Colors.grey));
                                  }
                                  return CircleAvatar(
                                    radius: 12,
                                    backgroundColor: rank == 1
                                        ? const Color(0xFFFEF3C7)
                                        : rank == 2
                                            ? const Color(0xFFF1F5F9)
                                            : Colors.transparent,
                                    child: Text(
                                      '#$rank',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: rank == 1
                                            ? const Color(0xFFD97706)
                                            : Colors.black87,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              AzureGridColumn<Map<String, dynamic>>(
                                label: 'Roll No',
                                width: 80,
                                cellBuilder: (item) => Text(item['roll'] ?? '—',
                                    style: const TextStyle(fontSize: 12)),
                              ),
                              AzureGridColumn<Map<String, dynamic>>(
                                label: 'Student Name',
                                width: 180,
                                cellBuilder: (item) => Text(
                                  item['name'],
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13),
                                ),
                              ),
                              AzureGridColumn<Map<String, dynamic>>(
                                label: 'Score',
                                width: 90,
                                cellBuilder: (item) => Text(
                                  '${item['score']} / ${_totalMarks.toInt()}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12),
                                ),
                              ),
                              AzureGridColumn<Map<String, dynamic>>(
                                label: 'Percentage',
                                width: 90,
                                cellBuilder: (item) => Text(item['percentage'],
                                    style: const TextStyle(fontSize: 12)),
                              ),
                              AzureGridColumn<Map<String, dynamic>>(
                                label: 'Grade',
                                width: 70,
                                cellBuilder: (item) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: item['grade'] == 'F'
                                        ? _danger.withValues(alpha: 0.1)
                                        : _success.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    item['grade'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: item['grade'] == 'F'
                                          ? _danger
                                          : _success,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              AzureGridColumn<Map<String, dynamic>>(
                                label: 'Status',
                                width: 90,
                                cellBuilder: (item) {
                                  final stat = item['status'];
                                  final isPass = stat == 'PASS';
                                  final isFail = stat == 'FAIL';
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isPass
                                          ? _success.withValues(alpha: 0.1)
                                          : isFail
                                              ? _danger.withValues(alpha: 0.1)
                                              : _warning.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      stat,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: isPass
                                            ? _success
                                            : isFail
                                                ? _danger
                                                : _warning,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  );
                                },
                              ),
                            ],
                            mobileCardBuilder: (context, item) =>
                                _buildMobileCard(item),
                            searchMatcher: (item) =>
                                '${item['name']} ${item['roll']}',
                          ),
                        ),
                      ),
                      _buildActionFooter(ungradedSubs),
                    ],
                  ),
      ),
    );
  }

  Widget _buildSummaryBanner(int total, int graded, int ungraded) {
    final isComplete = ungraded == 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          Icon(
            isComplete
                ? Icons.check_circle_outline_rounded
                : Icons.pending_actions_rounded,
            color: isComplete ? _success : _warning,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isComplete
                      ? 'Grading Complete! Ready to Publish.'
                      : 'Pending Evaluation Needed!',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isComplete ? _success : _warning,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Total Submissions: $total  •  Graded: $graded  •  Ungraded: $ungraded',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCard(Map<String, dynamic> item) {
    final stat = item['status'];
    final isPass = stat == 'PASS';
    final isFail = stat == 'FAIL';
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            if (item['rank'] != null)
              CircleAvatar(
                radius: 14,
                backgroundColor: item['rank'] == 1
                    ? const Color(0xFFFEF3C7)
                    : const Color(0xFFF1F5F9),
                child: Text(
                  '#${item['rank']}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: item['rank'] == 1
                        ? const Color(0xFFD97706)
                        : Colors.grey.shade700,
                  ),
                ),
              )
            else
              const Icon(Icons.help_outline, color: Colors.grey, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name'],
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Roll No: ${item['roll']}  •  Marks: ${item['score']}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isPass
                        ? _success.withValues(alpha: 0.1)
                        : isFail
                            ? _danger.withValues(alpha: 0.1)
                            : _warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    stat,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      color: isPass
                          ? _success
                          : isFail
                              ? _danger
                              : _warning,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Grade ${item['grade']}',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isFail ? _danger : _success,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionFooter(int ungradedCount) {
    final canPublish = ungradedCount == 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _exportResultsAsCSV,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Export Results'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: _border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: canPublish && !_isPublishing
                  ? _showPublishConfirmDialog
                  : null,
              icon: _isPublishing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.publish_rounded, size: 18),
              label: Text(_isPublishing ? 'Publishing...' : 'Publish & Notify'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
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
