import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/services/student_api_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:edu_shamiit_ai/core/utils/download_helper_stub.dart'
    if (dart.library.js) 'package:edu_shamiit_ai/core/utils/download_helper_web.dart'
    if (dart.library.io) 'package:edu_shamiit_ai/core/utils/download_helper_mobile.dart';
import 'package:edu_shamiit_ai/core/providers/auth_provider.dart';

class ExamResultScreen extends ConsumerStatefulWidget {
  final String examId;
  const ExamResultScreen({super.key, required this.examId});

  @override
  ConsumerState<ExamResultScreen> createState() => _ExamResultScreenState();
}

class _ExamResultScreenState extends ConsumerState<ExamResultScreen> {
  final StudentApiService _apiService = StudentApiService();
  
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _resultData;

  static const _tealDark = Color(0xFF115E59);
  static const _tealLight = Color(0xFF0D9488);
  static const _surfaceBg = Color(0xFFF8FAFC);
  static const _cardBorder = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _loadResultData();
  }

  Future<void> _loadResultData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _apiService.getOnlineExamResultDetails(widget.examId);
      if (mounted) {
        setState(() {
          _resultData = data;
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

  Color _getGradeColor(String grade) {
    final g = grade.toUpperCase();
    if (g.startsWith('A')) return const Color(0xFF10B981); // Emerald
    if (g.startsWith('B')) return const Color(0xFF3B82F6); // Blue
    if (g.startsWith('C') || g.startsWith('D')) return const Color(0xFFF59E0B); // Amber
    return const Color(0xFFEF4444); // Red
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _surfaceBg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: _tealLight),
              SizedBox(height: 16),
              Text(
                'Analyzing Exam Submission...',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: _surfaceBg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 54, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error loading results:\n$_error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black87, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _loadResultData,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _tealDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go('/student/exams'),
                  child: const Text('Back to Exams'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final data = _resultData!;
    final examTitle = data['exam_title']?.toString() ?? 'Exam Result';
    final score = (data['score_obtained'] as num?)?.toDouble() ?? 0.0;
    final totalMarks = (data['total_marks'] as num?)?.toDouble() ?? 100.0;
    final pct = (data['accuracy_ratio'] as num?)?.toDouble() ?? 0.0;
    final grade = data['grade']?.toString() ?? 'F';
    final rank = data['rank'] != null ? '${data['rank']}' : '-';
    final classTotal = '${data['class_total']}';
    final status = data['status']?.toString() ?? 'FAIL';
    final isPass = data['is_pass'] as bool? ?? false;

    final totalQ = data['total_questions'] ?? 0;
    final correctAnswers = data['correct_answers'] ?? 0;
    final incorrectAnswers = data['incorrect_answers'] ?? 0;
    final skippedAnswers = data['skipped_answers'] ?? 0;
    final timeTaken = data['time_taken']?.toString() ?? 'N/A';
    final integrity = data['integrity_rating']?.toString() ?? 'Excellent';
    
    final List<dynamic> rawTopics = data['topic_stats'] ?? [];
    final topicStats = rawTopics.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final recommendation = data['recommendation']?.toString() ?? '';
    final List<dynamic> rawReview = data['question_review'] ?? [];
    final questionReview = rawReview.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    return Scaffold(
      backgroundColor: _surfaceBg,
      appBar: AppBar(
        title: Text(
          examTitle,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: AppFonts.heading,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        backgroundColor: _tealDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => context.go('/student/exams'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Score Meter Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F2C2C), Color(0xFF115E59), Color(0xFF0D9488)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'YOUR FINAL PERFORMANCE SCORE',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Custom Painter Score Arc Gauge
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _ScoreCirclePainter(
                                percentage: pct,
                                scoreColor: isPass ? const Color(0xFF2DD4BF) : const Color(0xFFF87171),
                              ),
                            ),
                          ),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  score.toStringAsFixed(score.truncateToDouble() == score ? 0 : 1),
                                  style: const TextStyle(
                                    fontFamily: AppFonts.heading,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                                Container(
                                  height: 1,
                                  width: 40,
                                  color: Colors.white30,
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                ),
                                Text(
                                  '${totalMarks.toInt()} Marks',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Badges grid
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildHeroBadge(
                          'Class Rank',
                          rank == '-' ? '-' : '$rank / $classTotal',
                          Icons.workspace_premium_rounded,
                          const Color(0xFFF59E0B),
                        ),
                        _buildHeroBadge(
                          'Grade Letter',
                          grade,
                          Icons.text_fields_rounded,
                          _getGradeColor(grade),
                        ),
                        _buildHeroBadge(
                          'Pass Status',
                          status,
                          isPass ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          isPass ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Detailed stats header
              const Text(
                'Detailed Examination Stats',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              // Detailed stats card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    _buildStatDetailRow('Total Questions', '$totalQ questions', Icons.quiz_outlined, Colors.grey),
                    const Divider(height: 24, color: Color(0xFFF1F5F9)),
                    _buildStatDetailRow('Correct Answers', '$correctAnswers answers', Icons.check_circle_outline_rounded, const Color(0xFF10B981)),
                    const Divider(height: 24, color: Color(0xFFF1F5F9)),
                    _buildStatDetailRow('Incorrect Answers', '$incorrectAnswers answers', Icons.highlight_off_rounded, const Color(0xFFEF4444)),
                    const Divider(height: 24, color: Color(0xFFF1F5F9)),
                    _buildStatDetailRow('Skipped Questions', '$skippedAnswers skipped', Icons.skip_next_rounded, Colors.grey),
                    const Divider(height: 24, color: Color(0xFFF1F5F9)),
                    _buildStatDetailRow('Exam Duration', timeTaken, Icons.access_time_rounded, const Color(0xFF3B82F6)),
                    const Divider(height: 24, color: Color(0xFFF1F5F9)),
                    _buildStatDetailRow('Accuracy Ratio', '${pct.toStringAsFixed(1)}%', Icons.track_changes_rounded, const Color(0xFF8B5CF6)),
                    const Divider(height: 24, color: Color(0xFFF1F5F9)),
                    _buildStatDetailRow('Integrity & Proctoring', integrity, Icons.security_rounded, const Color(0xFF6366F1)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Topic-wise analysis header
              if (topicStats.isNotEmpty) ...[
                const Text(
                  'Topic Mastery breakdown',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _cardBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    children: topicStats.map((topic) {
                      final acc = (topic['accuracy'] as num).toInt();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  topic['name'] as String,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                                Text(
                                  '${topic['count']} correct ($acc%)',
                                  style: const TextStyle(fontSize: 10.5, color: Colors.grey, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: acc / 100.0,
                                minHeight: 6,
                                backgroundColor: const Color(0xFFF1F5F9),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  acc >= 75 ? const Color(0xFF10B981) : (acc >= 50 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),
              ],


              // AI revision section
              if (recommendation.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFC7D2FE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.psychology_rounded, color: Color(0xFF4F46E5), size: 22),
                          SizedBox(width: 8),
                          Text(
                            'AI STUDY RECOMMENDATION',
                            style: TextStyle(
                              fontFamily: AppFonts.heading,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF4338CA),
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        recommendation,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF312E81),
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
              ],

              // Bottom Actions
              // Review Answers button (if question_review is available)
              if (questionReview.isNotEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => context.go('/student/exams/review/${widget.examId}'),
                    icon: const Icon(Icons.manage_search_rounded, size: 18, color: Colors.white),
                    label: const Text('Review Answers'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F2C2C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFF0D9488), width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Generating detailed PDF report...'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                    try {
                      final authState = ref.read(authProvider);
                      final name = authState.userData?['full_name']?.toString() ??
                          authState.userData?['name']?.toString() ??
                          'Student';
                      final sId = authState.userData?['id']?.toString() ?? 'N/A';
                      final sClass = authState.userData?['class']?.toString() ?? '10A';

                      await _generateAndDownloadPdf(
                        studentName: name,
                        studentId: sId,
                        studentClass: sClass,
                        examTitle: examTitle,
                        score: score,
                        totalMarks: totalMarks,
                        pct: pct,
                        grade: grade,
                        rank: rank,
                        classTotal: classTotal,
                        status: status,
                        isPass: isPass,
                        totalQ: totalQ,
                        correctAnswers: correctAnswers,
                        incorrectAnswers: incorrectAnswers,
                        skippedAnswers: skippedAnswers,
                        timeTaken: timeTaken,
                        integrity: integrity,
                        topicStats: topicStats,
                        recommendation: recommendation,
                      );
                    } catch (e, stack) {
                      debugPrint('PDF Generation Error: $e\n$stack');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('❌ Error generating PDF: $e'),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.download_rounded, size: 18, color: Colors.white),
                  label: const Text('Download PDF Transcript'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _tealDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.go('/student/exams'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: const BorderSide(color: Colors.grey),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Return to Exams Dashboard',
                    style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBadge(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 9, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ],
    );
  }


  Widget _buildStatDetailRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 12.5, color: StudentColors.text2, fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: StudentColors.text,
          ),
        ),
      ],
    );
  }

  Future<void> _generateAndDownloadPdf({
    required String studentName,
    required String studentId,
    required String studentClass,
    required String examTitle,
    required double score,
    required double totalMarks,
    required double pct,
    required String grade,
    required String rank,
    required String classTotal,
    required String status,
    required bool isPass,
    required int totalQ,
    required int correctAnswers,
    required int incorrectAnswers,
    required int skippedAnswers,
    required String timeTaken,
    required String integrity,
    required List<Map<String, dynamic>> topicStats,
    required String recommendation,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header Section
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'EduSHAMIIT ACADEMY',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#115E59'),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'OFFICIAL PERFORMANCE TRANSCRIPT',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: isPass ? PdfColor.fromHex('#ECFDF5') : PdfColor.fromHex('#FEF2F2'),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        border: pw.Border.all(
                          color: isPass ? PdfColor.fromHex('#A7F3D0') : PdfColor.fromHex('#FCA5A5'),
                          width: 1,
                        ),
                      ),
                      child: pw.Text(
                        status,
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: isPass ? PdfColor.fromHex('#065F46') : PdfColor.fromHex('#991B1B'),
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'ID: TR-${studentId.length >= 8 ? studentId.substring(0, 8).toUpperCase() : studentId.toUpperCase()}',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                    ),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 18),
            pw.Divider(color: PdfColors.grey200, thickness: 1),
            pw.SizedBox(height: 14),

            // Metadata Card
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F8FAFC'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('STUDENT INFO', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey500, letterSpacing: 0.8)),
                        pw.SizedBox(height: 6),
                        _pdfDetailRow('Name', studentName),
                        _pdfDetailRow('Roll Number', studentId),
                        _pdfDetailRow('Class Section', studentClass),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 24),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('EXAMINATION INFO', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey500, letterSpacing: 0.8)),
                        pw.SizedBox(height: 6),
                        _pdfDetailRow('Subject Title', examTitle),
                        _pdfDetailRow('Date Generated', _formatPdfDate(DateTime.now())),
                        _pdfDetailRow('Passing Threshold', '40%'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Performance Cards Row
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _pdfStatCard('Final Score', '${score.toStringAsFixed(score.truncateToDouble() == score ? 0 : 1)} / ${totalMarks.toInt()}', '#115E59'),
                _pdfStatCard('Accuracy', '${pct.toStringAsFixed(1)}%', '#8B5CF6'),
                _pdfStatCard('Class Rank', rank == '-' ? '-' : '$rank of $classTotal', '#F59E0B'),
                _pdfStatCard('Grade Letter', grade, '#10B981'),
              ],
            ),

            pw.SizedBox(height: 22),

            // Details and Topic Mastery Columns
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Metrics
                pw.Expanded(
                  flex: 1,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('TEST METRICS', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700, letterSpacing: 0.8)),
                      pw.SizedBox(height: 8),
                      _pdfBreakdownRow('Total Questions', '$totalQ'),
                      _pdfBreakdownRow('Correct Answers', '$correctAnswers'),
                      _pdfBreakdownRow('Incorrect Answers', '$incorrectAnswers'),
                      _pdfBreakdownRow('Skipped Questions', '$skippedAnswers'),
                      _pdfBreakdownRow('Duration', timeTaken),
                      _pdfBreakdownRow('Proctor Integrity', integrity),
                    ],
                  ),
                ),
                pw.SizedBox(width: 28),
                // Topic Mastery
                pw.Expanded(
                  flex: 1,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('TOPIC MASTERY', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700, letterSpacing: 0.8)),
                      pw.SizedBox(height: 8),
                      if (topicStats.isEmpty)
                        pw.Text('No topic data available.', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey500))
                      else
                        ...topicStats.map((t) {
                          final accVal = (t['accuracy'] as num).toInt();
                          return pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 8),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Expanded(
                                      child: pw.Text(
                                        t['name']?.toString() ?? 'General',
                                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                                      ),
                                    ),
                                    pw.Text('${t['count']} correct ($accVal%)', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey500)),
                                  ],
                                ),
                                pw.SizedBox(height: 3),
                                // Progress bar row container
                                pw.Container(
                                  height: 4,
                                  width: double.infinity,
                                  decoration: const pw.BoxDecoration(
                                    color: PdfColors.grey200,
                                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
                                  ),
                                  child: pw.Row(
                                    children: [
                                      pw.Container(
                                        height: 4,
                                        width: 120.0 * (accVal / 100.0),
                                        decoration: pw.BoxDecoration(
                                          color: accVal >= 75
                                              ? PdfColor.fromHex('#10B981')
                                              : (accVal >= 50 ? PdfColor.fromHex('#F59E0B') : PdfColor.fromHex('#EF4444')),
                                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 22),

            // AI Revision Path Box
            if (recommendation.isNotEmpty) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#EEF2FF'),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: PdfColor.fromHex('#C7D2FE')),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'AI REVISION RECOMMENDATIONS & REMARKS',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#4338CA'),
                        letterSpacing: 0.8,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      recommendation,
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        color: PdfColor.fromHex('#312E81'),
                        lineSpacing: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            pw.SizedBox(height: 24),

            // Certification Footer
            pw.Divider(color: PdfColors.grey200, thickness: 1),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'This report is digitally certified by the EduSHAMIIT Educational Board.',
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
                ),
                pw.Text(
                  'Page 1 of 1',
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
                ),
              ],
            ),
          ];
        },
      ),
    );

    final pdfBytes = await pdf.save();
    final safeExamTitle = examTitle.replaceAll(RegExp(r'[^\w\s\-]'), '').replaceAll(' ', '_');
    final filename = 'Report_Student_$safeExamTitle.pdf';

    if (kIsWeb) {
      try {
        await getDownloadHelper().downloadBytes(pdfBytes, filename);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('📄 Performance Report downloaded: $filename'),
              backgroundColor: const Color(0xFF115E59),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (e) {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfBytes,
          name: filename,
        );
      }
    } else {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: filename,
      );
    }
  }

  pw.Widget _pdfDetailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        children: [
          pw.Text('$label: ', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800)),
        ],
      ),
    );
  }

  pw.Widget _pdfStatCard(String label, String value, String colorHex) {
    return pw.Container(
      width: 110,
      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F8FAFC'),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        children: [
          pw.Text(label.toUpperCase(), style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex(colorHex),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfBreakdownRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
          pw.Text(value, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900)),
        ],
      ),
    );
  }

  String _formatPdfDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _ScoreCirclePainter extends CustomPainter {
  final double percentage;
  final Color scoreColor;
  _ScoreCirclePainter({required this.percentage, required this.scoreColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    // Background track arc
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
      
    canvas.drawCircle(center, radius, trackPaint);
    
    // Active progress arc
    final progressPaint = Paint()
      ..color = scoreColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
      
    final double angle = 2 * 3.1415926535 * (percentage / 100.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.1415926535 / 2, // Start at 12 o'clock
      angle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScoreCirclePainter oldDelegate) {
    return oldDelegate.percentage != percentage || oldDelegate.scoreColor != scoreColor;
  }
}
