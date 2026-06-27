import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/services/teacher_api_service.dart';

class ManualEvaluationScreen extends ConsumerStatefulWidget {
  final String examId;
  const ManualEvaluationScreen({super.key, required this.examId});

  @override
  ConsumerState<ManualEvaluationScreen> createState() =>
      _ManualEvaluationScreenState();
}

class _ManualEvaluationScreenState extends ConsumerState<ManualEvaluationScreen>
    with TickerProviderStateMixin {
  final TeacherApiService _apiService = TeacherApiService();

  List<Map<String, dynamic>> _submissions = [];
  List<Map<String, dynamic>> _allQuestions = [];
  List<Map<String, dynamic>> _subjectiveQuestions = [];

  int _currentStudentIndex = 0;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isAutoGradingBulk = false;
  bool _isOffline = false;
  String? _error;
  String _studentSearchQuery = '';

  final Map<String, TextEditingController> _scoreControllers = {};
  final TextEditingController _overallRemarksController =
      TextEditingController();
  late TabController _tabController;

  static const _primary = Color(0xFF6366F1);
  static const _success = Color(0xFF10B981);
  static const _warning = Color(0xFFF59E0B);
  static const _danger = Color(0xFFEF4444);
  static const _surface = Color(0xFFF8FAFC);
  static const _border = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final exam = await _apiService.getExam(widget.examId);
      _isOffline = (exam['exam_type']?.toString().toLowerCase() == 'offline');

      final questions = await _apiService.getExamQuestions(widget.examId);
      final submissionsData =
          await _apiService.getExamSubmissions(widget.examId);
      final filtered = submissionsData
          .where((s) => s['status'] == 'submitted' || s['status'] == 'graded')
          .toList();
      final subjective = _isOffline
          ? questions
          : questions.where((q) => q['question_type'] == 'subjective').toList();

      if (mounted) {
        setState(() {
          _allQuestions = questions;
          _subjectiveQuestions = subjective;
          _submissions = filtered;
          _isLoading = false;
        });
        _initControllersForStudent();
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

  void _initControllersForStudent() {
    for (final c in _scoreControllers.values) {
      c.dispose();
    }
    _scoreControllers.clear();
    _overallRemarksController.clear();
    if (_submissions.isEmpty || _currentStudentIndex >= _submissions.length) {
      return;
    }

    final sub = _submissions[_currentStudentIndex];
    for (final q in _subjectiveQuestions) {
      // Find previous score for this subjective question if saved in sub['answers']
      final answers = sub['answers'] as Map<String, dynamic>? ?? {};
      final savedVal = answers[q['id']] ?? answers[q['id']?.toString()];
      String initialScore = '';
      if (savedVal != null) {
        if (savedVal is Map && savedVal['awarded_marks'] != null) {
          initialScore = savedVal['awarded_marks'].toString();
        } else if (savedVal is num) {
          initialScore = savedVal.toString();
        }
      }
      _scoreControllers[q['id']] = TextEditingController(text: initialScore);
    }
    _overallRemarksController.text = sub['remarks'] ?? '';
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in _scoreControllers.values) {
      c.dispose();
    }
    _overallRemarksController.dispose();
    super.dispose();
  }

  double _calculateAutoGradedMarks(Map<String, dynamic> sub) {
    if (_isOffline) return 0.0;
    final answers = sub['answers'] as Map<String, dynamic>? ?? {};
    double m = 0.0;
    for (final q in _allQuestions) {
      if (q['question_type'] == 'subjective') continue;
      final qId = q['id'];
      final sAns = answers[qId] ?? answers[qId?.toString()];
      final cAns = q['correct_answer']?.toString().trim().toLowerCase();
      if (sAns != null &&
          cAns != null &&
          sAns.toString().trim().toLowerCase() == cAns) {
        m += (q['marks'] as num?)?.toDouble() ?? 0.0;
      }
    }
    return m;
  }

  double get _currentAutoGradedMarks {
    if (_submissions.isEmpty || _currentStudentIndex >= _submissions.length) {
      return 0.0;
    }
    return _calculateAutoGradedMarks(_submissions[_currentStudentIndex]);
  }

  bool get _isCurrentStudentGraded {
    if (_submissions.isEmpty || _currentStudentIndex >= _submissions.length) {
      return false;
    }
    return _submissions[_currentStudentIndex]['status'] == 'graded';
  }

  int get _gradedCount =>
      _submissions.where((s) => s['status'] == 'graded').length;

  String _getStudentName() {
    if (_submissions.isEmpty || _currentStudentIndex >= _submissions.length) {
      return 'Student';
    }
    final profile = _submissions[_currentStudentIndex]['profiles']
            as Map<String, dynamic>? ??
        {};
    return profile['full_name']?.toString() ?? 'Student';
  }

  String _getRollNumber() {
    if (_submissions.isEmpty || _currentStudentIndex >= _submissions.length) {
      return '';
    }
    final profile = _submissions[_currentStudentIndex]['profiles']
            as Map<String, dynamic>? ??
        {};
    return profile['roll_number']?.toString() ?? '';
  }

  Future<void> _submitGrade() async {
    if (_submissions.isEmpty || _currentStudentIndex >= _submissions.length) {
      return;
    }
    final sub = _submissions[_currentStudentIndex];
    double subjTotal = 0.0;

    // Validate scores first
    for (final q in _subjectiveQuestions) {
      final text = _scoreControllers[q['id']]?.text.trim() ?? '';
      if (text.isNotEmpty) {
        final s = double.tryParse(text);
        if (s == null) {
          _showToast('Please enter a valid number for all scores.',
              isSuccess: false);
          return;
        }
        final maxM = (q['marks'] as num?)?.toDouble() ?? 0.0;
        if (s > maxM) {
          _showToast('Score cannot exceed maximum marks ($maxM).',
              isSuccess: false);
          return;
        }
        if (s < 0) {
          _showToast('Score cannot be negative.', isSuccess: false);
          return;
        }
      }
    }

    // Create new answers map preserving auto scores and inserting subjective scores
    final currentAnswers =
        Map<String, dynamic>.from(sub['answers'] as Map? ?? {});

    for (final q in _subjectiveQuestions) {
      final text = _scoreControllers[q['id']]?.text.trim() ?? '';
      final s = double.tryParse(text);
      final qAnswers = sub['answers']?[q['id']];
      if (s != null) {
        subjTotal += s;
        String? ansText;
        String? fileUrl;
        String? filename;
        if (qAnswers is Map) {
          ansText = qAnswers['text']?.toString();
          fileUrl = qAnswers['file_url']?.toString();
          filename = qAnswers['filename']?.toString();
        } else if (qAnswers is String) {
          ansText = qAnswers;
        }
        currentAnswers[q['id']] = {
          'text': ansText,
          'file_url': fileUrl,
          'filename': filename,
          'awarded_marks': s,
        };
      }
    }

    setState(() => _isSubmitting = true);
    try {
      final totalScore = _currentAutoGradedMarks + subjTotal;
      await _apiService.gradeExamSubmission(
        widget.examId,
        sub['id'],
        score: totalScore,
        remarks: _overallRemarksController.text.trim(),
        answers: currentAnswers,
      );

      if (!mounted) return;
      _showToast('Grade submitted for ${_getStudentName()}', isSuccess: true);
      await _loadData();

      if (!mounted) return;
      final next = _submissions.indexWhere((s) => s['status'] != 'graded');
      if (next != -1) {
        setState(() => _currentStudentIndex = next);
        _initControllersForStudent();
      } else {
        _showAllGradedDialog();
      }
    } catch (e) {
      if (mounted) _showToast('Failed to grade: $e', isSuccess: false);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _gradeAllAuto() async {
    final ungraded =
        _submissions.where((s) => s['status'] != 'graded').toList();
    if (ungraded.isEmpty) {
      _showToast('All submissions are already graded!', isSuccess: true);
      return;
    }

    setState(() => _isAutoGradingBulk = true);
    int successCount = 0;
    try {
      for (final sub in ungraded) {
        final autoScore = _calculateAutoGradedMarks(sub);
        // If there are subjective questions, they get 0 initially in auto mode
        await _apiService.gradeExamSubmission(
          widget.examId,
          sub['id'],
          score: autoScore,
          remarks: 'Auto-graded objective questions.',
        );
        successCount++;
      }
      _showToast('Successfully auto-graded $successCount students!',
          isSuccess: true);
      await _loadData();
    } catch (e) {
      _showToast('Bulk grading partially completed: $e', isSuccess: false);
    } finally {
      if (mounted) setState(() => _isAutoGradingBulk = false);
    }
  }

  void _showAllGradedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _success.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      color: _success, size: 48),
                ),
                const SizedBox(height: 20),
                const Text(
                  'All Students Graded!',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: AppFonts.heading),
                ),
                const SizedBox(height: 8),
                Text(
                  'Graded ${_submissions.length} students. Ready to publish results.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, height: 1.5),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.pushReplacement(
                          '/teacher/exams/publish/${widget.examId}');
                    },
                    icon: const Icon(Icons.publish_rounded),
                    label: const Text('Publish Results'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.go('/teacher/exams');
                  },
                  child: const Text('Back to Exams'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showToast(String msg, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isSuccess ? _success : _danger,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    if (!await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication)) {
      _showToast('Could not open attachment', isSuccess: false);
    }
  }

  List<Map<String, dynamic>> _getFilteredSubmissions() {
    if (_studentSearchQuery.isEmpty) return _submissions;
    return _submissions.where((s) {
      final name = ((s['profiles'] as Map?)?['full_name'] ?? '')
          .toString()
          .toLowerCase();
      final roll = ((s['profiles'] as Map?)?['roll_number'] ?? '')
          .toString()
          .toLowerCase();
      final q = _studentSearchQuery.toLowerCase();
      return name.contains(q) || roll.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1024;
    return Scaffold(
      backgroundColor: _surface,
      body: Column(
        children: [
          _buildTopHeader(),
          if (_isLoading)
            const Expanded(
                child:
                    Center(child: CircularProgressIndicator(color: _primary)))
          else if (_error != null)
            Expanded(child: _buildError())
          else if (_submissions.isEmpty)
            Expanded(child: _buildEmptyState())
          else ...[
            _buildProgressBar(),
            Expanded(
                child:
                    isDesktop ? _buildDesktopLayout() : _buildMobileLayout()),
          ],
        ],
      ),
    );
  }

  Widget _buildTopHeader() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [_primary, Color(0xFF818CF8)]),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 18),
                  onPressed: () => safeGoBack(context, '/teacher/exams'),
                ),
                const SizedBox(width: 4),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Evaluate Exam',
                        style: TextStyle(
                            fontFamily: AppFonts.heading,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white),
                      ),
                      Text(
                        'Subjective Answer Grading',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                if (!_isLoading && _submissions.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      '$_gradedCount/${_submissions.length} Graded',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );

  Widget _buildProgressBar() => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: _border)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Grading Progress',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600)),
                const Spacer(),
                Text(
                  '$_gradedCount of ${_submissions.length} students',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _primary),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _submissions.isNotEmpty
                    ? _gradedCount / _submissions.length
                    : 0.0,
                minHeight: 6,
                backgroundColor: Colors.grey.shade100,
                valueColor: const AlwaysStoppedAnimation<Color>(_success),
              ),
            ),
          ],
        ),
      );

  Widget _buildDesktopLayout() => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sidebar Student List
          SizedBox(
            width: 280,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(right: BorderSide(color: _border)),
              ),
              child: _buildStudentSidebar(),
            ),
          ),
          // Main question content
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildStudentCard(),
                  const SizedBox(height: 16),
                  ..._allQuestions.map(_buildQuestionBlock),
                ],
              ),
            ),
          ),
          // Right hand grading controls
          SizedBox(
            width: 340,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(left: BorderSide(color: _border)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildGradingPanel(),
              ),
            ),
          ),
        ],
      );

  Widget _buildMobileLayout() => Column(
        children: [
          TabBar(
            controller: _tabController,
            indicatorColor: _primary,
            labelColor: _primary,
            unselectedLabelColor: Colors.grey,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [
              Tab(text: 'Students'),
              Tab(text: 'Questions'),
              Tab(text: 'Grade'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildStudentSidebar(),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildStudentCard(),
                      const SizedBox(height: 16),
                      ..._allQuestions.map(_buildQuestionBlock),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildGradingPanel(),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _buildStudentSidebar() {
    final filtered = _getFilteredSubmissions();
    final isDesktop = MediaQuery.of(context).size.width > 1024;
    return Column(
      children: [
        // Sidebar Search
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            onChanged: (val) => setState(() => _studentSearchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search student...',
              hintStyle: const TextStyle(fontSize: 12),
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 18),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          ),
        ),
        // Bulk Action Button (only if not offline exam)
        if (!_isOffline)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isAutoGradingBulk ? null : _gradeAllAuto,
                icon: _isAutoGradingBulk
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _primary))
                    : const Icon(Icons.auto_awesome_rounded, size: 14),
                label:
                    Text(_isAutoGradingBulk ? 'Grading...' : 'Grade All Auto'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  side: const BorderSide(color: _primary),
                  foregroundColor: _primary,
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        const Divider(height: 1, color: _border),
        // Student Tiles List
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: filtered.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: _border),
            itemBuilder: (context, i) {
              final sub = filtered[i];
              final realIndex = _submissions.indexOf(sub);
              final isG = sub['status'] == 'graded';
              final isSel = realIndex == _currentStudentIndex;
              final prof = sub['profiles'] as Map<String, dynamic>? ?? {};
              final name = prof['full_name']?.toString() ?? 'Student';
              final roll = prof['roll_number']?.toString() ?? '';

              return ListTile(
                selected: isSel,
                selectedTileColor: _primary.withValues(alpha: 0.06),
                dense: true,
                onTap: () {
                  setState(() => _currentStudentIndex = realIndex);
                  _initControllersForStudent();
                  if (!isDesktop) {
                    _tabController.animateTo(1);
                  }
                },
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: isG
                      ? _success.withValues(alpha: 0.15)
                      : _primary.withValues(alpha: 0.1),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'S',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isG ? _success : _primary,
                    ),
                  ),
                ),
                title: Text(
                  name,
                  style: TextStyle(
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12.5,
                  ),
                ),
                subtitle:
                    Text('Roll: $roll', style: const TextStyle(fontSize: 10)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isG)
                      Text(
                        '${sub['score']}',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _success),
                      )
                    else
                      const Icon(Icons.pending_actions_rounded,
                          size: 14, color: _warning),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStudentCard() {
    if (_submissions.isEmpty || _currentStudentIndex >= _submissions.length) {
      return const SizedBox();
    }
    final sub = _submissions[_currentStudentIndex];
    final isG = sub['status'] == 'graded';
    final score = sub['score'];
    final subAt = sub['submitted_at'] ?? '';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isG
              ? [const Color(0xFFECFDF5), const Color(0xFFF0FDF4)]
              : [const Color(0xFFF5F3FF), const Color(0xFFEDE9FE)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isG
                ? _success.withValues(alpha: 0.3)
                : _primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: isG
                ? _success.withValues(alpha: 0.15)
                : _primary.withValues(alpha: 0.15),
            child: Text(
              _getStudentName().isNotEmpty
                  ? _getStudentName()[0].toUpperCase()
                  : 'S',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isG ? _success : _primary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_getStudentName(),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text('Roll No: ${_getRollNumber()}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600)),
                    if (isG) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: _success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6)),
                        child: const Text('GRADED',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: _success)),
                      ),
                    ],
                  ],
                ),
                if (subAt.isNotEmpty)
                  Text(
                    'Submitted: ${_formatDate(subAt)}',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
              ],
            ),
          ),
          if (isG && score != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$score',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _success)),
                const Text('Marks',
                    style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildQuestionBlock(Map<String, dynamic> q) {
    if (_submissions.isEmpty || _currentStudentIndex >= _submissions.length) {
      return const SizedBox();
    }
    final answers = _submissions[_currentStudentIndex]['answers']
            as Map<String, dynamic>? ??
        {};
    final qId = q['id'];
    final qType = q['question_type'] as String? ?? 'mcq';
    final isSub = qType == 'subjective';
    final ansVal = answers[qId] ?? answers[qId?.toString()];
    String sText = '';
    String? fUrl;
    String? fName;
    if (ansVal is Map) {
      sText = ansVal['text'] ?? '';
      fUrl = ansVal['file_url'];
      fName = ansVal['filename'];
    } else if (ansVal is String) {
      sText = ansVal;
    }
    final cAns = q['correct_answer']?.toString().trim().toLowerCase();
    final sAns = sText.trim().toLowerCase();
    final isOk = !isSub && cAns != null && cAns.isNotEmpty && sAns == cAns;
    final isErr =
        !isSub && cAns != null && cAns.isNotEmpty && sAns.isNotEmpty && !isOk;
    final bc = isOk
        ? _success.withValues(alpha: 0.4)
        : (isErr ? _danger.withValues(alpha: 0.3) : _border);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bc),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSub
                  ? _warning.withValues(alpha: 0.08)
                  : (isOk
                      ? _success.withValues(alpha: 0.06)
                      : (isErr
                          ? _danger.withValues(alpha: 0.05)
                          : Colors.grey.shade50)),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                _typeChip(qType),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    q['question_text'] ?? '',
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.4),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${q['marks'] ?? 0} M',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _primary)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person_rounded,
                        size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      _isOffline
                          ? 'Question Options & Answer'
                          : 'Student Response',
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600),
                    ),
                    const Spacer(),
                    if (!_isOffline && !isSub && cAns != null) ...[
                      Icon(
                        isOk
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        size: 16,
                        color:
                            isOk ? _success : (isErr ? _danger : Colors.grey),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isOk ? 'Correct' : (isErr ? 'Wrong' : 'No Answer'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color:
                              isOk ? _success : (isErr ? _danger : Colors.grey),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                if (!_isOffline)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      sText.isNotEmpty ? sText : '— No response —',
                      style: TextStyle(
                          fontSize: 12.5,
                          height: 1.5,
                          color:
                              sText.isNotEmpty ? Colors.black87 : Colors.grey),
                    ),
                  ),
                if (q['options'] != null && q['options'] is List) ...[
                  const SizedBox(height: 6),
                  const Text('Options:',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey)),
                  const SizedBox(height: 4),
                  ...(q['options'] as List).map((opt) {
                    final isCorrectOpt = cAns != null &&
                        opt.toString().trim().toLowerCase() == cAns;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isCorrectOpt
                            ? _success.withValues(alpha: 0.08)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isCorrectOpt
                              ? _success.withValues(alpha: 0.3)
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isCorrectOpt
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked,
                            size: 14,
                            color: isCorrectOpt ? _success : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              opt.toString(),
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isCorrectOpt ? _success : Colors.black87,
                                fontWeight: isCorrectOpt
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                if (cAns != null &&
                    cAns.isNotEmpty &&
                    (q['options'] == null || q['options'] is! List)) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1.0),
                        child: Icon(Icons.check_circle_outline_rounded,
                            size: 13, color: _success),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Correct Answer: $cAns',
                          style: const TextStyle(
                              fontSize: 11,
                              color: _success,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
                if (fUrl != null) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => _launchUrl(fUrl!),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade100),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.picture_as_pdf,
                              color: Colors.red, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              fName ?? 'answer_sheet.pdf',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.open_in_new_rounded,
                              color: Colors.red, size: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeChip(String type) {
    final labels = <String, List<dynamic>>{
      'mcq': ['MCQ', const Color(0xFF3B82F6)],
      'subjective': ['SUBJ', _warning],
      'numerical': ['NUM', const Color(0xFF8B5CF6)],
      'fill_in_the_blank': ['FILL', const Color(0xFF06B6D4)],
      'assertion_reason': ['A-R', const Color(0xFFEC4899)],
    };
    final info = labels[type] ?? [type.toUpperCase(), Colors.grey];
    final Color c = info[1] as Color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6)),
      child: Text(info[0] as String,
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: c)),
    );
  }

  Widget _buildGradingPanel() {
    if (_submissions.isEmpty || _currentStudentIndex >= _submissions.length) {
      return const SizedBox();
    }
    final autoM = _currentAutoGradedMarks;
    final totalM = _allQuestions.fold(
        0.0, (sum, q) => sum + ((q['marks'] as num?)?.toDouble() ?? 0.0));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient:
                const LinearGradient(colors: [_primary, Color(0xFF818CF8)]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('GRADING SUMMARY',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Auto-Graded',
                            style:
                                TextStyle(fontSize: 11, color: Colors.white70)),
                        Text('$autoM Marks',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 40, color: Colors.white24),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Available',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.white70)),
                          Text('$totalM Marks',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (_subjectiveQuestions.isNotEmpty) ...[
          Text(
            _isOffline ? 'GRADE QUESTIONS' : 'GRADE SUBJECTIVE QUESTIONS',
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          ..._subjectiveQuestions.map((q) {
            final maxM = (q['marks'] as num?)?.toDouble() ?? 0.0;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (q['question_text']?.toString().length ?? 0) > 60
                        ? '${q['question_text'].toString().substring(0, 60)}...'
                        : q['question_text']?.toString() ?? '',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600, height: 1.3),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _scoreControllers[q['id']]!,
                          builder: (context, value, _) {
                            final text = value.text.trim();
                            String? errorText;
                            if (text.isNotEmpty) {
                              final score = double.tryParse(text);
                              if (score == null) {
                                errorText = 'Invalid number';
                              } else if (score > maxM) {
                                errorText = 'Cannot exceed $maxM';
                              } else if (score < 0) {
                                errorText = 'Cannot be negative';
                              }
                            }
                            return TextField(
                              controller: _scoreControllers[q['id']],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                labelText: 'Score',
                                hintText: '0',
                                errorText: errorText,
                                suffixText: ' / ${maxM.toInt()}',
                                suffixStyle: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey),
                                isDense: true,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                      color: _primary, width: 2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 10),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
        ],
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('FEEDBACK / REMARKS',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey)),
              const SizedBox(height: 10),
              TextField(
                controller: _overallRemarksController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Write feedback for the student...',
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(10),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submitGrade,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(
              _isSubmitting
                  ? 'Submitting...'
                  : (_isCurrentStudentGraded ? 'Update Grade' : 'Submit Grade'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _currentStudentIndex < _submissions.length - 1
                ? () {
                    setState(() => _currentStudentIndex++);
                    _initControllersForStudent();
                  }
                : null,
            icon: const Icon(Icons.skip_next_rounded, size: 16),
            label: const Text('Skip to Next'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: _border),
              foregroundColor: Colors.grey,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: _danger, size: 48),
            const SizedBox(height: 16),
            Text(_error ?? '',
                style: const TextStyle(color: Colors.red, fontSize: 12)),
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

  Widget _buildEmptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle),
              child: const Icon(Icons.assignment_late_outlined,
                  color: _primary, size: 48),
            ),
            const SizedBox(height: 20),
            const Text('No Submissions Found',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('No student submissions ready for evaluation.',
                style: TextStyle(color: Colors.grey.shade500)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go('/teacher/exams'),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Back to Exams'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _primary, foregroundColor: Colors.white),
            ),
          ],
        ),
      );

  String _formatDate(String d) {
    try {
      final dt = DateTime.parse(d).toLocal();
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return d;
    }
  }
}
