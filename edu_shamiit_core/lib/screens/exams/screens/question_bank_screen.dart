import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import 'package:edu_shamiit_core/constants/app_fonts.dart';
import 'package:edu_shamiit_core/models/teacher_models.dart';
import 'package:edu_shamiit_core/screens/exams/services/exams_api_service.dart';
import 'package:edu_shamiit_core/screens/exams/services/question_bank_lookup_helper.dart';
import 'package:edu_shamiit_core/utils/download_helper.dart';

/// Font helper matching EduSHAMIIT ERP typography
TextStyle _font({
  double fontSize = 13,
  FontWeight fontWeight = FontWeight.normal,
  Color? color,
  double? letterSpacing,
  double? height,
}) {
  return TextStyle(
    fontFamily: AppFonts.body,
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );
}

class QuestionBankScreen extends ConsumerStatefulWidget {
  const QuestionBankScreen({super.key});

  @override
  ConsumerState<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends ConsumerState<QuestionBankScreen> {
  final ExamsApiService _apiService = ExamsApiService.instance;
  final QuestionBankLookupHelper _lookupHelper = QuestionBankLookupHelper.instance;

  // Search & Filter State
  final TextEditingController _searchController = TextEditingController();
  String _selectedClass = 'All';
  String _selectedSubject = 'All';
  String _selectedChapter = 'All';
  String _selectedDifficulty = 'All';
  String _selectedTab = 'all'; // all, mcq, short_answer, long_answer, others

  // Pagination State
  int _currentPage = 1;
  int _pageSize = 10;
  int _totalQuestions = 0;
  int _totalPages = 1;

  // Selection & Active Item
  final Set<String> _selectedQuestionIds = {};
  QuestionBankItem? _activePreviewItem;

  // Dynamic Metadata & Lookups
  List<QuestionBankItem> _questions = [];
  Map<String, dynamic> _kpis = {};
  List<TeacherSubject> _subjects = [];
  List<String> _classList = [];
  List<String> _chapterList = [];
  List<QuestionBankLookupItem> _lookupTypes = [];
  List<QuestionBankLookupItem> _lookupDifficulties = [];
  List<QuestionBankLookupItem> _lookupStatuses = [];
  List<QuestionBankLookupItem> _lookupTags = [];
  List<QuestionBankLookupItem> _lookupSources = [];
  List<QuestionBankLookupItem> _lookupLanguages = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Initial load of lookup master data, subjects, classes, chapters and questions
  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final lookupResults = await Future.wait([
        _lookupHelper.getQuestionTypes(),
        _lookupHelper.getDifficultyLevels(),
        _lookupHelper.getQuestionStatuses(),
        _lookupHelper.getQuestionTags(),
        _lookupHelper.getQuestionSources(),
        _lookupHelper.getQuestionLanguages(),
        _apiService.getSubjects(),
        _apiService.getQuestionBankClasses(),
        _apiService.getQuestionBankChapters(),
      ]);

      _lookupTypes = lookupResults[0] as List<QuestionBankLookupItem>;
      _lookupDifficulties = lookupResults[1] as List<QuestionBankLookupItem>;
      _lookupStatuses = lookupResults[2] as List<QuestionBankLookupItem>;
      _lookupTags = lookupResults[3] as List<QuestionBankLookupItem>;
      _lookupSources = lookupResults[4] as List<QuestionBankLookupItem>;
      _lookupLanguages = lookupResults[5] as List<QuestionBankLookupItem>;
      _subjects = lookupResults[6] as List<TeacherSubject>;
      _classList = lookupResults[7] as List<String>;
      _chapterList = lookupResults[8] as List<String>;

      await _fetchQuestions();
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Server-side fetch with current filters and pagination
  Future<void> _fetchQuestions() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      String? qTypeParam;
      if (_selectedTab == 'mcq') {
        qTypeParam = 'mcq';
      } else if (_selectedTab == 'short_answer') {
        qTypeParam = 'short_answer';
      } else if (_selectedTab == 'long_answer') {
        qTypeParam = 'long_answer';
      } else if (_selectedTab == 'others') {
        qTypeParam = 'others';
      }

      final pagedResult = await _apiService.getQuestionBankPaged(
        search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
        className: _selectedClass == 'All' ? null : _selectedClass,
        subject: _selectedSubject == 'All' ? null : _selectedSubject,
        chapter: _selectedChapter == 'All' ? null : _selectedChapter,
        difficulty: _selectedDifficulty == 'All' ? null : _selectedDifficulty,
        questionType: qTypeParam,
        page: _currentPage,
        pageSize: _pageSize,
      );

      final list = pagedResult['questions'] as List<QuestionBankItem>? ?? [];
      final total = (pagedResult['total'] as int?) ?? (pagedResult['total_count'] as int?) ?? list.length;
      final pages = (pagedResult['totalPages'] as int?) ?? (pagedResult['total_pages'] as int?) ?? ((total + _pageSize - 1) ~/ (_pageSize > 0 ? _pageSize : 1));
      final kpis = pagedResult['kpis'] as Map<String, dynamic>? ?? {};

      if (mounted) {
        setState(() {
          _questions = list;
          _totalQuestions = total;
          _totalPages = pages;
          _kpis = kpis;
          _selectedQuestionIds.clear();

          if (_questions.isNotEmpty) {
            if (_activePreviewItem == null ||
                !_questions.any((q) => q.id == _activePreviewItem!.id)) {
              _activePreviewItem = _questions.first;
            } else {
              _activePreviewItem = _questions.firstWhere(
                (q) => q.id == _activePreviewItem!.id,
                orElse: () => _questions.first,
              );
            }
          } else {
            _activePreviewItem = null;
          }

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

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _selectedClass = 'All';
      _selectedSubject = 'All';
      _selectedChapter = 'All';
      _selectedDifficulty = 'All';
      _selectedTab = 'all';
      _currentPage = 1;
    });
    _fetchQuestions();
  }

  // ============================================================================
  // UI BUILD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation & Screen Header
            _buildTopHeader(isDark),

            // Main Content Area
            Expanded(
              child: _isLoading && _questions.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF2563EB)),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchQuestions,
                      color: const Color(0xFF2563EB),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. KPI Cards
                            _buildKpiCardsRow(isDark),
                            const SizedBox(height: 16),

                            // 2. Horizontal Category Tabs Bar
                            _buildCategoryTabs(isDark),
                            const SizedBox(height: 16),

                            // 3. Search & Filter Bar
                            _buildFilterBar(isDark),
                            const SizedBox(height: 16),

                            // 4. Two-Column Layout (Data Table on Left, Live Preview on Right)
                            LayoutBuilder(
                              builder: (context, constraints) {
                                if (constraints.maxWidth >= 1024) {
                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 66,
                                        child: _buildTableCard(isDark),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 34,
                                        child: _buildRightPreviewCard(isDark),
                                      ),
                                    ],
                                  );
                                } else {
                                  return Column(
                                    children: [
                                      _buildTableCard(isDark),
                                      const SizedBox(height: 16),
                                      _buildRightPreviewCard(isDark),
                                    ],
                                  );
                                }
                              },
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // 1. TOP HEADER (Exact Enterprise Layout)
  // ============================================================================

  Widget _buildTopHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        children: [
          // Left: Question Bank Icon Badge & Titles
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Icon(
              Icons.quiz_rounded,
              color: Color(0xFF2563EB),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Question Bank',
                  style: _font(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Manage and organize your question bank across classes, subjects and examinations.',
                  style: _font(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          // Right: Action Buttons (Import, Export, + Add Question)
          OutlinedButton.icon(
            icon: const Icon(Icons.file_upload_outlined, size: 16, color: Color(0xFF2563EB)),
            label: Text(
              'Import Questions',
              style: _font(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2563EB),
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            ),
            onPressed: () => _showImportDialog(),
          ),
          const SizedBox(width: 10),

          OutlinedButton.icon(
            icon: const Icon(Icons.file_download_outlined, size: 16, color: Color(0xFF2563EB)),
            label: Text(
              'Export',
              style: _font(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2563EB),
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            ),
            onPressed: () => _showExportDialog(),
          ),
          const SizedBox(width: 12),

          PopupMenuButton<String>(
            tooltip: 'Add Question Options',
            offset: const Offset(0, 42),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            onSelected: (val) {
              if (val == 'new') {
                _showAddEditQuestionDialog();
              } else if (val == 'import') {
                _showImportDialog();
              } else if (val == 'duplicate') {
                if (_activePreviewItem != null) {
                  _duplicateQuestion(_activePreviewItem!);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a question to duplicate')),
                  );
                }
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'new',
                child: Row(
                  children: [
                    const Icon(Icons.add_circle_outline, size: 18, color: Color(0xFF2563EB)),
                    const SizedBox(width: 10),
                    Text(
                      'Create New Question',
                      style: _font(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    const Icon(Icons.upload_file_outlined, size: 18, color: Color(0xFF059669)),
                    const SizedBox(width: 10),
                    Text(
                      'Import from Spreadsheet',
                      style: _font(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'duplicate',
                child: Row(
                  children: [
                    const Icon(Icons.copy_outlined, size: 18, color: Color(0xFFD97706)),
                    const SizedBox(width: 10),
                    Text(
                      'Duplicate Selected Question',
                      style: _font(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                    offset: const Offset(0, 3),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Add Question',
                    style: _font(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // 2. KPI CARDS (Matching Reference Metrics & Trend Indicators)
  // ============================================================================

  Widget _buildKpiCardsRow(bool isDark) {
    final total = _kpis['total'] ?? _totalQuestions;
    final mcq = _kpis['mcq'] ?? 0;
    final shortAns = _kpis['short_answer'] ?? 0;
    final longAns = _kpis['long_answer'] ?? 0;

    return Row(
      children: [
        // 1. Total Questions
        Expanded(
          child: _buildSingleKpiCard(
            title: 'Total Questions',
            value: total.toString(),
            trend: '↑ 12%',
            icon: Icons.help_outline_rounded,
            iconColor: const Color(0xFF2563EB),
            bgTint: const Color(0xFFEFF6FF),
            isSelected: _selectedTab == 'all',
            isDark: isDark,
            onTap: () {
              setState(() {
                _selectedTab = 'all';
                _currentPage = 1;
              });
              _fetchQuestions();
            },
          ),
        ),
        const SizedBox(width: 14),

        // 2. MCQ Questions
        Expanded(
          child: _buildSingleKpiCard(
            title: 'MCQ Questions',
            value: mcq.toString(),
            trend: '↑ 14%',
            icon: Icons.check_circle_outline_rounded,
            iconColor: const Color(0xFF10B981),
            bgTint: const Color(0xFFECFDF5),
            isSelected: _selectedTab == 'mcq',
            isDark: isDark,
            onTap: () {
              setState(() {
                _selectedTab = 'mcq';
                _currentPage = 1;
              });
              _fetchQuestions();
            },
          ),
        ),
        const SizedBox(width: 14),

        // 3. Short Answer
        Expanded(
          child: _buildSingleKpiCard(
            title: 'Short Answer',
            value: shortAns.toString(),
            trend: '↑ 10%',
            icon: Icons.format_list_bulleted_rounded,
            iconColor: const Color(0xFF8B5CF6),
            bgTint: const Color(0xFFF5F3FF),
            isSelected: _selectedTab == 'short_answer',
            isDark: isDark,
            onTap: () {
              setState(() {
                _selectedTab = 'short_answer';
                _currentPage = 1;
              });
              _fetchQuestions();
            },
          ),
        ),
        const SizedBox(width: 14),

        // 4. Long Answer
        Expanded(
          child: _buildSingleKpiCard(
            title: 'Long Answer',
            value: longAns.toString(),
            trend: '↑ 8%',
            icon: Icons.edit_note_rounded,
            iconColor: const Color(0xFFF97316),
            bgTint: const Color(0xFFFFF7ED),
            isSelected: _selectedTab == 'long_answer',
            isDark: isDark,
            onTap: () {
              setState(() {
                _selectedTab = 'long_answer';
                _currentPage = 1;
              });
              _fetchQuestions();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSingleKpiCard({
    required String title,
    required String value,
    required String trend,
    required IconData icon,
    required Color iconColor,
    required Color bgTint,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2563EB)
                : isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bgTint,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: _font(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        value,
                        style: _font(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        trend,
                        style: _font(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // 3. HORIZONTAL CATEGORY TABS (All, MCQ, Short, Long, Others)
  // ============================================================================

  Widget _buildCategoryTabs(bool isDark) {
    final total = _kpis['total'] ?? _totalQuestions;
    final mcq = _kpis['mcq'] ?? 0;
    final shortAns = _kpis['short_answer'] ?? 0;
    final longAns = _kpis['long_answer'] ?? 0;
    final others = _kpis['others'] ?? 0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildPillTab(
            key: 'all',
            label: 'All Questions',
            count: total,
            icon: Icons.grid_view_rounded,
            isSelected: _selectedTab == 'all',
            isDark: isDark,
          ),
          const SizedBox(width: 10),
          _buildPillTab(
            key: 'mcq',
            label: 'MCQ',
            count: mcq,
            icon: Icons.check_circle_outline_rounded,
            isSelected: _selectedTab == 'mcq',
            isDark: isDark,
          ),
          const SizedBox(width: 10),
          _buildPillTab(
            key: 'short_answer',
            label: 'Short Answer',
            count: shortAns,
            icon: Icons.format_list_bulleted_rounded,
            isSelected: _selectedTab == 'short_answer',
            isDark: isDark,
          ),
          const SizedBox(width: 10),
          _buildPillTab(
            key: 'long_answer',
            label: 'Long Answer',
            count: longAns,
            icon: Icons.edit_note_rounded,
            isSelected: _selectedTab == 'long_answer',
            isDark: isDark,
          ),
          const SizedBox(width: 10),
          _buildPillTab(
            key: 'others',
            label: 'Others',
            count: others,
            icon: Icons.auto_awesome_rounded,
            isSelected: _selectedTab == 'others',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildPillTab({
    required String key,
    required String label,
    required int count,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTab = key;
          _currentPage = 1;
        });
        _fetchQuestions();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2563EB)
              : isDark
                  ? const Color(0xFF1E293B)
                  : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2563EB)
                : isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 8),
            Text(
              '$label ($count)',
              style: _font(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : isDark
                        ? Colors.white70
                        : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // 4. SEARCH & FILTER BAR (With Lookup Keys Integration)
  // ============================================================================

  Widget _buildFilterBar(bool isDark) {
    final classOptions = ['All', ..._classList.toSet()];
    if (!classOptions.contains(_selectedClass)) _selectedClass = 'All';

    final subjectOptions = ['All', ..._subjects.map((s) => s.name).toSet()];
    if (!subjectOptions.contains(_selectedSubject)) _selectedSubject = 'All';

    final chapterOptions = ['All', ..._chapterList.toSet()];
    if (!chapterOptions.contains(_selectedChapter)) _selectedChapter = 'All';

    final diffOptions = [
      'All',
      ..._lookupDifficulties.map((d) => d.name).toSet(),
    ];
    if (!diffOptions.contains(_selectedDifficulty)) _selectedDifficulty = 'All';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
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
          // Search Input
          Expanded(
            flex: 3,
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: _font(
                        fontSize: 13,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'Search questions by keywords...',
                        hintStyle: _font(
                          fontSize: 13,
                          color: const Color(0xFF94A3B8),
                        ),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) {
                        setState(() => _currentPage = 1);
                        _fetchQuestions();
                      },
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _currentPage = 1);
                        _fetchQuestions();
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Dropdown 1: All Classes
          Expanded(
            flex: 2,
            child: _buildCustomDropdown(
              value: _selectedClass,
              items: classOptions,
              prefixLabel: 'Class:',
              isDark: isDark,
              onChanged: (val) {
                setState(() {
                  _selectedClass = val!;
                  _currentPage = 1;
                });
                _fetchQuestions();
              },
            ),
          ),
          const SizedBox(width: 10),

          // Dropdown 2: All Subjects
          Expanded(
            flex: 2,
            child: _buildCustomDropdown(
              value: _selectedSubject,
              items: subjectOptions,
              prefixLabel: 'Subject:',
              isDark: isDark,
              onChanged: (val) {
                setState(() {
                  _selectedSubject = val!;
                  _currentPage = 1;
                });
                _fetchQuestions();
              },
            ),
          ),
          const SizedBox(width: 10),

          // Dropdown 3: All Chapters
          Expanded(
            flex: 2,
            child: _buildCustomDropdown(
              value: _selectedChapter,
              items: chapterOptions,
              prefixLabel: 'Chapter:',
              isDark: isDark,
              onChanged: (val) {
                setState(() {
                  _selectedChapter = val!;
                  _currentPage = 1;
                });
                _fetchQuestions();
              },
            ),
          ),
          const SizedBox(width: 10),

          // Dropdown 4: All Difficulty (from Lookups)
          Expanded(
            flex: 2,
            child: _buildCustomDropdown(
              value: _selectedDifficulty,
              items: diffOptions,
              prefixLabel: 'Difficulty:',
              isDark: isDark,
              onChanged: (val) {
                setState(() {
                  _selectedDifficulty = val!;
                  _currentPage = 1;
                });
                _fetchQuestions();
              },
            ),
          ),
          const SizedBox(width: 12),

          // Action Button: Search
          ElevatedButton.icon(
            icon: const Icon(Icons.search, size: 16, color: Colors.white),
            label: Text(
              'Search',
              style: _font(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              setState(() => _currentPage = 1);
              _fetchQuestions();
            },
          ),
          const SizedBox(width: 8),

          // Action Button: Reset
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF64748B)),
            label: Text(
              'Reset',
              style: _font(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            ),
            onPressed: _resetFilters,
          ),
        ],
      ),
    );
  }

  Widget _buildCustomDropdown({
    required String value,
    required List<String> items,
    required String prefixLabel,
    required bool isDark,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          style: _font(
            fontSize: 13,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          items: items.map((item) {
            final display = item == 'All' ? 'All ${prefixLabel.replaceAll(':', '')}s' : item;
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                display,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ============================================================================
  // 5. LEFT COLUMN: DATA TABLE WITH PAGINATION (Pixel-perfect match)
  // ============================================================================

  Widget _buildTableCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table Header Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Checkbox(
                    value: _questions.isNotEmpty &&
                        _selectedQuestionIds.length == _questions.length,
                    activeColor: const Color(0xFF2563EB),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedQuestionIds.addAll(_questions.map((q) => q.id));
                        } else {
                          _selectedQuestionIds.clear();
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 6),
                _buildHeaderCell('#', width: 34),
                const SizedBox(width: 6),
                Expanded(flex: 30, child: _buildHeaderCell('Question')),
                const SizedBox(width: 8),
                SizedBox(width: 64, child: _buildHeaderCell('Type')),
                const SizedBox(width: 8),
                SizedBox(width: 68, child: _buildHeaderCell('Class')),
                const SizedBox(width: 8),
                SizedBox(width: 88, child: _buildHeaderCell('Subject')),
                const SizedBox(width: 8),
                SizedBox(width: 90, child: _buildHeaderCell('Chapter')),
                const SizedBox(width: 8),
                SizedBox(width: 68, child: _buildHeaderCell('Difficulty')),
                const SizedBox(width: 8),
                SizedBox(width: 44, child: _buildHeaderCell('Marks')),
                const SizedBox(width: 8),
                SizedBox(width: 84, child: _buildHeaderCell('Actions', align: TextAlign.center)),
              ],
            ),
          ),

          // Table Rows
          if (_questions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  const Icon(Icons.search_off_rounded, size: 48, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 12),
                  Text(
                    'No questions found matching your filter criteria.',
                    style: _font(fontSize: 14, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _resetFilters,
                    child: Text('Reset Filters', style: _font(color: const Color(0xFF2563EB))),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _questions.length,
              separatorBuilder: (ctx, i) => Divider(
                height: 1,
                thickness: 1,
                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              ),
              itemBuilder: (ctx, index) {
                final q = _questions[index];
                final rowIndex = (_currentPage - 1) * _pageSize + index + 1;
                final isSelected = _selectedQuestionIds.contains(q.id);
                final isActive = _activePreviewItem?.id == q.id;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _activePreviewItem = q;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    color: isActive
                        ? const Color(0xFFEFF6FF).withValues(alpha: isDark ? 0.2 : 0.6)
                        : isSelected
                            ? const Color(0xFFF1F5F9).withValues(alpha: isDark ? 0.1 : 0.4)
                            : Colors.transparent,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Checkbox(
                            value: isSelected,
                            activeColor: const Color(0xFF2563EB),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedQuestionIds.add(q.id);
                                } else {
                                  _selectedQuestionIds.remove(q.id);
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 6),

                        SizedBox(
                          width: 34,
                          child: Text(
                            '$rowIndex',
                            style: _font(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),

                        Expanded(
                          flex: 30,
                          child: Text(
                            _formatMathFormula(q.questionText),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: _font(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        SizedBox(
                          width: 64,
                          child: _buildTypeBadge(q.questionType),
                        ),
                        const SizedBox(width: 8),

                        SizedBox(
                          width: 68,
                          child: Text(
                            q.className,
                            overflow: TextOverflow.ellipsis,
                            style: _font(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        SizedBox(
                          width: 88,
                          child: Text(
                            q.subjectName,
                            overflow: TextOverflow.ellipsis,
                            style: _font(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white70 : const Color(0xFF334155),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        SizedBox(
                          width: 90,
                          child: Text(
                            q.chapter ?? 'General',
                            overflow: TextOverflow.ellipsis,
                            style: _font(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        SizedBox(
                          width: 68,
                          child: _buildDifficultyBadge(q.difficulty),
                        ),
                        const SizedBox(width: 8),

                        SizedBox(
                          width: 44,
                          child: Text(
                            '${q.marks}',
                            textAlign: TextAlign.center,
                            style: _font(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        SizedBox(
                          width: 84,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              InkWell(
                                onTap: () => setState(() => _activePreviewItem = q),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.visibility_outlined, size: 17, color: Color(0xFF2563EB)),
                                ),
                              ),
                              const SizedBox(width: 2),
                              InkWell(
                                onTap: () => _showAddEditQuestionDialog(question: q),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.edit_outlined, size: 17, color: Color(0xFF64748B)),
                                ),
                              ),
                              const SizedBox(width: 2),
                              InkWell(
                                onTap: () => _confirmDeleteQuestion(q),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.delete_outline_rounded, size: 17, color: Color(0xFFDC2626)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

          // Bottom Pagination Bar
          _buildPaginationBar(isDark),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, {double? width, TextAlign align = TextAlign.left}) {
    return Text(
      text,
      textAlign: align,
      style: _font(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF64748B),
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildTypeBadge(String rawType) {
    final t = rawType.toLowerCase();
    Color bg;
    Color text;
    String label;

    if (t.contains('multi') || t == 'multi_select') {
      bg = const Color(0xFFEEF2FF);
      text = const Color(0xFF4F46E5);
      label = 'Multi-Select';
    } else if (t.contains('mcq') || t.contains('single') || t.contains('choice')) {
      bg = const Color(0xFFEFF6FF);
      text = const Color(0xFF2563EB);
      label = 'MCQ';
    } else if (t.contains('short')) {
      bg = const Color(0xFFFEF3C7);
      text = const Color(0xFFD97706);
      label = 'Short';
    } else if (t.contains('long') || t.contains('essay')) {
      bg = const Color(0xFFF3E8FF);
      text = const Color(0xFF9333EA);
      label = 'Long';
    } else if (t.contains('true') || t.contains('false')) {
      bg = const Color(0xFFECFDF5);
      text = const Color(0xFF059669);
      label = 'True/False';
    } else if (t.contains('blank') || t.contains('fill')) {
      bg = const Color(0xFFFEF9C3);
      text = const Color(0xFFCA8A04);
      label = 'Fill Blanks';
    } else if (t.contains('match')) {
      bg = const Color(0xFFFAF5FF);
      text = const Color(0xFF7C3AED);
      label = 'Match';
    } else if (t.contains('assert') || t.contains('reason')) {
      bg = const Color(0xFFFDF2F8);
      text = const Color(0xFFDB2777);
      label = 'Assertion';
    } else if (t.contains('diagram') || t.contains('image')) {
      bg = const Color(0xFFECFEFF);
      text = const Color(0xFF0891B2);
      label = 'Diagram';
    } else if (t.contains('numer')) {
      bg = const Color(0xFFFFF7ED);
      text = const Color(0xFFEA580C);
      label = 'Numerical';
    } else if (t.contains('case') || t.contains('passage')) {
      bg = const Color(0xFFF0FDF4);
      text = const Color(0xFF16A34A);
      label = 'Case Study';
    } else {
      bg = const Color(0xFFF1F5F9);
      text = const Color(0xFF475569);
      label = rawType.length > 9 ? '${rawType.substring(0, 8)}…' : (rawType.isEmpty ? 'Question' : rawType);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: _font(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
    );
  }

  Widget _buildDifficultyBadge(String rawDiff) {
    final d = rawDiff.toLowerCase();
    Color bg;
    Color text;

    if (d.contains('easy')) {
      bg = const Color(0xFFDCFCE7);
      text = const Color(0xFF16A34A);
    } else if (d.contains('hard')) {
      bg = const Color(0xFFFFE4E6);
      text = const Color(0xFFE11D48);
    } else {
      bg = const Color(0xFFFFEDD5);
      text = const Color(0xFFEA580C);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        rawDiff,
        textAlign: TextAlign.center,
        style: _font(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
    );
  }

  Widget _buildPaginationBar(bool isDark) {
    final startIdx = _questions.isEmpty ? 0 : (_currentPage - 1) * _pageSize + 1;
    final endIdx = ((_currentPage - 1) * _pageSize + _questions.length);

    // Build smart page numbers list
    final List<int?> pageNumbers = [];
    if (_totalPages <= 7) {
      for (int i = 1; i <= _totalPages; i++) {
        pageNumbers.add(i);
      }
    } else {
      pageNumbers.add(1);
      if (_currentPage > 3) {
        pageNumbers.add(null); // ellipsis
      }
      final start = (_currentPage - 1).clamp(2, _totalPages - 1);
      final end = (_currentPage + 1).clamp(2, _totalPages - 1);
      for (int i = start; i <= end; i++) {
        if (!pageNumbers.contains(i)) pageNumbers.add(i);
      }
      if (_currentPage < _totalPages - 2) {
        pageNumbers.add(null); // ellipsis
      }
      if (!pageNumbers.contains(_totalPages)) {
        pageNumbers.add(_totalPages);
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(10),
          bottomRight: Radius.circular(10),
        ),
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing $startIdx - $endIdx of $_totalQuestions questions',
            style: _font(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPageNavButton(
                label: '«',
                isEnabled: _currentPage > 1,
                onTap: () {
                  if (_currentPage > 1) {
                    setState(() => _currentPage--);
                    _fetchQuestions();
                  }
                },
              ),
              const SizedBox(width: 4),
              for (final p in pageNumbers) ...[
                if (p == null) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('...', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                  ),
                ] else ...[
                  _buildPageNumberButton(p),
                  const SizedBox(width: 4),
                ],
              ],
              _buildPageNavButton(
                label: '»',
                isEnabled: _currentPage < _totalPages,
                onTap: () {
                  if (_currentPage < _totalPages) {
                    setState(() => _currentPage++);
                    _fetchQuestions();
                  }
                },
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Rows per page:',
                style: _font(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _pageSize,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: _font(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    icon: Icon(Icons.arrow_drop_down, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    items: [10, 25, 50, 100].map((s) {
                      return DropdownMenuItem(
                        value: s,
                        child: Text(
                          '$s',
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _pageSize = val;
                          _currentPage = 1;
                        });
                        _fetchQuestions();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPageNumberButton(int page) {
    final isCurrent = _currentPage == page;
    return InkWell(
      onTap: () {
        setState(() => _currentPage = page);
        _fetchQuestions();
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isCurrent ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isCurrent ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          '$page',
          style: _font(
            fontSize: 12,
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
            color: isCurrent ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildPageNavButton({
    required String label,
    required bool isEnabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: isEnabled ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isEnabled ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // 6. RIGHT COLUMN: LIVE QUESTION PREVIEW CARD (Interactive & Rich)
  // ============================================================================

  Widget _buildRightPreviewCard(bool isDark) {
    final item = _activePreviewItem;

    if (item == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: const Center(
          child: Text('Select a question to view live preview and details.'),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: "Question Preview" + Type Pill
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Question Preview',
                  style: _font(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                _buildTypeBadge(item.questionType),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Render attached diagram image if present
                if (item.attachments.isNotEmpty) ...[
                  Builder(
                    builder: (context) {
                      final firstAtt = item.attachments.first;
                      String? imgUrl;
                      if (firstAtt is String && (firstAtt.startsWith('http') || firstAtt.startsWith('data:image'))) {
                        imgUrl = firstAtt;
                      } else if (firstAtt is Map && firstAtt['url'] != null) {
                        imgUrl = firstAtt['url'].toString();
                      }
                      if (imgUrl != null && imgUrl.isNotEmpty) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              imgUrl,
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],

                // Question Statement
                Text(
                  _formatMathFormula(item.questionText),
                  style: _font(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),

                // Question Options / Answers
                if (item.options.isNotEmpty)
                  Column(
                    children: List.generate(item.options.length, (i) {
                      final optLetter = String.fromCharCode(65 + i);
                      final optText = item.options[i];
                      final isMulti = item.questionType.toLowerCase().contains('multi');
                      final isCorrect = item.correctAnswer.toUpperCase().contains(optLetter) ||
                          item.correctAnswer.trim() == optText.trim() ||
                          (item.correctAnswer == '$i');

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isCorrect
                              ? const Color(0xFFEFF6FF)
                              : isDark
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isCorrect
                                ? const Color(0xFF2563EB)
                                : isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isMulti
                                  ? (isCorrect ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded)
                                  : (isCorrect ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded),
                              size: 16,
                              color: isCorrect ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '$optLetter. ',
                              style: _font(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isCorrect ? const Color(0xFF2563EB) : const Color(0xFF334155),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _formatMathFormula(optText),
                                style: _font(
                                  fontSize: 13,
                                  fontWeight: isCorrect ? FontWeight.w600 : FontWeight.w400,
                                  color: isCorrect ? const Color(0xFF1E293B) : const Color(0xFF475569),
                                ),
                              ),
                            ),
                            if (isCorrect)
                              const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF10B981)),
                          ],
                        ),
                      );
                    }),
                  )
                else if (item.correctAnswer.isNotEmpty && !item.questionType.toLowerCase().contains('long') && !item.questionType.toLowerCase().contains('short'))
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        Text(
                          'Correct Answer: ',
                          style: _font(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1E40AF)),
                        ),
                        Expanded(
                          child: Text(
                            item.correctAnswer,
                            style: _font(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (item.modelAnswer != null && item.modelAnswer!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle_outline, size: 15, color: Color(0xFF059669)),
                            const SizedBox(width: 6),
                            Text(
                              'Model Answer / Derivation:',
                              style: _font(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatMathFormula(item.modelAnswer!),
                          style: _font(fontSize: 13, color: const Color(0xFF1E293B), height: 1.4),
                        ),
                      ],
                    ),
                  ),

                if (item.explanation != null && item.explanation!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lightbulb_outline, size: 16, color: Color(0xFF16A34A)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Explanation: ${item.explanation}',
                            style: _font(fontSize: 12, color: const Color(0xFF166534)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          Divider(
            height: 1,
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),

          // Section 2: "Question Details"
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Question Details',
                  style: _font(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),

                _buildDetailRow(Icons.school_outlined, 'Class', item.className, isDark: isDark),
                const SizedBox(height: 8),
                _buildDetailRow(Icons.menu_book_outlined, 'Subject', item.subjectName, isDark: isDark),
                const SizedBox(height: 8),
                _buildDetailRow(Icons.bookmark_border_rounded, 'Chapter', (item.chapter != null && item.chapter!.isNotEmpty) ? item.chapter! : 'General', isDark: isDark),
                const SizedBox(height: 8),
                _buildDetailRow(Icons.analytics_outlined, 'Difficulty', item.difficulty, isDark: isDark),
                const SizedBox(height: 8),
                _buildDetailRow(Icons.military_tech_outlined, 'Marks', '${item.marks} Mark${item.marks > 1 ? 's' : ''}', isDark: isDark),
              ],
            ),
          ),

          Divider(
            height: 1,
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),

          // Section 3: "Quick Actions"
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Actions',
                  style: _font(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 15, color: Color(0xFF2563EB)),
                        label: Text(
                          'Edit Question',
                          style: _font(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF2563EB)),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.5) : const Color(0xFFBFDBFE)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          backgroundColor: isDark ? const Color(0xFF2563EB).withValues(alpha: 0.15) : const Color(0xFFEFF6FF),
                        ),
                        onPressed: () => _showAddEditQuestionDialog(question: item),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFDC2626)),
                        label: Text(
                          'Delete Question',
                          style: _font(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFDC2626)),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: isDark ? const Color(0xFFEF4444).withValues(alpha: 0.5) : const Color(0xFFFECACA)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          backgroundColor: isDark ? const Color(0xFFDC2626).withValues(alpha: 0.15) : const Color(0xFFFEF2F2),
                        ),
                        onPressed: () => _confirmDeleteQuestion(item),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.add, size: 15, color: Color(0xFF2563EB)),
                        label: Text(
                          'Add to Paper',
                          style: _font(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF2563EB)),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _showAddToPaperDialog(item),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: Icon(Icons.copy_outlined, size: 15, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                        label: Text(
                          'Duplicate',
                          style: _font(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569)),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _duplicateQuestion(item),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {bool isDark = false}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: _font(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
        ),
        Text(': ', style: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
        Expanded(
          child: Text(
            value.isNotEmpty ? value : '-',
            style: _font(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // 7. COMPREHENSIVE ADD / EDIT QUESTION DIALOG
  // ============================================================================

  void _showAddEditQuestionDialog({QuestionBankItem? question}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return _QuestionEditorDialog(
          question: question,
          lookupTypes: _lookupTypes,
          lookupDifficulties: _lookupDifficulties,
          lookupStatuses: _lookupStatuses,
          lookupTags: _lookupTags,
          lookupSources: _lookupSources,
          lookupLanguages: _lookupLanguages,
          subjects: _subjects,
          classes: _classList,
          chapters: _chapterList,
          onSaved: () {
            _fetchQuestions();
          },
        );
      },
    );
  }

  // ============================================================================
  // 8. IMPORT & EXPORT DIALOGS
  // ============================================================================

  void _showImportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _QuestionImportDialog(
        subjects: _subjects,
        onImportSuccess: () {
          _fetchQuestions();
        },
      ),
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.file_download_outlined, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 12),
              Text(
                'Export Question Bank',
                style: _font(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select export file format to download your question repository:',
                style: _font(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.table_chart_outlined, color: Color(0xFF10B981)),
                title: Text('Excel Spreadsheet (.xlsx / CSV)', style: _font(fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                subtitle: Text('Complete tabular questions, options, difficulty and tags', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12)),
                tileColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Downloading question bank template / export...')),
                  );
                  try {
                    final bytes = await _apiService.exportQuestionBankFile(type: 'all');
                    await getDownloadHelper().downloadBytes(bytes, 'question_bank_export.csv');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Question bank exported successfully!'), backgroundColor: Color(0xFF10B981)),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFFE11D48)),
                title: Text('Printable Question Paper (PDF / CSV)', style: _font(fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                subtitle: Text('Formatted examination question repository file', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12)),
                tileColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Generating printable question set export...')),
                  );
                  try {
                    final bytes = await _apiService.exportQuestionBankFile(type: 'all');
                    await getDownloadHelper().downloadBytes(bytes, 'question_bank_questions.csv');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Question bank export downloaded successfully!'), backgroundColor: Color(0xFF10B981)),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: _font(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
            ),
          ],
        );
      },
    );
  }

  // ============================================================================
  // 9. ADD TO PAPER MODAL
  // ============================================================================

  void _showAddToPaperDialog(QuestionBankItem question) async {
    List<TeacherExam> exams = [];
    try {
      exams = await _apiService.getExams();
    } catch (_) {}

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        String? selectedExamId = exams.isNotEmpty ? exams.first.id : null;
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.assignment_add, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 12),
                  Text('Add Question to Examination Paper', style: _font(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected Question: ${question.questionText}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _font(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 14),
                  if (exams.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'No active scheduled exams found. Create an exam in Exams module first.',
                        style: _font(fontSize: 12, color: const Color(0xFF92400E)),
                      ),
                    )
                  else
                    Builder(
                      builder: (context) {
                        final examMap = <String, TeacherExam>{};
                        for (final e in exams) {
                          examMap[e.id] = e;
                        }
                        final examValue = (selectedExamId != null && examMap.containsKey(selectedExamId))
                            ? selectedExamId
                            : (examMap.isNotEmpty ? examMap.keys.first : null);

                        return DropdownButtonFormField<String>(
                          initialValue: examValue,
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            labelText: 'Select Examination',
                            labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                          ),
                          items: examMap.values.map((e) {
                            return DropdownMenuItem<String>(
                              value: e.id,
                              child: Text('${e.title} (${e.subject})', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A))),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setDialogState(() => selectedExamId = val);
                          },
                        );
                      },
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('Cancel', style: _font(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: selectedExamId == null
                      ? null
                      : () async {
                          Navigator.of(ctx).pop();
                          try {
                            await _apiService.addExamQuestion(
                              selectedExamId!,
                              {
                                'question_text': question.questionText,
                                'question_type': question.questionType,
                                'options': question.options,
                                'correct_answer': question.correctAnswer,
                                'difficulty': question.difficulty,
                                'marks': question.marks,
                                'negative_marks': question.negativeMarks,
                                'explanation': question.explanation,
                              },
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Question successfully added to examination paper!'),
                                  backgroundColor: Color(0xFF16A34A),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to add to paper: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                  child: const Text('Add to Paper', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================================
  // 10. DUPLICATE & DELETE ACTIONS
  // ============================================================================

  void _duplicateQuestion(QuestionBankItem question) async {
    try {
      await _apiService.duplicateQuestion(question.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Question duplicated as draft copy!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
      _fetchQuestions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to duplicate question: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _confirmDeleteQuestion(QuestionBankItem question) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
              const SizedBox(width: 8),
              Text('Delete Question', style: _font(fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
            ],
          ),
          content: Text(
            'Are you sure you want to delete this question? This question will be archived.',
            style: _font(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: _font(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.of(ctx).pop();
                try {
                  await _apiService.deleteQuestionFromBank(question.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Question deleted successfully!')),
                    );
                  }
                  _fetchQuestions();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to delete question: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // ============================================================================
  // 11. MATH FORMULA FORMATTER HELPER
  // ============================================================================

  static String _formatMathFormula(String text) {
    if (text.isEmpty) return '';
    return text
        .replaceAll('^2', '²')
        .replaceAll('^3', '³')
        .replaceAll('^4', '⁴')
        .replaceAll('^n', 'ⁿ')
        .replaceAll('\\pi', 'π')
        .replaceAll('\\theta', 'θ')
        .replaceAll('\\sqrt', '√')
        .replaceAll('\\pm', '±')
        .replaceAll('\\times', '×')
        .replaceAll('\\div', '÷')
        .replaceAll('\\le', '≤')
        .replaceAll('\\ge', '≥')
        .replaceAll('\\ne', '≠');
  }
}

// ============================================================================
// COMPONENT: PREMIUM QUESTION EDITOR DIALOG
// ============================================================================

class QuestionEditorDialog extends StatefulWidget {
  final QuestionBankItem? question;
  final List<QuestionBankLookupItem> lookupTypes;
  final List<QuestionBankLookupItem> lookupDifficulties;
  final List<QuestionBankLookupItem> lookupStatuses;
  final List<QuestionBankLookupItem> lookupTags;
  final List<QuestionBankLookupItem> lookupSources;
  final List<QuestionBankLookupItem> lookupLanguages;
  final List<TeacherSubject> subjects;
  final List<String> classes;
  final List<String> chapters;
  final VoidCallback? onSaved;
  final void Function(QuestionBankItem savedQuestion)? onQuestionSaved;
  final String? initialClass;
  final String? initialSubject;
  final String? initialChapter;

  const QuestionEditorDialog({
    super.key,
    this.question,
    this.lookupTypes = const [],
    this.lookupDifficulties = const [],
    this.lookupStatuses = const [],
    this.lookupTags = const [],
    this.lookupSources = const [],
    this.lookupLanguages = const [],
    this.subjects = const [],
    this.classes = const [],
    this.chapters = const [],
    this.onSaved,
    this.onQuestionSaved,
    this.initialClass,
    this.initialSubject,
    this.initialChapter,
  });

  @override
  State<QuestionEditorDialog> createState() => _QuestionEditorDialogState();
}

typedef _QuestionEditorDialog = QuestionEditorDialog;

class _QuestionEditorDialogState extends State<QuestionEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final ExamsApiService _apiService = ExamsApiService.instance;

  int _selectedTabIndex = 0;

  late TextEditingController _titleController;
  late TextEditingController _questionTextController;
  late TextEditingController _topicController;
  late TextEditingController _marksController;
  late TextEditingController _negativeMarksController;
  late TextEditingController _explanationController;
  late TextEditingController _modelAnswerController;
  late TextEditingController _codeController;

  String? _selectedClass;
  String? _selectedSubject;
  String? _selectedChapter;
  String? _selectedType;
  String? _selectedDifficulty;
  String? _selectedStatus;
  String? _selectedSource;
  String? _selectedLanguage;

  // Single-Select & Multi-Select options
  List<TextEditingController> _optionControllers = [];
  String _correctAnswer = 'A';
  final Set<String> _multiCorrectAnswers = {};
  final Set<String> _selectedTags = {};
  bool _isSaving = false;

  // True / False
  String _tfCorrect = 'True';

  // Fill in the Blanks
  List<TextEditingController> _blankControllers = [];

  // Match the Following
  List<TextEditingController> _matchPremiseControllers = [];
  List<TextEditingController> _matchResponseControllers = [];
  Map<int, String> _matchPairs = {};

  // Assertion and Reason
  late TextEditingController _assertionController;
  late TextEditingController _reasonController;
  String _arCorrect = 'A';

  // Diagram / Image Based
  String? _diagramImageUrl;
  Uint8List? _diagramImageBytes;
  String? _diagramImageName;
  bool _isUploadingImage = false;
  String _diagramAnswerFormat = 'mcq';

  // Numerical Problem
  late TextEditingController _numericValueController;
  late TextEditingController _numericUnitController;
  late TextEditingController _numericToleranceController;

  String get _normType {
    final t = (_selectedType ?? 'mcq').toLowerCase().trim();
    if (t == 'multi_select' || t.contains('multi')) return 'multi_select';
    if (t == 'true_false' || t.contains('true') || t.contains('false') || t == 'boolean') return 'true_false';
    if (t.startsWith('fill') || t.contains('blank')) return 'fill_blanks';
    if (t.contains('match')) return 'match_following';
    if (t.contains('assert') || t.contains('reason')) return 'assertion_reason';
    if (t.contains('diagram') || t.contains('image')) return 'diagram';
    if (t.contains('numer')) return 'numerical';
    if (t.contains('case') || t.contains('passage')) return 'case_study';
    if (t.contains('short')) return 'short_answer';
    if (t.contains('long') || t.contains('essay') || t.contains('descriptive')) return 'long_answer';
    if (t.contains('practical') || t.contains('oral') || t.contains('activity')) return 'practical';
    return 'mcq';
  }

  void _updateMatchCorrectAnswer() {
    final pairs = <String>[];
    for (int i = 0; i < _matchPremiseControllers.length; i++) {
      final rightLetter = _matchPairs[i] ?? String.fromCharCode(65 + (i % 26));
      pairs.add('${i + 1}-$rightLetter');
    }
    _correctAnswer = pairs.join(', ');
  }

  Future<void> _pickDiagramImage() async {
    try {
      setState(() => _isUploadingImage = true);
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'svg'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;
        final fileName = file.name;

        if (bytes != null) {
          final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'png';
          final mime = (ext == 'jpg' || ext == 'jpeg') ? 'image/jpeg' : (ext == 'svg' ? 'image/svg+xml' : 'image/png');
          final dataUri = 'data:$mime;base64,${base64Encode(bytes)}';

          String? serverUrl;
          try {
            serverUrl = await _apiService.uploadFileBytes(
              bytes: bytes,
              filename: fileName,
            );
          } catch (_) {}

          if (mounted) {
            setState(() {
              _diagramImageBytes = bytes;
              _diagramImageName = fileName;
              _diagramImageUrl = serverUrl ?? dataUri;
              _isUploadingImage = false;
            });
          }
        } else {
          if (mounted) setState(() => _isUploadingImage = false);
        }
      } else {
        if (mounted) setState(() => _isUploadingImage = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  @override
  void initState() {
    super.initState();
    final q = widget.question;

    _titleController = TextEditingController(text: q?.title ?? '');
    _questionTextController = TextEditingController(text: q?.questionText ?? '');
    _topicController = TextEditingController(text: q?.topic ?? '');
    _marksController = TextEditingController(text: '${q?.marks ?? 1}');
    _negativeMarksController = TextEditingController(text: '${q?.negativeMarks ?? 0.0}');
    _explanationController = TextEditingController(text: q?.explanation ?? '');
    _modelAnswerController = TextEditingController(text: q?.modelAnswer ?? '');
    _codeController = TextEditingController(text: q?.questionCode ?? '');

    _selectedClass = q?.className ?? widget.initialClass ?? (widget.classes.isNotEmpty ? widget.classes.first : 'Class 10');
    _selectedSubject = q?.subjectName ?? widget.initialSubject ?? (widget.subjects.isNotEmpty ? widget.subjects.first.name : 'Mathematics');
    _selectedChapter = q?.chapter ?? widget.initialChapter ?? (widget.chapters.isNotEmpty ? widget.chapters.first : 'General');
    _selectedType = q?.questionType.toLowerCase() ?? 'mcq';
    _selectedDifficulty = q?.difficulty ?? 'Medium';
    _selectedStatus = q?.status ?? 'approved';
    _selectedSource = 'teacher_created';
    _selectedLanguage = q?.languageCode ?? 'en';

    if (q != null && q.options.isNotEmpty) {
      _optionControllers = q.options.map((opt) => TextEditingController(text: opt)).toList();
      _correctAnswer = q.correctAnswer;
    } else {
      _optionControllers = [
        TextEditingController(text: 'Option A'),
        TextEditingController(text: 'Option B'),
        TextEditingController(text: 'Option C'),
        TextEditingController(text: 'Option D'),
      ];
      _correctAnswer = 'A';
    }

    // Multi-Select answers parsing
    if (q != null && q.correctAnswer.isNotEmpty) {
      final parts = q.correctAnswer.split(RegExp(r'[,;\s]+')).map((e) => e.trim().toUpperCase()).where((e) => e.isNotEmpty);
      for (final p in parts) {
        if (p.length == 1 && p.codeUnitAt(0) >= 65 && p.codeUnitAt(0) <= 90) {
          _multiCorrectAnswers.add(p);
        }
      }
    }
    if (_multiCorrectAnswers.isEmpty) {
      _multiCorrectAnswers.add('A');
    }

    // True / False
    _tfCorrect = (q?.correctAnswer.toLowerCase() == 'false') ? 'False' : 'True';

    // Diagram / Image
    if (q != null && q.attachments.isNotEmpty) {
      final att = q.attachments.first;
      if (att is String) {
        _diagramImageUrl = att;
      } else if (att is Map && att['url'] != null) {
        _diagramImageUrl = att['url'].toString();
        _diagramImageName = att['name']?.toString();
      }
    }

    // Fill in Blanks
    if (q != null && q.options.isNotEmpty) {
      _blankControllers = q.options.map((opt) => TextEditingController(text: opt)).toList();
    } else {
      _blankControllers = [
        TextEditingController(text: (q != null && q.correctAnswer.isNotEmpty && !q.correctAnswer.contains(' ')) ? q.correctAnswer : '')
      ];
    }

    // Match the Following
    _matchPremiseControllers = [];
    _matchResponseControllers = [];
    _matchPairs = {};
    if (q != null && q.options.isNotEmpty) {
      List<String> premises = [];
      List<String> responses = [];
      for (final opt in q.options) {
        final trimmed = opt.trim();
        if (RegExp(r'^[1-9]\.').hasMatch(trimmed)) {
          premises.add(trimmed.substring(trimmed.indexOf('.') + 1).trim());
        } else if (RegExp(r'^[A-Z]\.').hasMatch(trimmed)) {
          responses.add(trimmed.substring(trimmed.indexOf('.') + 1).trim());
        }
      }
      if (premises.isNotEmpty && responses.isNotEmpty) {
        for (final p in premises) {
          _matchPremiseControllers.add(TextEditingController(text: p));
        }
        for (final r in responses) {
          _matchResponseControllers.add(TextEditingController(text: r));
        }
      }
    }
    if (_matchPremiseControllers.isEmpty) {
      _matchPremiseControllers = [
        TextEditingController(text: 'Item 1'),
        TextEditingController(text: 'Item 2'),
        TextEditingController(text: 'Item 3'),
        TextEditingController(text: 'Item 4'),
      ];
      _matchResponseControllers = [
        TextEditingController(text: 'Match A'),
        TextEditingController(text: 'Match B'),
        TextEditingController(text: 'Match C'),
        TextEditingController(text: 'Match D'),
      ];
    }
    if (q != null && q.correctAnswer.isNotEmpty) {
      final pairMatches = RegExp(r'([1-9])-([A-Z])').allMatches(q.correctAnswer.toUpperCase());
      for (final m in pairMatches) {
        final rowIdx = (int.tryParse(m.group(1)!) ?? 1) - 1;
        final rightLetter = m.group(2)!;
        _matchPairs[rowIdx] = rightLetter;
      }
    }
    for (int i = 0; i < _matchPremiseControllers.length; i++) {
      if (!_matchPairs.containsKey(i)) {
        _matchPairs[i] = String.fromCharCode(65 + (i % 26));
      }
    }

    // Assertion and Reason
    _assertionController = TextEditingController();
    _reasonController = TextEditingController();
    _arCorrect = (q != null && q.correctAnswer.length == 1 && 'ABCD'.contains(q.correctAnswer.toUpperCase()))
        ? q.correctAnswer.toUpperCase()
        : 'A';
    if (q != null && q.questionText.isNotEmpty) {
      final aMatch = RegExp(r'Assertion\s*\([A-Za-z]\)\s*:\s*(.*?)(?=\n\s*Reason|$)', dotAll: true).firstMatch(q.questionText);
      final rMatch = RegExp(r'Reason\s*\([A-Za-z]\)\s*:\s*(.*)', dotAll: true).firstMatch(q.questionText);
      if (aMatch != null) _assertionController.text = aMatch.group(1)?.trim() ?? '';
      if (rMatch != null) _reasonController.text = rMatch.group(1)?.trim() ?? '';
    }

    // Numerical
    _numericValueController = TextEditingController(text: q?.correctAnswer ?? '');
    _numericUnitController = TextEditingController();
    _numericToleranceController = TextEditingController(text: '± 0.1');

    if (q != null) {
      _selectedTags.addAll(q.tags);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _questionTextController.dispose();
    _topicController.dispose();
    _marksController.dispose();
    _negativeMarksController.dispose();
    _explanationController.dispose();
    _modelAnswerController.dispose();
    _codeController.dispose();
    for (var c in _optionControllers) {
      c.dispose();
    }
    for (var c in _blankControllers) {
      c.dispose();
    }
    for (var c in _matchPremiseControllers) {
      c.dispose();
    }
    for (var c in _matchResponseControllers) {
      c.dispose();
    }
    _assertionController.dispose();
    _reasonController.dispose();
    _numericValueController.dispose();
    _numericUnitController.dispose();
    _numericToleranceController.dispose();
    super.dispose();
  }

  void _insertMathSymbol(String symbol) {
    final text = _questionTextController.text;
    final selection = _questionTextController.selection;
    final newText = text.replaceRange(
      selection.start < 0 ? text.length : selection.start,
      selection.end < 0 ? text.length : selection.end,
      symbol,
    );
    _questionTextController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: (selection.start < 0 ? text.length : selection.start) + symbol.length,
      ),
    );
  }

  Future<void> _saveQuestion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      List<String>? optionsList;
      String finalCorrectAnswer = _correctAnswer;
      final rubricData = <String, dynamic>{};
      final attachmentsList = <dynamic>[];

      if (_diagramImageUrl != null && _diagramImageUrl!.isNotEmpty) {
        attachmentsList.add({
          'type': 'image',
          'url': _diagramImageUrl,
          'name': _diagramImageName ?? 'Diagram',
        });
      }

      switch (_normType) {
        case 'multi_select':
          optionsList = _optionControllers.map((c) => c.text.trim()).toList();
          final sorted = _multiCorrectAnswers.toList()..sort();
          finalCorrectAnswer = sorted.isNotEmpty ? sorted.join(', ') : 'A';
          break;

        case 'true_false':
          optionsList = ['True', 'False'];
          finalCorrectAnswer = _tfCorrect;
          break;

        case 'fill_blanks':
          optionsList = _blankControllers
              .map((c) => c.text.trim())
              .where((s) => s.isNotEmpty)
              .toList();
          finalCorrectAnswer = optionsList.isNotEmpty ? optionsList.first : (_blankControllers.isNotEmpty ? _blankControllers.first.text.trim() : '');
          break;

        case 'match_following':
          final premises = _matchPremiseControllers.asMap().entries.map((e) => '${e.key + 1}. ${e.value.text.trim()}').toList();
          final responses = _matchResponseControllers.asMap().entries.map((e) => '${String.fromCharCode(65 + e.key)}. ${e.value.text.trim()}').toList();
          optionsList = [...premises, ...responses];
          _updateMatchCorrectAnswer();
          finalCorrectAnswer = _correctAnswer;
          rubricData['pairs'] = _matchPairs.map((k, v) => MapEntry('${k + 1}', v));
          break;

        case 'assertion_reason':
          optionsList = [
            'Both (A) and (R) are true and (R) is the correct explanation of (A).',
            'Both (A) and (R) are true but (R) is NOT the correct explanation of (A).',
            '(A) is true but (R) is false.',
            '(A) is false but (R) is true.',
          ];
          finalCorrectAnswer = _arCorrect;
          rubricData['assertion'] = _assertionController.text.trim();
          rubricData['reason'] = _reasonController.text.trim();
          break;

        case 'diagram':
          if (_diagramAnswerFormat == 'mcq') {
            optionsList = _optionControllers.map((c) => c.text.trim()).toList();
            finalCorrectAnswer = _correctAnswer;
          } else if (_diagramAnswerFormat == 'multi_select') {
            optionsList = _optionControllers.map((c) => c.text.trim()).toList();
            final sorted = _multiCorrectAnswers.toList()..sort();
            finalCorrectAnswer = sorted.isNotEmpty ? sorted.join(', ') : 'A';
          } else {
            optionsList = null;
          }
          break;

        case 'numerical':
          optionsList = null;
          finalCorrectAnswer = _numericValueController.text.trim() +
              (_numericUnitController.text.trim().isNotEmpty ? ' ${_numericUnitController.text.trim()}' : '');
          rubricData['expected_value'] = _numericValueController.text.trim();
          rubricData['unit'] = _numericUnitController.text.trim();
          rubricData['tolerance'] = _numericToleranceController.text.trim();
          break;

        case 'mcq':
          optionsList = _optionControllers.map((c) => c.text.trim()).toList();
          finalCorrectAnswer = _correctAnswer;
          break;

        case 'case_study':
        case 'short_answer':
        case 'long_answer':
        case 'descriptive':
        default:
          optionsList = null;
          break;
      }

      final payload = {
        'title': _titleController.text.trim(),
        'question_text': _questionTextController.text.trim(),
        'class_name': _selectedClass,
        'subject': _selectedSubject,
        'chapter': _selectedChapter,
        'topic': _topicController.text.trim(),
        'question_type': _selectedType,
        'difficulty': _selectedDifficulty,
        'marks': int.tryParse(_marksController.text) ?? 1,
        'negative_marks': double.tryParse(_negativeMarksController.text) ?? 0.0,
        'explanation': _explanationController.text.trim(),
        'model_answer': _modelAnswerController.text.trim(),
        'status': _selectedStatus,
        'source_type': _selectedSource,
        'language_code': _selectedLanguage,
        'tags': _selectedTags.toList(),
        'options': optionsList,
        'correct_answer': finalCorrectAnswer,
        'rubric': rubricData,
        'attachments': attachmentsList,
        'question_code': _codeController.text.trim().isNotEmpty ? _codeController.text.trim() : null,
      };

      final QuestionBankItem savedQuestion;
      if (widget.question == null) {
        savedQuestion = await _apiService.addQuestionToBank(payload);
      } else {
        savedQuestion = await _apiService.updateQuestionInBank(widget.question!.id, payload);
      }

      widget.onQuestionSaved?.call(savedQuestion);
      widget.onSaved?.call();
      if (mounted) {
        Navigator.of(context).pop(savedQuestion);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.question == null ? 'Question created successfully!' : 'Question updated!'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save question: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  InputDecoration _editorInputDeco(String label, {String? hintText, bool isDark = false, bool alignLabel = false}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 13),
      hintText: hintText,
      hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), fontSize: 13),
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      alignLabelWithHint: alignLabel,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: Color(0xFF2563EB)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dialog Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.drive_file_rename_outline_rounded, color: Color(0xFF2563EB), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.question == null ? 'Create Question' : 'Edit Question (${widget.question!.questionCode})',
                            style: _font(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          ),
                          Text(
                            'Configure question statement, mathematical equations, rubric, and options.',
                            style: _font(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 20, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Step Tabs
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                ),
                child: Row(
                  children: [
                    _buildStepButton(0, '1. Basic Info', Icons.info_outline, isDark),
                    const SizedBox(width: 8),
                    _buildStepButton(1, '2. Question & Math', Icons.calculate_outlined, isDark),
                    const SizedBox(width: 8),
                    _buildStepButton(2, '3. Options & Rubric', Icons.grading_outlined, isDark),
                    const SizedBox(width: 8),
                    _buildStepButton(3, '4. Tags & Workflow', Icons.tune_outlined, isDark),
                  ],
                ),
              ),

              // Tab Content Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: IndexedStack(
                    index: _selectedTabIndex,
                    children: [
                      _buildBasicInfoTab(isDark),
                      _buildRichContentTab(isDark),
                      _buildOptionsRubricTab(isDark),
                      _buildWorkflowTab(isDark),
                    ],
                  ),
                ),
              ),

              // Dialog Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Cancel', style: _font(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                    ),
                    Row(
                      children: [
                        if (_selectedTabIndex > 0)
                          OutlinedButton(
                            onPressed: () => setState(() => _selectedTabIndex--),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Back'),
                          ),
                        const SizedBox(width: 10),
                        if (_selectedTabIndex < 3)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => setState(() => _selectedTabIndex++),
                            child: const Text('Next Step', style: TextStyle(color: Colors.white)),
                          )
                        else
                          ElevatedButton.icon(
                            icon: _isSaving
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.check, size: 18, color: Colors.white),
                            label: Text(
                              _isSaving ? 'Saving...' : 'Save Question',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _isSaving ? null : _saveQuestion,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepButton(int index, String label, IconData icon, bool isDark) {
    final isSelected = _selectedTabIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedTabIndex = index),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB).withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
            const SizedBox(width: 6),
            Text(
              label,
              style: _font(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Step 1: Basic Info
  Widget _buildBasicInfoTab(bool isDark) {
    // 1. Class List deduplication & fallback
    final classList = widget.classes.map((c) => c.trim()).where((c) => c.isNotEmpty).toSet().toList();
    if (classList.isEmpty) {
      classList.addAll(['Class 6', 'Class 7', 'Class 8', 'Class 9', 'Class 10', 'Class 11', 'Class 12']);
    }
    if (_selectedClass != null && _selectedClass!.isNotEmpty && !classList.contains(_selectedClass)) {
      classList.insert(0, _selectedClass!);
    }
    final classValue = (_selectedClass != null && classList.contains(_selectedClass))
        ? _selectedClass
        : classList.first;

    // 2. Subject List deduplication & fallback (solves duplicate "Mathematics" assertion error)
    final subjectList = widget.subjects.map((s) => s.name.trim()).where((n) => n.isNotEmpty).toSet().toList();
    if (subjectList.isEmpty) {
      subjectList.addAll(['Mathematics', 'Science', 'English', 'Social Science', 'Physics', 'Chemistry', 'Biology']);
    }
    if (_selectedSubject != null && _selectedSubject!.isNotEmpty && !subjectList.contains(_selectedSubject)) {
      subjectList.insert(0, _selectedSubject!);
    }
    final subjectValue = (_selectedSubject != null && subjectList.contains(_selectedSubject))
        ? _selectedSubject
        : subjectList.first;

    // 3. Question Type map deduplication & fallback
    final typeMap = <String, String>{};
    for (final t in widget.lookupTypes) {
      final code = t.code.toLowerCase().trim();
      if (code.isNotEmpty) {
        typeMap[code] = t.name;
      }
    }
    if (typeMap.isEmpty) {
      typeMap['mcq'] = 'Multiple Choice';
      typeMap['short_answer'] = 'Short Answer';
      typeMap['long_answer'] = 'Long Answer';
      typeMap['true_false'] = 'True / False';
      typeMap['fill_blank'] = 'Fill in the Blank';
    }
    if (_selectedType != null && _selectedType!.isNotEmpty && !typeMap.containsKey(_selectedType)) {
      typeMap[_selectedType!] = _selectedType!.toUpperCase();
    }
    final typeValue = (_selectedType != null && typeMap.containsKey(_selectedType))
        ? _selectedType
        : typeMap.keys.first;

    // 4. Difficulty List deduplication & fallback
    final diffList = widget.lookupDifficulties.map((d) => d.name.trim()).where((n) => n.isNotEmpty).toSet().toList();
    if (diffList.isEmpty) {
      diffList.addAll(['Easy', 'Medium', 'Hard']);
    }
    if (_selectedDifficulty != null && _selectedDifficulty!.isNotEmpty && !diffList.contains(_selectedDifficulty)) {
      diffList.insert(0, _selectedDifficulty!);
    }
    final diffValue = (_selectedDifficulty != null && diffList.contains(_selectedDifficulty))
        ? _selectedDifficulty
        : diffList.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: classValue,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                decoration: _editorInputDeco('Class *', isDark: isDark),
                items: classList.map((c) => DropdownMenuItem(value: c, child: Text(c, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A))))).toList(),
                onChanged: (val) => setState(() => _selectedClass = val),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: subjectValue,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                decoration: _editorInputDeco('Subject *', isDark: isDark),
                items: subjectList.map((s) => DropdownMenuItem(value: s, child: Text(s, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A))))).toList(),
                onChanged: (val) => setState(() => _selectedSubject = val),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: _selectedChapter,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                decoration: _editorInputDeco('Chapter *', isDark: isDark),
                onChanged: (v) => _selectedChapter = v,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextFormField(
                controller: _topicController,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                decoration: _editorInputDeco('Topic / Sub-topic (Optional)', isDark: isDark),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: typeValue,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                decoration: _editorInputDeco('Question Type *', isDark: isDark),
                items: typeMap.entries.map((t) {
                  return DropdownMenuItem(
                    value: t.key,
                    child: Text(t.value, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A))),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedType = val;
                    if (_normType == 'multi_select') {
                      if (_multiCorrectAnswers.isEmpty) {
                        _multiCorrectAnswers.add('A');
                      }
                      final sorted = _multiCorrectAnswers.toList()..sort();
                      _correctAnswer = sorted.join(', ');
                    } else if (_normType == 'true_false') {
                      _correctAnswer = _tfCorrect;
                    } else if (_normType == 'assertion_reason') {
                      _correctAnswer = _arCorrect;
                    } else if (_normType == 'match_following') {
                      _updateMatchCorrectAnswer();
                    } else if (_normType == 'mcq') {
                      if (_correctAnswer.isEmpty || _correctAnswer.contains(',')) {
                        _correctAnswer = 'A';
                      }
                    }
                  });
                },
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: diffValue,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                decoration: _editorInputDeco('Difficulty Level *', isDark: isDark),
                items: diffList.map((d) {
                  return DropdownMenuItem(
                    value: d,
                    child: Text(d, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A))),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedDifficulty = val),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _marksController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                decoration: _editorInputDeco('Marks *', isDark: isDark),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextFormField(
                controller: _negativeMarksController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                decoration: _editorInputDeco('Negative Marks (e.g. 0.25)', isDark: isDark),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Diagram Image Upload Component with Live Preview & File Picker
  Widget _buildDiagramImageUploadSection(bool isDark) {
    final hasImage = (_diagramImageBytes != null) || (_diagramImageUrl != null && _diagramImageUrl!.isNotEmpty);

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _normType == 'diagram'
              ? const Color(0xFF2563EB).withValues(alpha: 0.6)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: _normType == 'diagram' ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.image_outlined, color: Color(0xFF2563EB), size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _normType == 'diagram' ? 'Diagram / Image Illustration *' : 'Attach Diagram / Figure (Optional)',
                      style: _font(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                    Text(
                      'Upload diagram image or paste an image URL for this question.',
                      style: _font(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              if (_isUploadingImage)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (!hasImage) ...[
            InkWell(
              onTap: _isUploadingImage ? null : _pickDiagramImage,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_upload_outlined, size: 36, color: Color(0xFF2563EB)),
                    const SizedBox(height: 8),
                    Text(
                      'Click to Choose Diagram Image from Device',
                      style: _font(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF2563EB)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'PNG, JPG, JPEG, WEBP or SVG (Max 10 MB)',
                      style: _font(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _diagramImageUrl ?? '',
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Or paste image URL (e.g. https://.../diagram.png)',
                      hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), fontSize: 12),
                      isDense: true,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _diagramImageUrl = val.trim().isNotEmpty ? val.trim() : null;
                      });
                    },
                  ),
                ),
              ],
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: _diagramImageBytes != null
                          ? Image.memory(
                              _diagramImageBytes!,
                              height: 160,
                              fit: BoxFit.contain,
                            )
                          : Image.network(
                              _diagramImageUrl!,
                              height: 160,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Container(
                                height: 100,
                                alignment: Alignment.center,
                                child: Text('Image preview unavailable', style: _font(fontSize: 12, color: Colors.grey)),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            _diagramImageName ?? 'Diagram attached',
                            style: _font(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF16A34A)),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.refresh, size: 14),
                            label: const Text('Replace'),
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                            onPressed: _pickDiagramImage,
                          ),
                          const SizedBox(width: 4),
                          TextButton.icon(
                            icon: const Icon(Icons.delete_outline, size: 14, color: Colors.red),
                            label: const Text('Remove', style: TextStyle(color: Colors.red)),
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                            onPressed: () {
                              setState(() {
                                _diagramImageUrl = null;
                                _diagramImageBytes = null;
                                _diagramImageName = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Step 2: Rich Question Content with Math Toolbar
  Widget _buildRichContentTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _titleController,
          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
          decoration: _editorInputDeco(
            'Question Title / Header (Optional)',
            hintText: 'e.g. Area of Circle Calculation Theorem',
            isDark: isDark,
          ),
        ),
        const SizedBox(height: 14),

        Text(
          'Insert Math / Scientific Notation:',
          style: _font(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            'x²', 'x³', 'xⁿ', 'x₁', '√', 'π', 'θ', '±', '≠', '≤', '≥', '∑', '∆', '∫', '÷', '×', '½', '¼', '°'
          ].map((sym) {
            return InkWell(
              onTap: () => _insertMathSymbol(sym),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: Text(sym, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A))),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),

        TextFormField(
          controller: _questionTextController,
          maxLines: 5,
          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
          decoration: _editorInputDeco(
            'Question Statement *',
            hintText: 'Type question text or equations. e.g. Solve: x² - 5x + 6 = 0',
            isDark: isDark,
            alignLabel: true,
          ),
          validator: (v) => v == null || v.trim().isEmpty ? 'Question text is required' : null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),

        // Live Rendered Preview
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Live Rendered Preview:',
                style: _font(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB)),
              ),
              const SizedBox(height: 4),
              Text(
                _QuestionBankScreenState._formatMathFormula(
                  _questionTextController.text.isEmpty
                      ? 'Question preview will appear here...'
                      : _questionTextController.text,
                ),
                style: _font(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),

        // Diagram/Image Uploader Section in Tab 2
        _buildDiagramImageUploadSection(isDark),
      ],
    );
  }

  // Step 3: Options & Solution Rubric (Type-Aware Dispatcher)
  Widget _buildOptionsRubricTab(bool isDark) {
    switch (_normType) {
      case 'multi_select':
        return _buildMultiSelectOptionsTab(isDark);
      case 'true_false':
        return _buildTrueFalseTab(isDark);
      case 'fill_blanks':
        return _buildFillBlanksTab(isDark);
      case 'match_following':
        return _buildMatchFollowingTab(isDark);
      case 'assertion_reason':
        return _buildAssertionReasonTab(isDark);
      case 'diagram':
        return _buildDiagramTab(isDark);
      case 'numerical':
        return _buildNumericalTab(isDark);
      case 'case_study':
      case 'short_answer':
      case 'long_answer':
      case 'descriptive':
      case 'practical':
        return _buildDescriptiveRubricTab(isDark);
      case 'mcq':
      default:
        return _buildMcqSingleSelectTab(isDark);
    }
  }

  // 3.1 Multiple Choice Single Select Tab
  Widget _buildMcqSingleSelectTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Multiple Choice Single Select Options',
                  style: _font(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
                Text(
                  'Select the radio button next to the option to mark it as the single correct answer.',
                  style: _font(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ],
            ),
            if (_optionControllers.length < 8)
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Option'),
                onPressed: () {
                  setState(() {
                    _optionControllers.add(TextEditingController(text: ''));
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.radio_button_checked, size: 16, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Text(
                'Selected Correct Answer: ',
                style: _font(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1E40AF)),
              ),
              Text(
                'Option $_correctAnswer',
                style: _font(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF16A34A)),
              ),
            ],
          ),
        ),

        ...List.generate(_optionControllers.length, (i) {
          final optLetter = String.fromCharCode(65 + i);

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                InkWell(
                  onTap: () => setState(() => _correctAnswer = optLetter),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Icon(
                      _correctAnswer.toUpperCase() == optLetter
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: _correctAnswer.toUpperCase() == optLetter
                          ? const Color(0xFF2563EB)
                          : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                      size: 20,
                    ),
                  ),
                ),
                Text('$optLetter. ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                Expanded(
                  child: TextFormField(
                    controller: _optionControllers[i],
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                      focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(6)), borderSide: BorderSide(color: Color(0xFF2563EB))),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Option cannot be empty' : null,
                  ),
                ),
                if (_optionControllers.length > 2)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                    onPressed: () {
                      setState(() {
                        _optionControllers.removeAt(i);
                        if (_correctAnswer == optLetter) _correctAnswer = 'A';
                      });
                    },
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: 14),

        TextFormField(
          controller: _explanationController,
          maxLines: 3,
          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
          decoration: _editorInputDeco(
            'Explanation / Conceptual Hint (Optional)',
            isDark: isDark,
            alignLabel: true,
          ),
        ),
      ],
    );
  }

  // 3.2 Multi-Select Multiple Choice Tab (Checkboxes)
  Widget _buildMultiSelectOptionsTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Multi-Select Options (Checkboxes)',
                  style: _font(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
                Text(
                  'Check all options that represent correct answers. Multiple choices allowed.',
                  style: _font(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ],
            ),
            if (_optionControllers.length < 8)
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Option'),
                onPressed: () {
                  setState(() {
                    _optionControllers.add(TextEditingController(text: ''));
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: 10),

        // Status banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF4F46E5)),
              const SizedBox(width: 8),
              Text(
                'Correct Answer(s): ',
                style: _font(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF3730A3)),
              ),
              Expanded(
                child: Text(
                  _multiCorrectAnswers.isEmpty
                      ? 'None selected (Please check at least one below)'
                      : (_multiCorrectAnswers.toList()..sort()).join(', '),
                  style: _font(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _multiCorrectAnswers.isEmpty ? Colors.red : const Color(0xFF16A34A),
                  ),
                ),
              ),
            ],
          ),
        ),

        ...List.generate(_optionControllers.length, (i) {
          final optLetter = String.fromCharCode(65 + i);
          final isChecked = _multiCorrectAnswers.contains(optLetter);

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      if (_multiCorrectAnswers.contains(optLetter)) {
                        if (_multiCorrectAnswers.length > 1) {
                          _multiCorrectAnswers.remove(optLetter);
                        }
                      } else {
                        _multiCorrectAnswers.add(optLetter);
                      }
                      final sorted = _multiCorrectAnswers.toList()..sort();
                      _correctAnswer = sorted.join(', ');
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Icon(
                      isChecked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                      color: isChecked ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                      size: 22,
                    ),
                  ),
                ),
                Text('$optLetter. ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                Expanded(
                  child: TextFormField(
                    controller: _optionControllers[i],
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                      focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(6)), borderSide: BorderSide(color: Color(0xFF2563EB))),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Option cannot be empty' : null,
                  ),
                ),
                if (_optionControllers.length > 2)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                    onPressed: () {
                      setState(() {
                        _optionControllers.removeAt(i);
                        _multiCorrectAnswers.remove(optLetter);
                        if (_multiCorrectAnswers.isEmpty) _multiCorrectAnswers.add('A');
                        final sorted = _multiCorrectAnswers.toList()..sort();
                        _correctAnswer = sorted.join(', ');
                      });
                    },
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: 14),

        TextFormField(
          controller: _explanationController,
          maxLines: 3,
          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
          decoration: _editorInputDeco(
            'Explanation / Conceptual Hint (Optional)',
            isDark: isDark,
            alignLabel: true,
          ),
        ),
      ],
    );
  }

  // 3.3 True / False Tab
  Widget _buildTrueFalseTab(bool isDark) {
    final isTrue = _tfCorrect == 'True';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'True / False Configuration',
          style: _font(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
        ),
        Text(
          'Select which statement is correct for the question.',
          style: _font(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => setState(() {
                  _tfCorrect = 'True';
                  _correctAnswer = 'True';
                }),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isTrue
                        ? const Color(0xFF16A34A).withValues(alpha: 0.12)
                        : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isTrue
                          ? const Color(0xFF16A34A)
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      width: isTrue ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isTrue ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: isTrue ? const Color(0xFF16A34A) : Colors.grey,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'TRUE',
                        style: _font(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isTrue ? const Color(0xFF16A34A) : (isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: InkWell(
                onTap: () => setState(() {
                  _tfCorrect = 'False';
                  _correctAnswer = 'False';
                }),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  decoration: BoxDecoration(
                    color: !isTrue
                        ? const Color(0xFFDC2626).withValues(alpha: 0.12)
                        : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: !isTrue
                          ? const Color(0xFFDC2626)
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      width: !isTrue ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        !isTrue ? Icons.cancel : Icons.radio_button_unchecked,
                        color: !isTrue ? const Color(0xFFDC2626) : Colors.grey,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'FALSE',
                        style: _font(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: !isTrue ? const Color(0xFFDC2626) : (isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _explanationController,
          maxLines: 3,
          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
          decoration: _editorInputDeco(
            'Explanation / Conceptual Hint (Optional)',
            isDark: isDark,
            alignLabel: true,
          ),
        ),
      ],
    );
  }

  // 3.4 Fill in the Blanks Tab
  Widget _buildFillBlanksTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fill in the Blanks Configuration',
                  style: _font(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
                Text(
                  'Define primary correct blank answer and any alternate acceptable spellings.',
                  style: _font(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ],
            ),
            if (_blankControllers.length < 5)
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Alternate Answer'),
                onPressed: () {
                  setState(() {
                    _blankControllers.add(TextEditingController(text: ''));
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tip: Write "[___]" in Tab 2 (Question Statement) where the blank should be located.',
                  style: _font(fontSize: 12, color: const Color(0xFF1E40AF)),
                ),
              ),
            ],
          ),
        ),

        ...List.generate(_blankControllers.length, (i) {
          final isPrimary = i == 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 90,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    isPrimary ? 'Primary *' : 'Alternate $i:',
                    style: _font(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isPrimary ? const Color(0xFF16A34A) : (isDark ? Colors.white70 : const Color(0xFF475569)),
                    ),
                  ),
                ),
                Expanded(
                  child: TextFormField(
                    controller: _blankControllers[i],
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                    decoration: _editorInputDeco(
                      isPrimary ? 'Primary Correct Value *' : 'Alternate Acceptable Value',
                      hintText: isPrimary ? 'e.g. Mitochondria' : 'e.g. mitochondrion',
                      isDark: isDark,
                    ),
                    validator: isPrimary ? (v) => v == null || v.trim().isEmpty ? 'Primary answer is required' : null : null,
                    onChanged: (v) {
                      if (isPrimary) {
                        setState(() => _correctAnswer = v.trim());
                      }
                    },
                  ),
                ),
                if (!isPrimary)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                    onPressed: () {
                      setState(() {
                        _blankControllers.removeAt(i);
                      });
                    },
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: 14),

        TextFormField(
          controller: _explanationController,
          maxLines: 3,
          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
          decoration: _editorInputDeco(
            'Explanation / Conceptual Hint (Optional)',
            isDark: isDark,
            alignLabel: true,
          ),
        ),
      ],
    );
  }

  // 3.5 Match the Following Tab
  Widget _buildMatchFollowingTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Match the Following Configuration',
                  style: _font(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
                Text(
                  'Specify Column A (Left) and Column B (Right) items, then set matching pairs.',
                  style: _font(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ],
            ),
            if (_matchPremiseControllers.length < 6)
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Pair Row'),
                onPressed: () {
                  setState(() {
                    final nextIdx = _matchPremiseControllers.length;
                    _matchPremiseControllers.add(TextEditingController(text: 'Item ${nextIdx + 1}'));
                    _matchResponseControllers.add(TextEditingController(text: 'Match ${String.fromCharCode(65 + nextIdx)}'));
                    _matchPairs[nextIdx] = String.fromCharCode(65 + nextIdx);
                    _updateMatchCorrectAnswer();
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: 10),

        // Summary badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF3E8FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.compare_arrows_rounded, size: 16, color: Color(0xFF7C3AED)),
              const SizedBox(width: 8),
              Text(
                'Correct Match Sequence: ',
                style: _font(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF5B21B6)),
              ),
              Expanded(
                child: Text(
                  _correctAnswer,
                  style: _font(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF7C3AED)),
                ),
              ),
            ],
          ),
        ),

        // Header Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Text('Column A (Premises)', style: _font(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : const Color(0xFF475569))),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: Text('Column B (Responses)', style: _font(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : const Color(0xFF475569))),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: Text('Match With', style: _font(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : const Color(0xFF475569))),
              ),
              if (_matchPremiseControllers.length > 2) const SizedBox(width: 36),
            ],
          ),
        ),
        const SizedBox(height: 6),

        ...List.generate(_matchPremiseControllers.length, (i) {
          final rowNum = i + 1;
          final rightLetter = String.fromCharCode(65 + i);

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: TextFormField(
                    controller: _matchPremiseControllers[i],
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                    decoration: InputDecoration(
                      prefixText: '$rowNum. ',
                      prefixStyle: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      isDense: true,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: TextFormField(
                    controller: _matchResponseControllers[i],
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                    decoration: InputDecoration(
                      prefixText: '$rightLetter. ',
                      prefixStyle: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      isDense: true,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: DropdownButtonFormField<String>(
                    initialValue: _matchPairs[i] ?? rightLetter,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    items: List.generate(_matchResponseControllers.length, (idx) {
                      final letter = String.fromCharCode(65 + idx);
                      return DropdownMenuItem(value: letter, child: Text('-> $letter'));
                    }),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _matchPairs[i] = val;
                          _updateMatchCorrectAnswer();
                        });
                      }
                    },
                  ),
                ),
                if (_matchPremiseControllers.length > 2)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                    onPressed: () {
                      setState(() {
                        _matchPremiseControllers.removeAt(i);
                        _matchResponseControllers.removeAt(i);
                        _matchPairs.remove(i);
                        _updateMatchCorrectAnswer();
                      });
                    },
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: 14),

        TextFormField(
          controller: _explanationController,
          maxLines: 3,
          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
          decoration: _editorInputDeco(
            'Explanation / Conceptual Hint (Optional)',
            isDark: isDark,
            alignLabel: true,
          ),
        ),
      ],
    );
  }

  // 3.6 Assertion & Reason Tab
  Widget _buildAssertionReasonTab(bool isDark) {
    const choices = [
      {'code': 'A', 'text': 'Both (A) and (R) are true and (R) is the correct explanation of (A).'},
      {'code': 'B', 'text': 'Both (A) and (R) are true but (R) is NOT the correct explanation of (A).'},
      {'code': 'C', 'text': '(A) is true but (R) is false.'},
      {'code': 'D', 'text': '(A) is false but (R) is true.'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Assertion and Reason Statements',
          style: _font(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
        ),
        Text(
          'Input Assertion (A) and Reason (R), then select the correct multiple choice evaluation.',
          style: _font(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        ),
        const SizedBox(height: 12),

        TextFormField(
          controller: _assertionController,
          maxLines: 2,
          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
          decoration: _editorInputDeco('Assertion (A) *', hintText: 'State the assertion proposition...', isDark: isDark, alignLabel: true),
          onChanged: (_) {
            if (_questionTextController.text.isEmpty || _questionTextController.text.startsWith('Assertion (A):')) {
              _questionTextController.text = 'Assertion (A): ${_assertionController.text}\nReason (R): ${_reasonController.text}';
            }
          },
        ),
        const SizedBox(height: 10),

        TextFormField(
          controller: _reasonController,
          maxLines: 2,
          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
          decoration: _editorInputDeco('Reason (R) *', hintText: 'State the reasoning or explanation...', isDark: isDark, alignLabel: true),
          onChanged: (_) {
            if (_questionTextController.text.isEmpty || _questionTextController.text.startsWith('Assertion (A):')) {
              _questionTextController.text = 'Assertion (A): ${_assertionController.text}\nReason (R): ${_reasonController.text}';
            }
          },
        ),
        const SizedBox(height: 14),

        Text(
          'Standard Evaluation Choices (Select radio for correct answer):',
          style: _font(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
        ),
        const SizedBox(height: 8),

        ...choices.map((c) {
          final code = c['code']!;
          final isSelected = _arCorrect == code;

          return InkWell(
            onTap: () => setState(() {
              _arCorrect = code;
              _correctAnswer = code;
            }),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFEFF6FF)
                    : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF2563EB)
                      : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$code. ',
                    style: _font(fontSize: 13, fontWeight: FontWeight.w700, color: isSelected ? const Color(0xFF2563EB) : (isDark ? Colors.white : const Color(0xFF0F172A))),
                  ),
                  Expanded(
                    child: Text(
                      c['text']!,
                      style: _font(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? const Color(0xFF1E293B) : (isDark ? Colors.white70 : const Color(0xFF334155)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 12),

        TextFormField(
          controller: _explanationController,
          maxLines: 3,
          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
          decoration: _editorInputDeco(
            'Explanation / Conceptual Hint (Optional)',
            isDark: isDark,
            alignLabel: true,
          ),
        ),
      ],
    );
  }

  // 3.7 Diagram / Image Based Tab
  Widget _buildDiagramTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDiagramImageUploadSection(isDark),
        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Student Response Mode:',
              style: _font(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Single Select (MCQ)'),
                  selected: _diagramAnswerFormat == 'mcq',
                  onSelected: (sel) {
                    if (sel) setState(() => _diagramAnswerFormat = 'mcq');
                  },
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Multi-Select'),
                  selected: _diagramAnswerFormat == 'multi_select',
                  onSelected: (sel) {
                    if (sel) setState(() => _diagramAnswerFormat = 'multi_select');
                  },
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Descriptive'),
                  selected: _diagramAnswerFormat == 'descriptive',
                  onSelected: (sel) {
                    if (sel) setState(() => _diagramAnswerFormat = 'descriptive');
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (_diagramAnswerFormat == 'mcq')
          _buildMcqSingleSelectTab(isDark)
        else if (_diagramAnswerFormat == 'multi_select')
          _buildMultiSelectOptionsTab(isDark)
        else
          _buildDescriptiveRubricTab(isDark),
      ],
    );
  }

  // 3.8 Numerical Problem Tab
  Widget _buildNumericalTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Numerical Problem Configuration',
          style: _font(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
        ),
        Text(
          'Enter the exact numeric value, measurement unit, and acceptable tolerance percentage/range.',
          style: _font(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              flex: 4,
              child: TextFormField(
                controller: _numericValueController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                decoration: _editorInputDeco('Expected Numeric Value *', hintText: 'e.g. 9.8 or 3.14', isDark: isDark),
                validator: (v) => v == null || v.trim().isEmpty ? 'Numeric value is required' : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _numericUnitController,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                decoration: _editorInputDeco('Unit (Optional)', hintText: 'e.g. m/s², cm, kg', isDark: isDark),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _numericToleranceController,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                decoration: _editorInputDeco('Tolerance', hintText: 'e.g. ± 0.1 or ± 1%', isDark: isDark),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        TextFormField(
          controller: _modelAnswerController,
          maxLines: 4,
          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
          decoration: _editorInputDeco(
            'Full Derivation & Calculation Steps *',
            hintText: 'e.g. Formula: F = ma. Given m=2kg, a=4.9m/s². F = 2 * 4.9 = 9.8 N',
            isDark: isDark,
            alignLabel: true,
          ),
          validator: (v) => v == null || v.trim().isEmpty ? 'Calculation derivation is required' : null,
        ),
        const SizedBox(height: 14),

        TextFormField(
          controller: _explanationController,
          maxLines: 3,
          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
          decoration: _editorInputDeco(
            'Marking Rubric / Step Distribution',
            hintText: 'e.g. Formula: 1 Mark, Calculation: 2 Marks, Final Unit: 1 Mark',
            isDark: isDark,
            alignLabel: true,
          ),
        ),
      ],
    );
  }

  // 3.9 Descriptive / Essay / Practical Rubric Tab
  Widget _buildDescriptiveRubricTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Model Answer & Step-wise Marking Rubric',
          style: _font(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
        ),
        Text(
          'Provide the comprehensive answer, derivations, theorem proof, or rubric points.',
          style: _font(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        ),
        const SizedBox(height: 12),

        TextFormField(
          controller: _modelAnswerController,
          maxLines: 5,
          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
          decoration: _editorInputDeco(
            'Model Answer / Step-wise Solution *',
            hintText: 'Provide complete derivation, solution steps, key concepts or essay points.',
            isDark: isDark,
            alignLabel: true,
          ),
          validator: (v) => v == null || v.trim().isEmpty ? 'Model answer is required' : null,
        ),
        const SizedBox(height: 14),

        TextFormField(
          controller: _explanationController,
          maxLines: 3,
          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
          decoration: _editorInputDeco(
            'Marking Rubric / Step-wise Scoring Distribution',
            hintText: 'e.g. Definition: 1 Mark, Key Points: 2 Marks, Diagram: 2 Marks',
            isDark: isDark,
            alignLabel: true,
          ),
        ),
      ],
    );
  }

  // Step 4: Metadata, Tags & Status Workflow
  Widget _buildWorkflowTab(bool isDark) {
    // 1. Status Map deduplication & fallback
    final statusMap = <String, String>{};
    for (final s in widget.lookupStatuses) {
      final code = s.name.toLowerCase().replaceAll(' ', '_').trim();
      if (code.isNotEmpty) {
        statusMap[code] = s.name;
      }
    }
    if (statusMap.isEmpty) {
      statusMap['approved'] = 'Approved';
      statusMap['draft'] = 'Draft';
      statusMap['pending_review'] = 'Pending Review';
    }
    if (_selectedStatus != null && _selectedStatus!.isNotEmpty && !statusMap.containsKey(_selectedStatus)) {
      statusMap[_selectedStatus!] = _selectedStatus!;
    }
    final statusValue = (_selectedStatus != null && statusMap.containsKey(_selectedStatus))
        ? _selectedStatus
        : statusMap.keys.first;

    // 2. Language Map deduplication & fallback
    final langMap = <String, String>{};
    for (final l in widget.lookupLanguages) {
      final code = l.code.toLowerCase().trim();
      if (code.isNotEmpty) {
        langMap[code] = l.name;
      }
    }
    if (langMap.isEmpty) {
      langMap['en'] = 'English';
      langMap['hi'] = 'Hindi';
    }
    if (_selectedLanguage != null && _selectedLanguage!.isNotEmpty && !langMap.containsKey(_selectedLanguage)) {
      langMap[_selectedLanguage!] = _selectedLanguage!;
    }
    final langValue = (_selectedLanguage != null && langMap.containsKey(_selectedLanguage))
        ? _selectedLanguage
        : langMap.keys.first;

    // 3. Source Map deduplication & fallback
    final sourceMap = <String, String>{};
    for (final s in widget.lookupSources) {
      final code = s.code.toLowerCase().trim();
      if (code.isNotEmpty) {
        sourceMap[code] = s.name;
      }
    }
    if (sourceMap.isEmpty) {
      sourceMap['teacher_created'] = 'Teacher Created';
      sourceMap['curriculum_standard'] = 'Curriculum Standard';
      sourceMap['external_imported'] = 'External Imported';
    }
    if (_selectedSource != null && _selectedSource!.isNotEmpty && !sourceMap.containsKey(_selectedSource)) {
      sourceMap[_selectedSource!] = _selectedSource!;
    }
    final sourceValue = (_selectedSource != null && sourceMap.containsKey(_selectedSource))
        ? _selectedSource
        : sourceMap.keys.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: statusValue,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                decoration: _editorInputDeco('Moderation Status *', isDark: isDark),
                items: statusMap.entries.map((entry) {
                  return DropdownMenuItem(value: entry.key, child: Text(entry.value, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A))));
                }).toList(),
                onChanged: (val) => setState(() => _selectedStatus = val),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: langValue,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                decoration: _editorInputDeco('Instructional Language', isDark: isDark),
                items: langMap.entries.map((entry) {
                  return DropdownMenuItem(value: entry.key, child: Text(entry.value, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A))));
                }).toList(),
                onChanged: (val) => setState(() => _selectedLanguage = val),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: sourceValue,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                decoration: _editorInputDeco('Question Provenance / Source', isDark: isDark),
                items: sourceMap.entries.map((entry) {
                  return DropdownMenuItem(value: entry.key, child: Text(entry.value, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A))));
                }).toList(),
                onChanged: (val) => setState(() => _selectedSource = val),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextFormField(
                controller: _codeController,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                decoration: _editorInputDeco(
                  'Internal Reference Code',
                  hintText: 'e.g. QB-MATH-101',
                  isDark: isDark,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Text(
          'Pedagogical Tags (From Lookup Key Values):',
          style: _font(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.lookupTags.map((tag) {
            final isChecked = _selectedTags.contains(tag.name);
            return FilterChip(
              label: Text(tag.name),
              selected: isChecked,
              backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              selectedColor: isDark ? const Color(0xFF2563EB).withValues(alpha: 0.25) : const Color(0xFFEFF6FF),
              checkmarkColor: const Color(0xFF2563EB),
              labelStyle: TextStyle(
                fontSize: 12,
                color: isDark ? (isChecked ? const Color(0xFF93C5FD) : const Color(0xFFCBD5E1)) : (isChecked ? const Color(0xFF1E40AF) : const Color(0xFF334155)),
                fontWeight: isChecked ? FontWeight.w600 : FontWeight.w500,
              ),
              side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              onSelected: (val) {
                setState(() {
                  if (val) {
                    _selectedTags.add(tag.name);
                  } else {
                    _selectedTags.remove(tag.name);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ============================================================================
// COMPONENT: IMPORT QUESTIONS DIALOG
// ============================================================================

class _QuestionImportDialog extends StatefulWidget {
  final List<TeacherSubject> subjects;
  final VoidCallback onImportSuccess;

  const _QuestionImportDialog({required this.subjects, required this.onImportSuccess});

  @override
  State<_QuestionImportDialog> createState() => _QuestionImportDialogState();
}

class _QuestionImportDialogState extends State<_QuestionImportDialog> {
  final ExamsApiService _apiService = ExamsApiService.instance;
  String? _selectedSubject;
  String? _fileName;
  String? _fileContent;
  bool _isUploading = false;
  String? _uploadError;

  @override
  void initState() {
    super.initState();
    if (widget.subjects.isNotEmpty) {
      _selectedSubject = widget.subjects.first.name;
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;
        if (bytes != null) {
          final content = utf8.decode(bytes);
          setState(() {
            _fileName = file.name;
            _fileContent = content;
            _uploadError = null;
          });
        }
      }
    } catch (e) {
      setState(() => _uploadError = 'Error picking file: $e');
    }
  }

  Future<void> _submitBulkUpload() async {
    if (_fileContent == null || _selectedSubject == null) return;

    setState(() => _isUploading = true);
    try {
      final count = await _apiService.bulkUploadQuestions(
        _fileContent!,
        _selectedSubject!,
        'mcq',
      );

      widget.onImportSuccess();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully imported $count question(s)!'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _uploadError = e.toString();
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.upload_file_outlined, color: Color(0xFF2563EB)),
          ),
          const SizedBox(width: 12),
          Text(
            'Import Questions from CSV',
            style: _font(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Builder(
              builder: (context) {
                final importSubjectList = widget.subjects.map((s) => s.name.trim()).where((n) => n.isNotEmpty).toSet().toList();
                if (importSubjectList.isEmpty) {
                  importSubjectList.addAll(['Mathematics', 'Science', 'English', 'Social Science', 'Physics', 'Chemistry', 'Biology']);
                }
                if (_selectedSubject != null && _selectedSubject!.isNotEmpty && !importSubjectList.contains(_selectedSubject)) {
                  importSubjectList.insert(0, _selectedSubject!);
                }
                final importSubjectValue = (_selectedSubject != null && importSubjectList.contains(_selectedSubject))
                    ? _selectedSubject
                    : importSubjectList.first;

                return DropdownButtonFormField<String>(
                  initialValue: importSubjectValue,
                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    labelText: 'Target Subject',
                    labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                  ),
                  items: importSubjectList.map((s) => DropdownMenuItem(value: s, child: Text(s, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A))))).toList(),
                  onChanged: (val) => setState(() => _selectedSubject = val),
                );
              },
            ),
            const SizedBox(height: 14),

            InkWell(
              onTap: _pickFile,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1), style: BorderStyle.solid),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_upload_outlined, size: 36, color: Color(0xFF2563EB)),
                    const SizedBox(height: 8),
                    Text(
                      _fileName ?? 'Click to select CSV file from your device',
                      style: _font(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _fileName != null ? (isDark ? Colors.white : const Color(0xFF0F172A)) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Columns required: question_text, question_type, options, correct_answer, difficulty, marks',
                      textAlign: TextAlign.center,
                      style: _font(fontSize: 11, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ),

            if (_uploadError != null) ...[
              const SizedBox(height: 10),
              Text(_uploadError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: _font(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: (_fileContent == null || _isUploading) ? null : _submitBulkUpload,
          child: _isUploading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Start Import', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
