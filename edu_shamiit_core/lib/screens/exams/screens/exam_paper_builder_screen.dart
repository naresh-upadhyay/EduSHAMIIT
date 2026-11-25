import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_core/constants/app_fonts.dart';
import 'package:edu_shamiit_core/screens/exams/services/exams_api_service.dart';
import 'package:edu_shamiit_core/screens/exams/services/question_bank_lookup_helper.dart';
import 'package:edu_shamiit_core/models/teacher_models.dart';
import 'package:edu_shamiit_core/screens/exams/utils/exam_nav_helper.dart';
import 'package:edu_shamiit_core/utils/download_helper.dart';
import 'package:edu_shamiit_core/screens/exams/screens/question_bank_screen.dart';

class ExamPaperBuilderScreen extends ConsumerStatefulWidget {
  final String? examId;
  const ExamPaperBuilderScreen({super.key, this.examId});

  @override
  ConsumerState<ExamPaperBuilderScreen> createState() => _ExamPaperBuilderScreenState();
}

class _ExamPaperBuilderScreenState extends ConsumerState<ExamPaperBuilderScreen> {
  final ExamsApiService _apiService = ExamsApiService.instance;
  final QuestionBankLookupHelper _lookupHelper = QuestionBankLookupHelper.instance;

  TeacherExam? _exam;
  List<TeacherExam> _allExams = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  // Paper details
  String _paperType = 'Final Exam';
  String _paperStatus = 'Draft';
  int _totalMarks = 100;
  int _durationMinutes = 120;
  String _instructions = '';

  // Sections & Paper questions
  List<Map<String, dynamic>> _sections = [];
  List<Map<String, dynamic>> _unassignedQuestions = [];

  // Question Bank Picker (Left Panel)
  List<QuestionBankItem> _qbQuestions = [];
  int _qbTotalCount = 0;
  int _qbPage = 1;
  int _qbPageSize = 10;
  bool _qbLoading = false;
  final TextEditingController _searchController = TextEditingController();

  String _selectedType = 'All Types';
  String _selectedDifficulty = 'All Difficulty';
  String _selectedChapter = 'All Chapters';

  // Selected questions in left panel for bulk adding
  final Set<String> _selectedQbIds = {};
  String? _targetSectionId;

  // Lookup data
  List<QuestionBankLookupItem> _paperTypes = [];
  List<QuestionBankLookupItem> _questionTypes = [];
  List<QuestionBankLookupItem> _difficulties = [];
  List<String> _chapters = [];

  // Dynamic Theme Helpers
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bgCol => _isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
  Color get _cardBg => _isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get _innerCardBg => _isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
  Color get _cardBorder => _isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
  Color get _textPrimary => _isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
  Color get _textSecondary => _isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get _inputBg => _isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

  TextStyle _font({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    double? height,
  }) {
    return TextStyle(
      fontFamily: AppFonts.body,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? _textPrimary,
      height: height,
    );
  }

  TextStyle _headingFont({
    double fontSize = 18,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: AppFonts.heading,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? _textPrimary,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadLookups();
    _loadInitialData();
  }

  @override
  void didUpdateWidget(covariant ExamPaperBuilderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.examId != oldWidget.examId) {
      _loadInitialData();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    try {
      final pTypes = await _lookupHelper.getPaperTypes();
      final qTypes = await _lookupHelper.getQuestionTypes();
      final diffs = await _lookupHelper.getDifficulties();
      final chaps = await _apiService.getQuestionBankChapters();

      if (mounted) {
        setState(() {
          _paperTypes = pTypes;
          _questionTypes = qTypes;
          _difficulties = diffs;
          _chapters = chaps;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final exams = await _apiService.getExams();
      exams.sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));

      if (exams.isEmpty) {
        setState(() {
          _allExams = [];
          _isLoading = false;
        });
        return;
      }

      TeacherExam? targetExam;
      if (widget.examId != null && widget.examId!.isNotEmpty) {
        targetExam = exams.firstWhere(
          (e) => e.id == widget.examId,
          orElse: () => exams.first,
        );
      } else {
        // Look for flagship Annual Examination 2025-26 or first exam
        targetExam = exams.firstWhere(
          (e) => e.title.contains('Annual Examination') || e.title.contains('2025-26'),
          orElse: () => exams.first,
        );
      }

      _allExams = exams;
      _exam = targetExam;

      // Initialize paper details
      _paperType = _exam?.examCategory.isNotEmpty == true ? _exam!.examCategory : 'Final Exam';
      _paperStatus = _exam?.status.isNotEmpty == true ? _exam!.status : 'Draft';
      _totalMarks = _exam?.totalMarks ?? 100;
      final parsedDuration = int.tryParse(_exam?.duration.replaceAll(RegExp(r'[^0-9]'), '') ?? '120') ?? 120;
      _durationMinutes = parsedDuration > 0 ? parsedDuration : 120;
      _instructions = _exam?.syllabus ?? '';

      // Load sections & paper questions
      await _loadSectionsData();

      // Load Question Bank picker questions
      await _fetchQbQuestions();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadSectionsData() async {
    if (_exam == null) return;
    try {
      final data = await _apiService.getExamSections(_exam!.id);
      final rawSections = (data['sections'] as List? ?? []);
      final unassigned = (data['unassigned_questions'] as List? ?? []);

      final parsedSections = rawSections.map((s) => Map<String, dynamic>.from(s as Map)).toList();
      final parsedUnassigned = unassigned.map((q) => Map<String, dynamic>.from(q as Map)).toList();

      if (mounted) {
        setState(() {
          _sections = parsedSections;
          _unassignedQuestions = parsedUnassigned;
          if (_targetSectionId == null && _sections.isNotEmpty) {
            _targetSectionId = _sections.first['id']?.toString();
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchQbQuestions() async {
    setState(() {
      _qbLoading = true;
    });

    try {
      String? qType;
      if (_selectedType != 'All Types') {
        final match = _questionTypes.firstWhere(
          (it) => it.name == _selectedType,
          orElse: () => QuestionBankLookupItem(code: _selectedType.toLowerCase(), name: _selectedType),
        );
        qType = match.code.toLowerCase();
      }

      String? diff;
      if (_selectedDifficulty != 'All Difficulty') {
        diff = _selectedDifficulty;
      }

      String? chapter;
      if (_selectedChapter != 'All Chapters') {
        chapter = _selectedChapter;
      }

      final result = await _apiService.getQuestionBankPaged(
        page: _qbPage,
        pageSize: _qbPageSize,
        search: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
        questionType: qType,
        difficulty: diff,
        chapter: chapter,
      );

      final items = (result['questions'] as List<QuestionBankItem>?) ??
          (result['items'] as List<QuestionBankItem>?) ??
          [];
      final total = (result['total_count'] as int?) ??
          (result['total'] as int?) ??
          items.length;

      if (mounted) {
        setState(() {
          _qbQuestions = items;
          _qbTotalCount = total;
          _qbLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _qbLoading = false;
        });
      }
    }
  }

  int get _totalPaperQuestions {
    int count = _unassignedQuestions.length;
    for (final sec in _sections) {
      final qs = (sec['questions'] as List? ?? []);
      count += qs.length;
    }
    return count;
  }

  int get _totalCalculatedMarks {
    int marks = 0;
    for (final q in _unassignedQuestions) {
      marks += int.tryParse(q['marks']?.toString() ?? '1') ?? 1;
    }
    for (final sec in _sections) {
      final qs = (sec['questions'] as List? ?? []);
      for (final q in qs) {
        marks += int.tryParse(q['marks']?.toString() ?? '1') ?? 1;
      }
    }
    return marks;
  }

  bool _isQuestionAlreadyInPaper(String qbId) {
    for (final sec in _sections) {
      final qs = (sec['questions'] as List? ?? []);
      for (final q in qs) {
        if (q['question_bank_id'] == qbId) return true;
      }
    }
    for (final q in _unassignedQuestions) {
      if (q['question_bank_id'] == qbId) return true;
    }
    return false;
  }

  Future<void> _addSingleQuestionToSection(QuestionBankItem q, {String? targetSectionId}) async {
    if (_exam == null) return;

    if (_isQuestionAlreadyInPaper(q.id)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Question is already included in this exam paper'),
            backgroundColor: Color(0xFFF59E0B),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    String? finalSectionId = targetSectionId;
    if (_sections.isEmpty && (finalSectionId == null || finalSectionId.isEmpty)) {
      try {
        final newSec = await _apiService.createExamSection(
          _exam!.id,
          {
            'name': 'Section A',
            'instructions': 'Answer all questions',
            'marks_per_question': q.marks > 0 ? q.marks : 1,
          },
        );
        finalSectionId = newSec['id']?.toString();
      } catch (_) {}
    } else if (finalSectionId == null || finalSectionId.isEmpty) {
      if (_sections.isNotEmpty) {
        finalSectionId = _sections.first['id']?.toString();
      }
    }

    try {
      await _apiService.bulkAddQuestionsFromBank(
        _exam!.id,
        [q.id],
        sectionId: finalSectionId,
        marks: q.marks > 0 ? q.marks : 1,
      );

      await _loadSectionsData();

      if (mounted) {
        final secName = _sections.firstWhere(
          (s) => s['id']?.toString() == finalSectionId,
          orElse: () => {'name': 'Section A'},
        )['name'] ?? 'Section';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Added question to $secName (+${q.marks} Mark${q.marks > 1 ? "s" : ""})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF16A34A),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add question: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _addSelectedQuestionsToPaper() async {
    if (_exam == null || _selectedQbIds.isEmpty) return;

    final targetSec = _sections.firstWhere(
      (s) => s['id'] == _targetSectionId,
      orElse: () => _sections.isNotEmpty ? _sections.first : <String, dynamic>{},
    );

    int? defaultMarks;
    if (targetSec.isNotEmpty && targetSec['marks_per_question'] != null) {
      defaultMarks = (targetSec['marks_per_question'] as num).toInt();
    }

    try {
      await _apiService.bulkAddQuestionsFromBank(
        _exam!.id,
        _selectedQbIds.toList(),
        sectionId: targetSec['id']?.toString(),
        marks: defaultMarks,
      );

      setState(() {
        _selectedQbIds.clear();
      });

      await _loadSectionsData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Questions successfully added to exam paper'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add questions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeQuestionFromExam(String questionId) async {
    if (_exam == null) return;
    try {
      await _apiService.deleteExamQuestion(_exam!.id, questionId);
      await _loadSectionsData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Question removed from paper'),
            backgroundColor: Color(0xFF475569),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove question: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _savePaperConfiguration() async {
    if (_exam == null) return;
    setState(() {
      _isSaving = true;
    });

    try {
      await _apiService.savePaperConfiguration(_exam!.id, {
        'title': _exam!.title,
        'paper_type': _paperType,
        'paper_status': _paperStatus,
        'total_marks': _totalMarks,
        'duration_minutes': _durationMinutes,
        'instructions': _instructions,
      });

      setState(() {
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Question paper configuration saved successfully!'),
            backgroundColor: Color(0xFF2563EB),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save paper: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ==========================================================================
  // BUILD METHOD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _bgCol,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFF2563EB)),
              const SizedBox(height: 16),
              Text(
                'Loading Question Paper Builder...',
                style: _font(fontSize: 14, color: _textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null || _exam == null) {
      return Scaffold(
        backgroundColor: _bgCol,
        appBar: AppBar(
          title: Text('Build Question Paper', style: _headingFont(color: Colors.white, fontSize: 16)),
          backgroundColor: const Color(0xFF2563EB),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => safeGoBack(context, getExamsBaseRoute(context)),
          ),
        ),
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _cardBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'No examinations found.',
                  style: _font(fontSize: 14, fontWeight: FontWeight.bold, color: _textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _loadInitialData,
                  icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
                  label: const Text('Try Again', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1100;

    return Scaffold(
      backgroundColor: _bgCol,
      body: SafeArea(
        child: Column(
          children: [
            // Top Scrollable Container
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // A. Page Header
                    _buildPageHeader(),
                    const SizedBox(height: 16),

                    // B. Exam Info Summary Cards (Row of 6)
                    _buildExamInfoCards(screenWidth),
                    const SizedBox(height: 20),

                    // C. Main Workspace: 2-Panel Split
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Panel (approx 36%): Question Bank Picker
                          SizedBox(
                            width: 380,
                            child: _buildQuestionBankPickerPanel(),
                          ),
                          const SizedBox(width: 20),
                          // Right Panel: Question Paper Builder
                          Expanded(
                            child: _buildQuestionPaperBuilderPanel(),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildQuestionPaperBuilderPanel(),
                          const SizedBox(height: 20),
                          _buildQuestionBankPickerPanel(),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            // D. Sticky Bottom Summary Bar
            _buildStickyBottomBar(),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // SECTION A: PAGE HEADER
  // ==========================================================================

  Widget _buildPageHeader() {
    return Row(
      children: [
        // Left Badge Icon
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.assignment_outlined, color: Colors.white, size: 24),
          ),
        ),
        const SizedBox(width: 14),
        // Title & Subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Build Question Paper',
                style: _headingFont(fontSize: 20, fontWeight: FontWeight.w800, color: _textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                'Create question paper for examination',
                style: _font(fontSize: 13, color: _textSecondary),
              ),
            ],
          ),
        ),
        // Right Action Buttons
        OutlinedButton.icon(
          onPressed: () => safeGoBack(context, getExamsBaseRoute(context)),
          icon: Icon(Icons.arrow_back, size: 16, color: _textPrimary),
          label: Text('Back to Exams', style: _font(fontWeight: FontWeight.w600, color: _textPrimary)),
          style: OutlinedButton.styleFrom(
            backgroundColor: _cardBg,
            side: BorderSide(color: _cardBorder),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _savePaperConfiguration,
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.save_outlined, size: 16, color: Colors.white),
          label: Text(
            _isSaving ? 'Saving...' : 'Save Paper',
            style: _font(fontWeight: FontWeight.w600, color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // SECTION B: 6 KPI / METADATA SUMMARY CARDS
  // ==========================================================================

  Widget _buildExamInfoCards(double screenWidth) {
    final examDateStr = _exam?.examDate != null ? '(${_formatDate(_exam!.examDate)})' : '(Mar 15, 2026)';
    final className = _exam?.class_.isNotEmpty == true ? _exam!.class_ : 'Class 10';
    final subjectName = _exam?.subject.isNotEmpty == true ? _exam!.subject : 'Mathematics';

    final cards = [
      // 1. Exam
      _buildSingleInfoCard(
        label: 'Exam',
        value: _exam?.title ?? 'Annual Examination 2025-26',
        subValue: examDateStr,
        icon: Icons.calendar_today_outlined,
        iconColor: const Color(0xFF9333EA),
        iconBgColor: const Color(0xFFF3E8FF),
        onTap: _showExamSwitcherDialog,
      ),
      // 2. Class
      _buildSingleInfoCard(
        label: 'Class',
        value: className,
        icon: Icons.people_alt_outlined,
        iconColor: const Color(0xFF2563EB),
        iconBgColor: const Color(0xFFEFF6FF),
      ),
      // 3. Subject
      _buildSingleInfoCard(
        label: 'Subject',
        value: subjectName,
        icon: Icons.menu_book_outlined,
        iconColor: const Color(0xFF2563EB),
        iconBgColor: const Color(0xFFEFF6FF),
      ),
      // 4. Paper Type
      _buildSingleInfoCard(
        label: 'Paper Type',
        value: _paperType,
        icon: Icons.article_outlined,
        iconColor: const Color(0xFF16A34A),
        iconBgColor: const Color(0xFFDCFCE7),
        onTap: _showEditPaperTypeDialog,
      ),
      // 5. Total Marks
      _buildSingleInfoCard(
        label: 'Total Marks',
        value: '$_totalMarks',
        icon: Icons.star_rounded,
        iconColor: const Color(0xFFD97706),
        iconBgColor: const Color(0xFFFEF3C7),
        onTap: _showEditMarksAndDurationDialog,
      ),
      // 6. Duration
      _buildSingleInfoCard(
        label: 'Duration',
        value: '${(_durationMinutes / 60).toStringAsFixed(0)} Hours',
        icon: Icons.schedule_outlined,
        iconColor: const Color(0xFF0284C7),
        iconBgColor: const Color(0xFFE0F2FE),
        onTap: _showEditMarksAndDurationDialog,
      ),
    ];

    if (screenWidth >= 1200) {
      return Row(
        children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: c))).toList(),
      );
    } else {
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: cards.map((c) => SizedBox(width: (screenWidth - 60) / (screenWidth >= 600 ? 3 : 2), child: c)).toList(),
      );
    }
  }

  Widget _buildSingleInfoCard({
    required String label,
    required String value,
    String? subValue,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _isDark ? iconColor.withValues(alpha: 0.18) : iconBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(icon, color: iconColor, size: 20),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: _font(fontSize: 11, color: _textSecondary, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: _font(fontSize: 13, fontWeight: FontWeight.w700, color: _textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subValue != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      subValue,
                      style: _font(fontSize: 11, color: _textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.arrow_drop_down, color: _textSecondary, size: 18),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  // ==========================================================================
  // SECTION C.1: LEFT PANEL - QUESTION BANK PICKER
  // ==========================================================================

  Widget _buildQuestionBankPickerPanel() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                'Question Bank',
                style: _headingFont(fontSize: 16, fontWeight: FontWeight.w700, color: _textPrimary),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$_qbTotalCount Available',
                  style: _font(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Color(0xFF2563EB), size: 20),
                tooltip: 'Add New Question to Bank',
                onPressed: _showCreateQuestionInlineDialog,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.touch_app_outlined, size: 13, color: _textSecondary),
              const SizedBox(width: 4),
              Text(
                'Drag questions into sections or click "+ Add"',
                style: _font(fontSize: 11, color: _textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Search Row
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (_) {
                      setState(() => _qbPage = 1);
                      _fetchQbQuestions();
                    },
                    style: TextStyle(fontSize: 12.5, color: _textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search questions...',
                      hintStyle: _font(fontSize: 12, color: _textSecondary),
                      prefixIcon: Icon(Icons.search, size: 18, color: _textSecondary),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      filled: true,
                      fillColor: _inputBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: _cardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: _cardBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF2563EB)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _qbPage = 1);
                  _fetchQbQuestions();
                },
                icon: const Icon(Icons.search, size: 15, color: Colors.white),
                label: Text('Search', style: _font(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Filters Row (All Types, All Difficulty, All Chapters)
          Row(
            children: [
              // All Types Dropdown
              Expanded(
                child: _buildSmallFilterDropdown(
                  value: _selectedType,
                  items: [
                    'All Types',
                    ...(_questionTypes.isNotEmpty
                        ? _questionTypes.map((t) => t.name)
                        : ['MCQ', 'Short Answer', 'Long Answer'])
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedType = val!;
                      _qbPage = 1;
                    });
                    _fetchQbQuestions();
                  },
                ),
              ),
              const SizedBox(width: 6),
              // All Difficulty Dropdown
              Expanded(
                child: _buildSmallFilterDropdown(
                  value: _selectedDifficulty,
                  items: [
                    'All Difficulty',
                    ...(_difficulties.isNotEmpty
                        ? _difficulties.map((d) => d.name)
                        : ['Easy', 'Medium', 'Hard'])
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedDifficulty = val!;
                      _qbPage = 1;
                    });
                    _fetchQbQuestions();
                  },
                ),
              ),
              const SizedBox(width: 6),
              // All Chapters Dropdown
              Expanded(
                child: _buildSmallFilterDropdown(
                  value: _selectedChapter,
                  items: ['All Chapters', ..._chapters],
                  onChanged: (val) {
                    setState(() {
                      _selectedChapter = val!;
                      _qbPage = 1;
                    });
                    _fetchQbQuestions();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Floating / Persistent Add To Section Bar (when questions selected)
          if (_selectedQbIds.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: _isDark ? 0.2 : 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Text(
                    '${_selectedQbIds.length} Selected',
                    style: _font(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF3B82F6)),
                  ),
                  const Spacer(),
                  if (_sections.isNotEmpty) ...[
                    AppSearchableDropdown<String>.fromMenuItems(
                      value: _targetSectionId ?? _sections.first['id'],
                      dropdownColor: _cardBg,
                      underline: const SizedBox(),
                      isDense: true,
                      style: _font(fontSize: 11, fontWeight: FontWeight.bold, color: _textPrimary),
                      items: _sections.map((s) {
                        final code = s['section_code'] ?? 'A';
                        return DropdownMenuItem<String>(
                          value: s['id']?.toString(),
                          child: Text('Section $code', style: TextStyle(color: _textPrimary)),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _targetSectionId = v),
                    ),
                    const SizedBox(width: 8),
                  ],
                  ElevatedButton(
                    onPressed: _addSelectedQuestionsToPaper,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: Text('+ Add', style: _font(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Question Items List
          if (_qbLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB))),
            )
          else if (_qbQuestions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.quiz_outlined, size: 36, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text('No matching questions found', style: _font(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _qbQuestions.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: _cardBorder),
              itemBuilder: (ctx, idx) {
                final q = _qbQuestions[idx];
                final isSelected = _selectedQbIds.contains(q.id);
                final isAlreadyInPaper = _isQuestionAlreadyInPaper(q.id);

                return _buildQbQuestionItemCard(q, isSelected, isAlreadyInPaper);
              },
            ),

          const SizedBox(height: 12),

          // Bottom Pagination Bar inside Left Card
          _buildQbPaginationBar(),
        ],
      ),
    );
  }

  Widget _buildSmallFilterDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final sanitizedValue = items.contains(value) ? value : (items.isNotEmpty ? items.first : 'All');

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: _inputBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _cardBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: AppSearchableDropdown<String>.fromMenuItems(
          value: sanitizedValue,
          dropdownColor: _cardBg,
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, size: 16, color: _textSecondary),
          style: _font(fontSize: 11, fontWeight: FontWeight.w500, color: _textPrimary),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item, maxLines: 1, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildQbQuestionItemCard(QuestionBankItem q, bool isSelected, bool isAlreadyInPaper) {
    Color typeBg = _isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF);
    Color typeColor = const Color(0xFF3B82F6);
    String typeLabel = 'MCQ';

    final t = q.questionType.toLowerCase();
    if (t.contains('short')) {
      typeBg = _isDark ? const Color(0xFF78350F).withValues(alpha: 0.3) : const Color(0xFFFEF3C7);
      typeColor = const Color(0xFFF59E0B);
      typeLabel = 'Short';
    } else if (t.contains('long')) {
      typeBg = _isDark ? const Color(0xFF581C87).withValues(alpha: 0.3) : const Color(0xFFF3E8FF);
      typeColor = const Color(0xFFA855F7);
      typeLabel = 'Long';
    }

    final marksStr = '${q.marks} Mark${q.marks > 1 ? 's' : ''}';

    final cardContent = Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? (_isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.2) : const Color(0xFFEFF6FF))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag indicator icon for unadded questions
          if (!isAlreadyInPaper)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Tooltip(
                message: 'Drag and drop into any section on the right',
                child: Icon(Icons.drag_indicator, size: 16, color: _textSecondary.withValues(alpha: 0.5)),
              ),
            ),

          // Checkbox
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: isSelected || isAlreadyInPaper,
              onChanged: isAlreadyInPaper
                  ? null
                  : (val) {
                      setState(() {
                        if (val == true) {
                          _selectedQbIds.add(q.id);
                        } else {
                          _selectedQbIds.remove(q.id);
                        }
                      });
                    },
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              activeColor: isAlreadyInPaper ? Colors.grey : const Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 6),

          // Question Type Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: typeBg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              typeLabel,
              style: _font(fontSize: 10, fontWeight: FontWeight.bold, color: typeColor),
            ),
          ),
          const SizedBox(width: 8),

          // Question Text Snippet
          Expanded(
            child: Tooltip(
              message: q.questionText,
              waitDuration: const Duration(milliseconds: 400),
              child: Text(
                q.questionText,
                style: _font(
                  fontSize: 12,
                  color: isAlreadyInPaper ? _textSecondary.withValues(alpha: 0.6) : _textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Marks Badge / Added Status / Quick Add
          if (isAlreadyInPaper)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _innerCardBg,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _cardBorder),
              ),
              child: Text(
                'Added',
                style: _font(fontSize: 10, color: _textSecondary, fontWeight: FontWeight.w600),
              ),
            )
          else ...[
            Text(
              marksStr,
              style: _font(fontSize: 11, fontWeight: FontWeight.w600, color: _textSecondary),
            ),
            const SizedBox(width: 6),
            // Quick Add Button
            InkWell(
              onTap: () => _addSingleQuestionToSection(q, targetSectionId: _targetSectionId),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, size: 12, color: Color(0xFF2563EB)),
                    const SizedBox(width: 2),
                    Text(
                      'Add',
                      style: _font(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (isAlreadyInPaper) {
      return cardContent;
    }

    return Draggable<QuestionBankItem>(
      data: q,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        color: Colors.transparent,
        child: Container(
          width: 320,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2563EB), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: typeBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  typeLabel,
                  style: _font(fontSize: 10, fontWeight: FontWeight.bold, color: typeColor),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  q.questionText,
                  style: _font(fontSize: 12, fontWeight: FontWeight.w600, color: _textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  marksStr,
                  style: _font(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: cardContent,
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: cardContent,
      ),
    );
  }

  Widget _buildQbPaginationBar() {
    final startIdx = _qbTotalCount == 0 ? 0 : ((_qbPage - 1) * _qbPageSize) + 1;
    final endIdx = ((_qbPage * _qbPageSize) > _qbTotalCount) ? _qbTotalCount : (_qbPage * _qbPageSize);
    final totalPages = (_qbTotalCount / _qbPageSize).ceil().clamp(1, 9999);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Showing $startIdx - $endIdx of $_qbTotalCount',
                style: _font(fontSize: 11, color: _textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Rows per page selector
            Text(
              'Per page:',
              style: _font(fontSize: 10, color: _textSecondary),
            ),
            const SizedBox(width: 4),
            Container(
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: _innerCardBg,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _cardBorder),
              ),
              child: DropdownButtonHideUnderline(
                child: AppSearchableDropdown<int>.fromMenuItems(
                  value: _qbPageSize,
                  dropdownColor: _isDark ? const Color(0xFF1E293B) : Colors.white,
                  style: _font(fontSize: 11, fontWeight: FontWeight.bold, color: _textPrimary),
                  icon: Icon(Icons.arrow_drop_down, size: 14, color: _textSecondary),
                  items: [10, 25, 50, 100].map((s) {
                    return DropdownMenuItem(
                      value: s,
                      child: Text('$s', style: TextStyle(color: _textPrimary, fontSize: 11)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _qbPageSize = val;
                        _qbPage = 1;
                      });
                      _fetchQbQuestions();
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // First page
            IconButton(
              icon: Icon(Icons.first_page, size: 16, color: _qbPage > 1 ? _textSecondary : _textSecondary.withValues(alpha: 0.3)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'First Page',
              onPressed: _qbPage > 1
                  ? () {
                      setState(() => _qbPage = 1);
                      _fetchQbQuestions();
                    }
                  : null,
            ),
            const SizedBox(width: 6),
            // Previous
            IconButton(
              icon: Icon(Icons.chevron_left, size: 16, color: _qbPage > 1 ? _textSecondary : _textSecondary.withValues(alpha: 0.3)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Previous Page',
              onPressed: _qbPage > 1
                  ? () {
                      setState(() => _qbPage--);
                      _fetchQbQuestions();
                    }
                  : null,
            ),
            const SizedBox(width: 8),

            // Numbered pages (up to 5 buttons centered on current page)
            Builder(
              builder: (context) {
                final startP = (_qbPage - 2).clamp(1, totalPages);
                final endP = (_qbPage + 2).clamp(1, totalPages);
                final buttons = <Widget>[];

                for (int p = startP; p <= endP; p++) {
                  final isCurrent = p == _qbPage;
                  buttons.add(
                    InkWell(
                      onTap: () {
                        setState(() => _qbPage = p);
                        _fetchQbQuestions();
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: isCurrent ? const Color(0xFF2563EB) : _innerCardBg,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isCurrent ? const Color(0xFF2563EB) : _cardBorder,
                          ),
                        ),
                        child: Text(
                          '$p',
                          style: _font(
                            fontSize: 11,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                            color: isCurrent ? Colors.white : _textPrimary,
                          ),
                        ),
                      ),
                    ),
                  );
                }
                return Row(mainAxisSize: MainAxisSize.min, children: buttons);
              },
            ),

            const SizedBox(width: 8),
            // Next
            IconButton(
              icon: Icon(Icons.chevron_right, size: 16, color: _qbPage < totalPages ? _textSecondary : _textSecondary.withValues(alpha: 0.3)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Next Page',
              onPressed: _qbPage < totalPages
                  ? () {
                      setState(() => _qbPage++);
                      _fetchQbQuestions();
                    }
                  : null,
            ),
            const SizedBox(width: 6),
            // Last page
            IconButton(
              icon: Icon(Icons.last_page, size: 16, color: _qbPage < totalPages ? _textSecondary : _textSecondary.withValues(alpha: 0.3)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Last Page',
              onPressed: _qbPage < totalPages
                  ? () {
                      setState(() => _qbPage = totalPages);
                      _fetchQbQuestions();
                    }
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================================================
  // SECTION C.2: RIGHT PANEL - QUESTION PAPER BUILDER
  // ==========================================================================

  Widget _buildQuestionPaperBuilderPanel() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with title and right actions
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.description, color: Color(0xFF2563EB), size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                'Question Paper Builder',
                style: _headingFont(fontSize: 16, fontWeight: FontWeight.w700, color: _textPrimary),
              ),
              const Spacer(),

              // Action: Randomize Questions
              OutlinedButton.icon(
                onPressed: _showRandomizeDialog,
                icon: const Icon(Icons.shuffle, size: 14, color: Color(0xFF2563EB)),
                label: Text('Randomize Questions', style: _font(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF2563EB))),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: const Color(0xFF2563EB).withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
              const SizedBox(width: 8),

              // Action: Clear All
              OutlinedButton.icon(
                onPressed: _showClearAllDialog,
                icon: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFDC2626)),
                label: Text('Clear All', style: _font(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFDC2626))),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: const Color(0xFFDC2626).withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
              const SizedBox(width: 8),

              // Action: Preview
              OutlinedButton.icon(
                onPressed: _showPaperPreviewDialog,
                icon: const Icon(Icons.visibility_outlined, size: 14, color: Color(0xFF2563EB)),
                label: Text('Preview', style: _font(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF2563EB))),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: const Color(0xFF2563EB).withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
              const SizedBox(width: 8),

              // Action: Add Section
              IconButton(
                icon: const Icon(Icons.add_box_outlined, color: Color(0xFF2563EB), size: 22),
                tooltip: 'Add Section',
                onPressed: () => _showEditSectionDialog(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Render Sections List
          if (_sections.isEmpty && _unassignedQuestions.isEmpty)
            DragTarget<QuestionBankItem>(
              onWillAcceptWithDetails: (details) => true,
              onAcceptWithDetails: (details) {
                _addSingleQuestionToSection(details.data);
              },
              builder: (context, candidateData, rejectedData) {
                final isHovered = candidateData.isNotEmpty;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(40),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isHovered
                        ? (_isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.25) : const Color(0xFFEFF6FF))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isHovered ? const Color(0xFF2563EB) : _cardBorder.withValues(alpha: 0.6),
                      width: isHovered ? 2.0 : 1.0,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        isHovered ? Icons.add_circle : Icons.layers_outlined,
                        size: 48,
                        color: isHovered ? const Color(0xFF2563EB) : _textSecondary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isHovered ? 'Drop question here to auto-create Section A' : 'No sections configured in this paper yet.',
                        style: _font(fontWeight: FontWeight.bold, color: isHovered ? const Color(0xFF2563EB) : _textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Drag questions from the left Question Bank or click below',
                        style: _font(fontSize: 12, color: _textSecondary),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => _showEditSectionDialog(),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Create First Section'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                      ),
                    ],
                  ),
                );
              },
            )
          else ...[
            for (int sIdx = 0; sIdx < _sections.length; sIdx++) ...[
              _buildSectionCard(_sections[sIdx], sIdx),
              const SizedBox(height: 16),
            ],
            // Unassigned questions if any
            if (_unassignedQuestions.isNotEmpty) ...[
              _buildUnassignedQuestionsCard(),
              const SizedBox(height: 16),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSectionCard(Map<String, dynamic> section, int sectionIndex) {
    final questions = (section['questions'] as List? ?? []).map((q) => Map<String, dynamic>.from(q as Map)).toList();
    final sectionName = section['name']?.toString() ?? 'Section ${sectionIndex + 1}';
    final qCount = questions.length;

    return DragTarget<QuestionBankItem>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        _addSingleQuestionToSection(details.data, targetSectionId: section['id']?.toString());
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isHovered
                ? (_isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.25) : const Color(0xFFEFF6FF))
                : _innerCardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isHovered ? const Color(0xFF2563EB) : _cardBorder,
              width: isHovered ? 2.0 : 1.0,
            ),
            boxShadow: isHovered
                ? [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isHovered
                      ? const Color(0xFF2563EB).withValues(alpha: 0.15)
                      : (_isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(9),
                    topRight: Radius.circular(9),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              sectionName,
                              style: _font(fontSize: 13, fontWeight: FontWeight.w700, color: _textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '($qCount Question${qCount == 1 ? '' : 's'})',
                            style: _font(fontSize: 12, color: _textSecondary, fontWeight: FontWeight.w500),
                          ),
                          if (isHovered) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Drop to add here',
                                style: _font(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Section action buttons: Move up, Move down, Edit, Delete
                    IconButton(
                      icon: Icon(Icons.arrow_upward, size: 16, color: _textSecondary),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Move Section Up',
                      onPressed: sectionIndex > 0 ? () => _moveSection(sectionIndex, sectionIndex - 1) : null,
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.arrow_downward, size: 16, color: _textSecondary),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Move Section Down',
                      onPressed: sectionIndex < _sections.length - 1 ? () => _moveSection(sectionIndex, sectionIndex + 1) : null,
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF2563EB)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Edit Section',
                      onPressed: () => _showEditSectionDialog(section),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFDC2626)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Delete Section',
                      onPressed: () => _confirmDeleteSection(section['id']?.toString() ?? ''),
                    ),
                  ],
                ),
              ),

              // Questions List in this Section
              if (questions.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.touch_app_outlined, size: 16, color: _textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          'Drag questions from the left Question Bank or click "+ Add"',
                          style: _font(fontSize: 12, color: _textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: questions.length,
                  onReorderItem: (oldIndex, newIndex) => _reorderQuestionWithinSection(section, oldIndex, newIndex),
                  itemBuilder: (ctx, qIdx) {
                    final q = questions[qIdx];
                    return _buildQuestionItemRow(q, qIdx + 1, section, key: ValueKey(q['id'] ?? '$sectionIndex-$qIdx'));
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuestionItemRow(
    Map<String, dynamic> q,
    int number,
    Map<String, dynamic> section, {
    required Key key,
  }) {
    final marks = q['marks']?.toString() ?? '1';
    final marksLabel = '$marks Mark${marks == '1' ? '' : 's'}';

    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border(
          bottom: BorderSide(color: _cardBorder),
        ),
      ),
      child: Row(
        children: [
          // Drag handle
          ReorderableDragStartListener(
            index: number - 1,
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: Icon(Icons.drag_indicator, size: 18, color: _textSecondary),
            ),
          ),
          const SizedBox(width: 8),

          // Question Number
          SizedBox(
            width: 22,
            child: Text(
              '$number.',
              style: _font(fontSize: 13, fontWeight: FontWeight.w700, color: _textSecondary),
            ),
          ),
          const SizedBox(width: 8),

          // Question Text
          Expanded(
            child: Text(
              q['question_text']?.toString() ?? '',
              style: _font(fontSize: 13, fontWeight: FontWeight.w500, color: _textPrimary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),

          // Marks Pill
          InkWell(
            onTap: () => _showEditQuestionMarksDialog(q),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: _isDark ? 0.2 : 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
              ),
              child: Text(
                marksLabel,
                style: _font(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF3B82F6)),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Green checkmark status icon
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 13, color: Color(0xFF16A34A)),
          ),
          const SizedBox(width: 8),

          // Delete/Remove Question
          IconButton(
            icon: Icon(Icons.close, size: 16, color: _textSecondary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Remove from Paper',
            onPressed: () => _removeQuestionFromExam(q['id']?.toString() ?? ''),
          ),
        ],
      ),
    );
  }

  Widget _buildUnassignedQuestionsCard() {
    return DragTarget<QuestionBankItem>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        _addSingleQuestionToSection(details.data, targetSectionId: null);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isHovered
                ? (_isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.25) : const Color(0xFFEFF6FF))
                : _innerCardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isHovered ? const Color(0xFF2563EB) : _cardBorder,
              width: isHovered ? 2.0 : 1.0,
            ),
            boxShadow: isHovered
                ? [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isHovered
                      ? const Color(0xFF2563EB).withValues(alpha: 0.15)
                      : (_isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(9),
                    topRight: Radius.circular(9),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'General Questions (Unassigned)',
                      style: _font(fontSize: 13, fontWeight: FontWeight.w700, color: _textPrimary),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${_unassignedQuestions.length} Questions)',
                      style: _font(fontSize: 12, color: _textSecondary),
                    ),
                    if (isHovered) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Drop here as unassigned',
                          style: _font(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              for (int idx = 0; idx < _unassignedQuestions.length; idx++) ...[
                _buildQuestionItemRow(
                  _unassignedQuestions[idx],
                  idx + 1,
                  {},
                  key: ValueKey('unassigned-$idx'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _moveSection(int fromIdx, int toIdx) async {
    if (_exam == null) return;
    final item = _sections.removeAt(fromIdx);
    _sections.insert(toIdx, item);
    setState(() {});

    final sectionIds = _sections.map((s) => s['id']?.toString() ?? '').toList();
    try {
      await _apiService.reorderExamSections(_exam!.id, sectionIds);
    } catch (_) {}
  }

  Future<void> _reorderQuestionWithinSection(Map<String, dynamic> section, int oldIndex, int newIndex) async {
    if (_exam == null) return;
    final qs = (section['questions'] as List? ?? []);
    final item = qs.removeAt(oldIndex);
    qs.insert(newIndex, item);
    setState(() {});

    final List<Map<String, dynamic>> updateItems = [];
    for (int i = 0; i < qs.length; i++) {
      updateItems.add({
        'id': qs[i]['id'],
        'section_id': section['id'],
        'order_number': i + 1,
      });
    }

    try {
      await _apiService.reorderExamQuestions(_exam!.id, updateItems);
    } catch (_) {}
  }

  // ==========================================================================
  // SECTION D: STICKY BOTTOM SUMMARY BAR
  // ==========================================================================

  Widget _buildStickyBottomBar() {
    final bool marksMatched = _totalCalculatedMarks == _totalMarks;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border(
          top: BorderSide(color: _cardBorder),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left metrics
          Row(
            children: [
              // Total Questions
              const Icon(Icons.bar_chart, size: 18, color: Color(0xFF2563EB)),
              const SizedBox(width: 6),
              Text(
                'Total Questions: ',
                style: _font(fontSize: 13, color: _textSecondary),
              ),
              Text(
                '$_totalPaperQuestions',
                style: _font(fontSize: 13, fontWeight: FontWeight.bold, color: _textPrimary),
              ),
              const SizedBox(width: 24),

              // Total Marks
              Icon(
                Icons.emoji_events_outlined,
                size: 18,
                color: marksMatched ? const Color(0xFF9333EA) : Colors.orange,
              ),
              const SizedBox(width: 6),
              Text(
                'Total Marks: ',
                style: _font(fontSize: 13, color: _textSecondary),
              ),
              Text(
                '$_totalCalculatedMarks',
                style: _font(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: marksMatched ? _textPrimary : Colors.orange.shade700,
                ),
              ),
              if (!marksMatched) ...[
                const SizedBox(width: 4),
                Text(
                  ' (Target: $_totalMarks)',
                  style: _font(fontSize: 11, color: Colors.orange.shade700),
                ),
              ],
              const SizedBox(width: 24),

              // Duration
              const Icon(Icons.schedule, size: 18, color: Color(0xFF0284C7)),
              const SizedBox(width: 6),
              Text(
                'Duration: ',
                style: _font(fontSize: 13, color: _textSecondary),
              ),
              Text(
                '${(_durationMinutes / 60).toStringAsFixed(0)} Hours',
                style: _font(fontSize: 13, fontWeight: FontWeight.bold, color: _textPrimary),
              ),
            ],
          ),

          const Spacer(),

          // Right buttons: Preview Paper & Save & Continue
          OutlinedButton.icon(
            onPressed: _showPaperPreviewDialog,
            icon: const Icon(Icons.visibility_outlined, size: 16, color: Color(0xFF2563EB)),
            label: Text('Preview Paper', style: _font(fontWeight: FontWeight.w600, color: const Color(0xFF2563EB))),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
              backgroundColor: _innerCardBg,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 12),

          ElevatedButton.icon(
            onPressed: _savePaperConfiguration,
            icon: const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
            label: Text('Save & Continue →', style: _font(fontWeight: FontWeight.bold, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // SECTION E: PREMIUM DIALOGS & POPUPS
  // ==========================================================================

  /// 1. PAPER PREVIEW DIALOG (Student Copy & Teacher Marking Scheme)
  Future<void> _showPaperPreviewDialog() async {
    if (_exam == null) return;

    showDialog(
      context: context,
      builder: (ctx) => _PaperPreviewModal(
        examId: _exam!.id,
        apiService: _apiService,
      ),
    );
  }

  /// 2. EDIT / ADD SECTION DIALOG
  Future<void> _showEditSectionDialog([Map<String, dynamic>? section]) async {
    if (_exam == null) return;
    final isEditing = section != null;

    final nameController = TextEditingController(text: section?['name']?.toString() ?? 'Section ${chr(65 + _sections.length)} – Short Answer Questions (2 Marks Each)');
    final codeController = TextEditingController(text: section?['section_code']?.toString() ?? chr(65 + _sections.length));
    final marksController = TextEditingController(text: section?['marks_per_question']?.toString() ?? '2');
    final instructionsController = TextEditingController(text: section?['instructions']?.toString() ?? 'Answer all questions with proper steps.');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: _cardBorder)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFF2563EB).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.view_agenda_outlined, color: Color(0xFF3B82F6), size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              isEditing ? 'Edit Section' : 'Add New Section',
              style: _headingFont(fontSize: 16, color: _textPrimary),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Section Name', style: _font(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary)),
              const SizedBox(height: 6),
              TextField(
                controller: nameController,
                style: TextStyle(color: _textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'e.g. Section D – Assertion and Reason',
                  hintStyle: _font(fontSize: 12, color: _textSecondary),
                  filled: true,
                  fillColor: _inputBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _cardBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _cardBorder)),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Section Code', style: _font(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: codeController,
                          style: TextStyle(color: _textPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'e.g. D',
                            hintStyle: _font(fontSize: 12, color: _textSecondary),
                            filled: true,
                            fillColor: _inputBg,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _cardBorder)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _cardBorder)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Marks per Question', style: _font(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: marksController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: _textPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'e.g. 2',
                            hintStyle: _font(fontSize: 12, color: _textSecondary),
                            filled: true,
                            fillColor: _inputBg,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _cardBorder)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _cardBorder)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text('Section Instructions', style: _font(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary)),
              const SizedBox(height: 6),
              TextField(
                controller: instructionsController,
                maxLines: 2,
                style: TextStyle(color: _textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'e.g. All questions are compulsory...',
                  hintStyle: _font(fontSize: 12, color: _textSecondary),
                  filled: true,
                  fillColor: _inputBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _cardBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _cardBorder)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: _font(color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final payload = {
                'name': nameController.text.trim(),
                'section_code': codeController.text.trim(),
                'marks_per_question': double.tryParse(marksController.text.trim()) ?? 1.0,
                'instructions': instructionsController.text.trim(),
              };

              try {
                if (isEditing) {
                  await _apiService.updateExamSection(_exam!.id, section['id'], payload);
                } else {
                  await _apiService.createExamSection(_exam!.id, payload);
                }
                await _loadSectionsData();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to save section: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(isEditing ? 'Update Section' : 'Create Section', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String chr(int asciiCode) {
    return String.fromCharCode(asciiCode);
  }

  Future<void> _confirmDeleteSection(String sectionId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: _cardBorder)),
        title: Text('Delete Section', style: _headingFont(fontSize: 16, color: _textPrimary)),
        content: Text('Are you sure you want to delete this section? Its questions will be moved to unassigned.', style: _font(color: _textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: _font(color: _textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && _exam != null) {
      try {
        await _apiService.deleteExamSection(_exam!.id, sectionId);
        await _loadSectionsData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete section: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  /// 3. RANDOMIZE QUESTIONS DIALOG
  Future<void> _showRandomizeDialog() async {
    if (_exam == null) return;
    bool shuffleOptions = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _cardBg,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: _cardBorder)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF2563EB).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.shuffle, color: Color(0xFF3B82F6), size: 20),
              ),
              const SizedBox(width: 12),
              Text('Randomize Questions', style: _headingFont(fontSize: 16, color: _textPrimary)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will shuffle the order of questions within each section to prevent predictable patterns.',
                style: _font(fontSize: 13, color: _textSecondary),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: shuffleOptions,
                onChanged: (v) => setDialogState(() => shuffleOptions = v ?? false),
                title: Text('Also shuffle MCQ options', style: _font(fontSize: 13, fontWeight: FontWeight.w600, color: _textPrimary)),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(0xFF2563EB),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: _font(color: _textSecondary))),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                try {
                  await _apiService.randomizeExamQuestions(_exam!.id, shuffleOptions: shuffleOptions);
                  await _loadSectionsData();
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Questions randomized successfully'), backgroundColor: Color(0xFF16A34A)),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Randomize failed: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              child: const Text('Randomize', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  /// 4. CLEAR ALL QUESTIONS DIALOG
  Future<void> _showClearAllDialog() async {
    if (_exam == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: _cardBorder)),
        title: Text('Clear All Questions?', style: _headingFont(fontSize: 16, color: _textPrimary)),
        content: Text('This will remove all questions from this exam paper. You will need to re-add them.', style: _font(color: _textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: _font(color: _textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _apiService.clearAllExamQuestions(_exam!.id);
        await _loadSectionsData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All questions cleared from paper'), backgroundColor: Color(0xFF475569)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Clear failed: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  /// 5. EDIT PAPER TYPE DIALOG
  Future<void> _showEditPaperTypeDialog() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: _cardBorder)),
        title: Text('Select Paper Type', style: _headingFont(fontSize: 16, color: _textPrimary)),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _paperTypes.map((pt) {
              final isSel = _paperType == pt.name;
              return ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                tileColor: isSel ? const Color(0xFF2563EB).withValues(alpha: _isDark ? 0.2 : 0.08) : Colors.transparent,
                title: Text(pt.name, style: _font(fontWeight: FontWeight.w600, color: isSel ? const Color(0xFF3B82F6) : _textPrimary)),
                trailing: isSel ? const Icon(Icons.check, color: Color(0xFF2563EB)) : null,
                onTap: () {
                  setState(() {
                    _paperType = pt.name;
                  });
                  Navigator.pop(ctx);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  /// 6. EDIT TOTAL MARKS & DURATION DIALOG
  Future<void> _showEditMarksAndDurationDialog() async {
    final marksCtrl = TextEditingController(text: '$_totalMarks');
    final durationCtrl = TextEditingController(text: '$_durationMinutes');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: _cardBorder)),
        title: Text('Paper Details', style: _headingFont(fontSize: 16, color: _textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: marksCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(color: _textPrimary),
              decoration: InputDecoration(
                labelText: 'Total Paper Marks',
                labelStyle: _font(color: _textSecondary),
                filled: true,
                fillColor: _inputBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _cardBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _cardBorder)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: durationCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(color: _textPrimary),
              decoration: InputDecoration(
                labelText: 'Duration in Minutes (e.g. 120)',
                labelStyle: _font(color: _textSecondary),
                filled: true,
                fillColor: _inputBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _cardBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _cardBorder)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: _font(color: _textSecondary))),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _totalMarks = int.tryParse(marksCtrl.text.trim()) ?? 100;
                _durationMinutes = int.tryParse(durationCtrl.text.trim()) ?? 120;
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// 7. EDIT QUESTION MARKS DIALOG
  Future<void> _showEditQuestionMarksDialog(Map<String, dynamic> q) async {
    final ctrl = TextEditingController(text: q['marks']?.toString() ?? '1');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: _cardBorder)),
        title: Text('Edit Question Marks', style: _headingFont(fontSize: 16, color: _textPrimary)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: TextStyle(color: _textPrimary),
          decoration: InputDecoration(
            labelText: 'Marks',
            labelStyle: _font(color: _textSecondary),
            filled: true,
            fillColor: _inputBg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _cardBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _cardBorder)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: _font(color: _textSecondary))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final newMarks = int.tryParse(ctrl.text.trim()) ?? 1;
              try {
                await _apiService.updateExamQuestion(_exam!.id, q['id'], {'marks': newMarks});
                await _loadSectionsData();
              } catch (_) {}
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            child: const Text('Update', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// 8. EXAM SWITCHER MODAL (Theme-aware & Premium)
  Future<void> _showExamSwitcherDialog() async {
    final searchCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final query = searchCtrl.text.trim().toLowerCase();
          final filteredExams = query.isEmpty
              ? _allExams
              : _allExams.where((e) {
                  return e.title.toLowerCase().contains(query) ||
                      e.subject.toLowerCase().contains(query) ||
                      e.class_.toLowerCase().contains(query);
                }).toList();

          return Dialog(
            backgroundColor: _cardBg,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: _cardBorder),
            ),
            child: Container(
              width: 520,
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF3B82F6), size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Switch Examination',
                              style: _headingFont(fontSize: 17, fontWeight: FontWeight.bold, color: _textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Select an examination to author or edit its question paper',
                              style: _font(fontSize: 12, color: _textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, size: 20, color: _textSecondary),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Search field
                  SizedBox(
                    height: 38,
                    child: TextField(
                      controller: searchCtrl,
                      onChanged: (_) => setDialogState(() {}),
                      style: TextStyle(fontSize: 13, color: _textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search exams by title, subject or class...',
                        hintStyle: _font(fontSize: 12, color: _textSecondary),
                        prefixIcon: Icon(Icons.search, size: 18, color: _textSecondary),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        filled: true,
                        fillColor: _inputBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: _cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: _cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF2563EB)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 340),
                    child: filteredExams.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text('No matching examinations found', style: _font(color: _textSecondary)),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: filteredExams.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, idx) {
                              final e = filteredExams[idx];
                              final isCurrent = e.id == _exam?.id;

                              return InkWell(
                                onTap: () {
                                  Navigator.pop(ctx);
                                  context.pushReplacement('${getExamsBaseRoute(context)}/paper-builder?examId=${e.id}');
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isCurrent
                                        ? const Color(0xFF2563EB).withValues(alpha: _isDark ? 0.2 : 0.08)
                                        : _innerCardBg,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isCurrent
                                          ? const Color(0xFF2563EB).withValues(alpha: 0.6)
                                          : _cardBorder,
                                      width: isCurrent ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              e.title,
                                              style: _font(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                                color: isCurrent ? const Color(0xFF3B82F6) : _textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(Icons.menu_book_outlined, size: 13, color: _textSecondary),
                                                const SizedBox(width: 4),
                                                Text(e.subject, style: _font(fontSize: 11, color: _textSecondary)),
                                                const SizedBox(width: 10),
                                                Icon(Icons.people_outline, size: 13, color: _textSecondary),
                                                const SizedBox(width: 4),
                                                Text(e.class_, style: _font(fontSize: 11, color: _textSecondary)),
                                                const SizedBox(width: 10),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: _isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    e.examCategory,
                                                    style: _font(fontSize: 10, color: _textSecondary, fontWeight: FontWeight.w600),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isCurrent)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2563EB),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'Active',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _cardBorder),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('Close', style: _font(color: _textSecondary)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 9. CREATE QUESTION INLINE MODAL (REUSED FROM QUESTION BANK SCREEN)
  Future<void> _showCreateQuestionInlineDialog() async {
    // Load lookups if needed
    List<QuestionBankLookupItem> qTypes = _questionTypes;
    List<QuestionBankLookupItem> diffs = _difficulties;
    List<QuestionBankLookupItem> statuses = [];
    List<QuestionBankLookupItem> tags = [];
    List<QuestionBankLookupItem> sources = [];
    List<QuestionBankLookupItem> languages = [];
    List<TeacherSubject> subjects = [];
    List<String> classes = [];
    List<String> chaps = _chapters;

    try {
      final results = await Future.wait([
        qTypes.isNotEmpty ? Future.value(qTypes) : _lookupHelper.getQuestionTypes(),
        diffs.isNotEmpty ? Future.value(diffs) : _lookupHelper.getDifficultyLevels(),
        _lookupHelper.getQuestionStatuses(),
        _lookupHelper.getQuestionTags(),
        _lookupHelper.getQuestionSources(),
        _lookupHelper.getQuestionLanguages(),
        _apiService.getSubjects(),
        _apiService.getQuestionBankClasses(),
        chaps.isNotEmpty ? Future.value(chaps) : _apiService.getQuestionBankChapters(),
      ]);

      qTypes = results[0] as List<QuestionBankLookupItem>;
      diffs = results[1] as List<QuestionBankLookupItem>;
      statuses = results[2] as List<QuestionBankLookupItem>;
      tags = results[3] as List<QuestionBankLookupItem>;
      sources = results[4] as List<QuestionBankLookupItem>;
      languages = results[5] as List<QuestionBankLookupItem>;
      subjects = results[6] as List<TeacherSubject>;
      classes = results[7] as List<String>;
      chaps = results[8] as List<String>;

      if (mounted) {
        setState(() {
          _questionTypes = qTypes;
          _difficulties = diffs;
          _chapters = chaps;
        });
      }
    } catch (_) {}

    final targetClass = (_exam?.class_.isNotEmpty == true) ? _exam!.class_ : null;

    if (!mounted) return;

    final newQ = await showDialog<QuestionBankItem>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => QuestionEditorDialog(
        lookupTypes: qTypes,
        lookupDifficulties: diffs,
        lookupStatuses: statuses,
        lookupTags: tags,
        lookupSources: sources,
        lookupLanguages: languages,
        subjects: subjects,
        classes: classes,
        chapters: chaps,
        initialClass: targetClass,
        initialSubject: _exam?.subject,
        initialChapter: _selectedChapter != 'All Chapters' ? _selectedChapter : null,
      ),
    );

    if (newQ != null) {
      // Auto-add the newly created question to current paper section and refresh question bank
      await _addSingleQuestionToSection(newQ, targetSectionId: _targetSectionId);
      await _fetchQbQuestions();
    }
  }
}

// ============================================================================
// POPUP MODAL: PAPER PREVIEW (STUDENT COPY & TEACHER MARKING SCHEME)
// ============================================================================

class _PaperPreviewModal extends StatefulWidget {
  final String examId;
  final ExamsApiService apiService;

  const _PaperPreviewModal({
    required this.examId,
    required this.apiService,
  });

  @override
  State<_PaperPreviewModal> createState() => _PaperPreviewModalState();
}

class _PaperPreviewModalState extends State<_PaperPreviewModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic>? _previewData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    try {
      final res = await widget.apiService.getPaperPreview(widget.examId);
      if (mounted) {
        setState(() {
          _previewData = res;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Dialog(
      backgroundColor: cardBg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cardBorder),
      ),
      child: Container(
        width: 860,
        height: 720,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header with Tabs & Close
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.print_outlined, color: Color(0xFF3B82F6), size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  'Examination Paper Preview',
                  style: TextStyle(fontFamily: AppFonts.heading, fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                ),
                const Spacer(),
                SizedBox(
                  width: 320,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: const Color(0xFF2563EB),
                    labelColor: const Color(0xFF2563EB),
                    unselectedLabelColor: textSecondary,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    tabs: const [
                      Tab(text: 'Student Copy'),
                      Tab(text: 'Teacher Marking Scheme'),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: Icon(Icons.close, color: textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Divider(color: cardBorder),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                  : _previewData == null
                      ? Center(child: Text('Failed to load preview', style: TextStyle(color: textSecondary)))
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            // 1. Student Copy
                            _buildFormattedPaper(isTeacherCopy: false, isDark: isDark, textPrimary: textPrimary, textSecondary: textSecondary, cardBorder: cardBorder),
                            // 2. Teacher Marking Scheme
                            _buildFormattedPaper(isTeacherCopy: true, isDark: isDark, textPrimary: textPrimary, textSecondary: textSecondary, cardBorder: cardBorder),
                          ],
                        ),
            ),

            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, size: 16, color: textSecondary),
                  label: Text('Close', style: TextStyle(color: textSecondary)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: cardBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    final targetId = widget.examId;
                    if (targetId.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select or save the exam first.'), backgroundColor: Colors.orange),
                      );
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Preparing printable exam paper PDF...'), backgroundColor: Color(0xFF2563EB)),
                    );
                    try {
                      final pdfBytes = await widget.apiService.downloadExamPaperPdf(targetId);
                      final filename = 'exam_paper_${targetId.length > 8 ? targetId.substring(0, 8) : targetId}.pdf';
                      await getDownloadHelper().downloadBytes(pdfBytes, filename);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Exam paper PDF downloaded successfully!'), backgroundColor: Color(0xFF16A34A)),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to generate PDF: $e'), backgroundColor: const Color(0xFFDC2626)),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.print, size: 16, color: Colors.white),
                  label: const Text('Print Paper', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormattedPaper({
    required bool isTeacherCopy,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color cardBorder,
  }) {
    final institute = _previewData?['institute'] as Map<String, dynamic>? ?? {};
    final exam = _previewData?['exam'] as Map<String, dynamic>? ?? {};
    final sections = (_previewData?['sections'] as List? ?? []).map((s) => Map<String, dynamic>.from(s as Map)).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          border: Border.all(color: cardBorder),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // School Header
            Text(
              institute['name']?.toString().toUpperCase() ?? 'EDUSHAMIIT INTERNATIONAL SCHOOL',
              style: TextStyle(fontFamily: AppFonts.heading, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              institute['address']?.toString() ?? 'Affiliated to CBSE • Examination Division',
              style: TextStyle(fontSize: 12, color: textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isTeacherCopy
                    ? (isDark ? const Color(0xFF78350F).withValues(alpha: 0.3) : const Color(0xFFFEF3C7))
                    : (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isTeacherCopy
                    ? 'TEACHER MARKING SCHEME & SOLUTION KEY'
                    : (exam['title']?.toString().toUpperCase() ?? 'EXAMINATION PAPER'),
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isTeacherCopy
                      ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFF92400E))
                      : (isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E40AF)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Metadata row
            Builder(
              builder: (context) {
                final targetClass = (exam['target_classes'] is List && (exam['target_classes'] as List).isNotEmpty)
                    ? (exam['target_classes'] as List).first.toString()
                    : (exam['class'] ?? exam['class_name'] ?? 'Class 10').toString();
                final durationNum = (exam['duration_minutes'] is num)
                    ? (exam['duration_minutes'] as num).toDouble()
                    : (double.tryParse(exam['duration_minutes']?.toString() ?? '120') ?? 120.0);
                final durationStr = '${(durationNum / 60).toStringAsFixed(durationNum % 60 == 0 ? 0 : 1)} Hours';

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Class: $targetClass', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary)),
                    Text('Subject: ${exam['subject'] ?? 'Mathematics'}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary)),
                    Text('Max Marks: ${exam['total_marks'] ?? 100}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary)),
                    Text('Time: $durationStr', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary)),
                  ],
                );
              },
            ),
            Divider(height: 24, thickness: 1.5, color: cardBorder),

            // General Instructions
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('General Instructions:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary)),
                  const SizedBox(height: 4),
                  Text(
                    exam['instructions']?.toString() ?? '1. All questions are compulsory.\n2. Write clearly.',
                    style: TextStyle(fontSize: 11, color: textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Sections & Questions
            for (final sec in sections) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  sec['name']?.toString() ?? 'Section',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: textPrimary),
                ),
              ),
              const SizedBox(height: 10),

              // Questions in Section
              for (int qIdx = 0; qIdx < (sec['questions'] as List? ?? []).length; qIdx++) ...[
                _buildPrintQuestionRow((sec['questions'] as List)[qIdx], qIdx + 1, isTeacherCopy, isDark, textPrimary, textSecondary),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPrintQuestionRow(
    dynamic questionData,
    int num,
    bool isTeacherCopy,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    final q = questionData is Map ? Map<String, dynamic>.from(questionData) : <String, dynamic>{};
    final text = q['question_text']?.toString() ?? q['title']?.toString() ?? '';
    final marks = q['marks']?.toString() ?? '1';
    final options = (q['options'] as List? ?? []);
    final correctAnswer = q['correct_answer']?.toString();
    final explanation = q['explanation']?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Q$num. ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary)),
            Expanded(
              child: Text(text, style: TextStyle(fontSize: 12, height: 1.3, color: textPrimary)),
            ),
            const SizedBox(width: 8),
            Text('[$marks]', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary)),
          ],
        ),
        if (options.isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Wrap(
              spacing: 24,
              runSpacing: 6,
              children: List.generate(options.length, (optIdx) {
                final opt = options[optIdx];
                String optId = String.fromCharCode(65 + optIdx);
                String optText = '';

                if (opt is Map) {
                  optId = (opt['id'] ?? opt['label'] ?? String.fromCharCode(65 + optIdx)).toString();
                  optText = (opt['text'] ?? opt['value'] ?? opt['title'] ?? '').toString();
                } else if (opt is String) {
                  optText = opt;
                  // If string starts with "A. " or "A) ", extract the letter
                  final match = RegExp(r'^([A-D])[\.\)]\s*(.*)$', caseSensitive: false).firstMatch(opt.trim());
                  if (match != null) {
                    optId = match.group(1)!.toUpperCase();
                    optText = match.group(2)!;
                  }
                } else {
                  optText = opt?.toString() ?? '';
                }

                final cleanCorrect = correctAnswer?.trim().toUpperCase() ?? '';
                final isCorrect = isTeacherCopy && (
                  cleanCorrect == optId.toUpperCase() ||
                  cleanCorrect == optText.trim().toUpperCase() ||
                  cleanCorrect.startsWith('$optId:') ||
                  cleanCorrect.startsWith('($optId)') ||
                  (cleanCorrect.length == 1 && cleanCorrect == String.fromCharCode(65 + optIdx))
                );

                return Container(
                  margin: const EdgeInsets.only(right: 8, bottom: 2),
                  padding: isCorrect
                      ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
                      : EdgeInsets.zero,
                  decoration: isCorrect
                      ? BoxDecoration(
                          color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.4)),
                        )
                      : null,
                  child: Text(
                    '($optId) $optText',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                      color: isCorrect
                          ? const Color(0xFF16A34A)
                          : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
        if (isTeacherCopy && (correctAnswer != null || explanation != null)) ...[
          const SizedBox(height: 6),
          Container(
            margin: const EdgeInsets.only(left: 20, top: 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isDark ? const Color(0xFF059669).withValues(alpha: 0.5) : const Color(0xFFBBF7D0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (correctAnswer != null && correctAnswer.isNotEmpty)
                  Text('Answer: $correctAnswer', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF22C55E))),
                if (explanation != null && explanation.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('Step Marks / Explanation: $explanation', style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF166534))),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
