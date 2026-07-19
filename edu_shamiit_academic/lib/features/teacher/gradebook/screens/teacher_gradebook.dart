import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/utils/responsive.dart';
import 'package:edu_shamiit_academic/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_core/constants/app_fonts.dart';
import 'package:edu_shamiit_academic/core/services/teacher_api_service.dart';
import 'package:edu_shamiit_core/models/teacher_models.dart';
import 'package:edu_shamiit_academic/shared/widgets/azure_grid.dart';
import 'package:google_fonts/google_fonts.dart';

// Premium Palette
const _kPrimary = Color(0xFF4F46E5); // Indigo
const _kSecondary = Color(0xFF0EA5E9); // Sky
const _kSuccess = Color(0xFF10B981); // Emerald
const _kWarning = Color(0xFFF59E0B); // Amber
const _kDanger = Color(0xFFEF4444); // Red
const _kBg = Color(0xFFF8FAFC);
const _kBorder = Color(0xFFE2E8F0);
const _kText = Color(0xFF0F172A);
const _kText2 = Color(0xFF475569);
const _kText3 = Color(0xFF94A3B8);

class TeacherGradebook extends ConsumerStatefulWidget {
  const TeacherGradebook({super.key});

  @override
  ConsumerState<TeacherGradebook> createState() => _TeacherGradebookState();
}

class _TeacherGradebookState extends ConsumerState<TeacherGradebook> {
  final TeacherApiService _apiService = TeacherApiService();

  String _selectedClass = '';
  String _selectedSubject = 'All';

  List<String> _classes = [];
  List<TeacherSubject> _subjects = [];

  bool _isLoading = true;
  String? _error;

  List<Map<String, dynamic>> _gradebookRows = [];
  List<Map<String, dynamic>> _homeworkList = [];
  List<Map<String, dynamic>> _submissions = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadSubjectsForSelectedClass() async {
    if (_selectedClass.isEmpty) return;
    try {
      final subjects = await _apiService.getSubjects(classId: _selectedClass);
      setState(() {
        _subjects = subjects;
        final subjectNames = subjects.map((s) => s.name).toSet().toList();
        if (_selectedSubject != 'All' &&
            !subjectNames.contains(_selectedSubject)) {
          _selectedSubject = 'All';
        }
      });
    } catch (e) {
      // Keep existing subjects on error
    }
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final classes = await _apiService.getMyClasses();

      setState(() {
        if (classes.isNotEmpty) {
          _classes = classes
              .map((c) {
                final section = c.section.trim();
                if (section.isEmpty || c.name.contains('-$section')) {
                  return c.name;
                }
                return '${c.name}-$section';
              })
              .toSet()
              .toList();
          _selectedClass = _classes.first;
        }
      });

      await _loadSubjectsForSelectedClass();
      await _loadGradebookData();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadGradebookData() async {
    if (_selectedClass.isEmpty) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final subj = _selectedSubject == 'All'
          ? null
          : _subjects.firstWhere((s) => s.name == _selectedSubject).id;

      final data = await _apiService.getConsolidatedGradebook(
        classId: _selectedClass,
        subjectId: subj,
        assessmentType: null,
      );

      setState(() {
        _gradebookRows =
            List<Map<String, dynamic>>.from(data['gradebook'] ?? []);
        _homeworkList =
            List<Map<String, dynamic>>.from(data['homework_list'] ?? []);
        _submissions =
            List<Map<String, dynamic>>.from(data['homework_submissions'] ?? []);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  double get _averageMarks {
    if (_gradebookRows.isEmpty) return 0.0;
    return _gradebookRows.fold<double>(
            0.0,
            (sum, r) =>
                sum + (double.tryParse(r['average'].toString()) ?? 0.0)) /
        _gradebookRows.length;
  }

  String get _averageGrade {
    final avg = _averageMarks;
    if (avg >= 90) return 'A+';
    if (avg >= 80) return 'A';
    if (avg >= 70) return 'B+';
    if (avg >= 60) return 'B';
    if (avg >= 50) return 'C';
    if (avg >= 40) return 'D';
    return 'F';
  }

  Color _avatarColor(String name) {
    final colors = [
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFF3B82F6),
      const Color(0xFFEC4899),
      const Color(0xFF8B5CF6),
      const Color(0xFF0EA5E9),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  List<AzureGridColumn<Map<String, dynamic>>> _buildGridColumns() {
    return [
      AzureGridColumn<Map<String, dynamic>>(
        label: 'Roll No',
        width: 80.0,
        compare: (a, b) => (a['roll_number'] ?? '')
            .toString()
            .compareTo((b['roll_number'] ?? '').toString()),
        cellBuilder: (r) => Text((r['roll_number'] ?? '-').toString(),
            style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      AzureGridColumn<Map<String, dynamic>>(
        label: 'Student Name',
        width: 200.0,
        compare: (a, b) => (a['name'] ?? '')
            .toString()
            .compareTo((b['name'] ?? '').toString()),
        cellBuilder: (r) {
          final name = r['name'] ?? 'Student';
          final initials = name.trim().isEmpty
              ? '?'
              : name
                  .trim()
                  .split(RegExp(r'\s+'))
                  .map((n) => n.isNotEmpty ? n[0] : '')
                  .take(2)
                  .join()
                  .toUpperCase();
          return Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _avatarColor(name).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: TextStyle(
                      color: _avatarColor(name),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: _kText),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        },
      ),
      AzureGridColumn<Map<String, dynamic>>(
        label: 'Consolidated Avg',
        width: 140.0,
        compare: (a, b) => (double.tryParse(a['average'].toString()) ?? 0.0)
            .compareTo(double.tryParse(b['average'].toString()) ?? 0.0),
        cellBuilder: (r) => Text(
          '${r['average']}%',
          style: const TextStyle(fontWeight: FontWeight.bold, color: _kText2),
        ),
      ),
      AzureGridColumn<Map<String, dynamic>>(
        label: 'Overall Grade',
        width: 110.0,
        compare: (a, b) => (a['grade'] ?? '')
            .toString()
            .compareTo((b['grade'] ?? '').toString()),
        cellBuilder: (r) {
          final g = r['grade'] ?? 'F';
          final color = _getGradeColor(g);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              g,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold, color: color),
            ),
          );
        },
      ),
      AzureGridColumn<Map<String, dynamic>>(
        label: 'Trend',
        width: 110.0,
        cellBuilder: (r) {
          final t = r['trend'] ?? 'stable';
          final isUp = t == 'up';
          final isDown = t == 'down';
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isUp
                    ? Icons.trending_up
                    : isDown
                        ? Icons.trending_down
                        : Icons.remove_rounded,
                size: 14,
                color: isUp
                    ? _kSuccess
                    : isDown
                        ? _kDanger
                        : _kText3,
              ),
              const SizedBox(width: 4),
              Text(
                isUp
                    ? 'Improving'
                    : isDown
                        ? 'Declining'
                        : 'Stable',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isUp
                      ? _kSuccess
                      : isDown
                          ? _kDanger
                          : _kText2,
                ),
              ),
            ],
          );
        },
      ),
      AzureGridColumn<Map<String, dynamic>>(
        label: 'Pending Tasks',
        width: 120.0,
        cellBuilder: (r) {
          final count = int.tryParse(r['pending_count'].toString()) ?? 0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: count > 0
                  ? _kWarning.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              count > 0 ? '$count Pending' : 'All Graded',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: count > 0 ? _kWarning : _kText3,
              ),
            ),
          );
        },
      ),
      AzureGridColumn<Map<String, dynamic>>(
        label: 'Actions',
        width: 110.0,
        cellBuilder: (r) {
          return SizedBox(
            height: 24,
            child: ElevatedButton(
              onPressed: () => _openGradingPanel(r),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
                elevation: 0,
              ),
              child: const Text('Grade & Review',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
          );
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _gradebookRows.fold<int>(0,
        (sum, r) => sum + (int.tryParse(r['pending_count'].toString()) ?? 0));

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          // Premium Header
          Container(
            padding: EdgeInsets.fromLTRB(
                16, Responsive.headerTopPadding(context), 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_kPrimary, _kSecondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => safeGoBack(context, '/teacher/dashboard'),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Consolidated Gradebook',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Table / Main View
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 80.0),
              child: AzureGrid<Map<String, dynamic>>(
                title: 'Gradebook Roster',
                items: _error != null ? [] : _gradebookRows,
                loading: _isLoading,
                subHeader: _error != null
                    ? _buildErrorBanner()
                    : _buildStatsHeader(pendingCount),
                extraCommandFilters: [
                  if (_classes.isNotEmpty)
                    _buildTableToolbarDropdown(
                        'Class', _selectedClass, _classes, (value) async {
                      setState(() {
                        _selectedClass = value!;
                        _isLoading = true;
                      });
                      await _loadSubjectsForSelectedClass();
                      await _loadGradebookData();
                    }),
                ],
                columns: _buildGridColumns(),
                searchMatcher: (r) =>
                    '${r['name']} ${r['roll_number']} ${r['grade']}',
                onRefresh: _loadGradebookData,
                mobileCardBuilder: (context, r) => _buildMobileRosterTile(r),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableToolbarDropdown(
    String label,
    String value,
    List<String> options,
    Function(String?) onChanged,
  ) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value.isEmpty && options.isNotEmpty ? options.first : value,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          dropdownColor: Colors.white,
          items: options.map((opt) {
            return DropdownMenuItem<String>(
              value: opt,
              child: Text(opt.isEmpty ? '$label: None' : '$label: $opt'),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildStatsHeader(int pendingCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
              child: _buildStatChip('Average Score',
                  '${_averageMarks.toStringAsFixed(1)}%', _kPrimary)),
          const SizedBox(width: 8),
          Expanded(
              child: _buildStatChip('Overall Grade', _averageGrade,
                  _getGradeColor(_averageGrade))),
          const SizedBox(width: 8),
          Expanded(
              child: _buildStatChip('Roster Size',
                  '${_gradebookRows.length} Students', Colors.purple)),
          const SizedBox(width: 8),
          Expanded(
              child: _buildStatChip(
                  'Pending Tasks',
                  '$pendingCount Needing Grade',
                  pendingCount > 0 ? _kWarning : _kSuccess)),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: _kDanger.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: _kDanger, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error ?? 'An unexpected error occurred.',
              style: const TextStyle(
                  color: _kDanger, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: _kDanger, size: 18),
            onPressed: _loadGradebookData,
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 9, color: _kText2),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileRosterTile(Map<String, dynamic> r) {
    final name = r['name'] ?? 'Student';
    final g = r['grade'] ?? 'F';
    final color = _getGradeColor(g);
    final initials = name.trim().isEmpty
        ? '?'
        : name
            .trim()
            .split(RegExp(r'\s+'))
            .map((n) => n.isNotEmpty ? n[0] : '')
            .take(2)
            .join()
            .toUpperCase();
    final count = int.tryParse(r['pending_count'].toString()) ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _avatarColor(name).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: TextStyle(
                    color: _avatarColor(name),
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text('Roll No: ${r['roll_number']} · Avg: ${r['average']}%',
                    style: const TextStyle(color: _kText2, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4)),
                child: Text(g,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: color)),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _openGradingPanel(r),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: count > 0
                        ? _kWarning.withValues(alpha: 0.15)
                        : _kPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    count > 0 ? 'Grade ($count)' : 'Review',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: count > 0 ? _kWarning : _kPrimary),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Consolidated Grading panel for any picked student
  void _openGradingPanel(Map<String, dynamic> student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _GradingDetailsSheet(
          student: student,
          homeworkList: _homeworkList,
          submissions: _submissions,
          onGraded: () {
            _loadGradebookData();
          },
        );
      },
    );
  }
}

class _GradingDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> student;
  final List<Map<String, dynamic>> homeworkList;
  final List<Map<String, dynamic>> submissions;
  final VoidCallback onGraded;

  const _GradingDetailsSheet({
    required this.student,
    required this.homeworkList,
    required this.submissions,
    required this.onGraded,
  });

  @override
  State<_GradingDetailsSheet> createState() => _GradingDetailsSheetState();
}

class _GradingDetailsSheetState extends State<_GradingDetailsSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TeacherApiService _apiService = TeacherApiService();

  // Selected submission ID for active grading editing
  String? _editingSubmissionId;
  final _marksController = TextEditingController();
  final _remarksController = TextEditingController();
  String? _gradingError;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _marksController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _studentHomeworks {
    final sId = widget.student['student_id'];
    return widget.homeworkList.map((hw) {
      final sub = widget.submissions.firstWhere(
        (s) => s['homework_id'] == hw['id'] && s['student_id'] == sId,
        orElse: () => <String, dynamic>{},
      );
      return {
        'homework': hw,
        'submission': sub.isNotEmpty ? sub : null,
      };
    }).toList();
  }

  List<Map<String, dynamic>> get _studentExams {
    final results = widget.student['results'] as List? ?? [];
    return List<Map<String, dynamic>>.from(results);
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.student['name'] ?? 'Student';
    final initials = name.trim().isEmpty
        ? '?'
        : name
            .trim()
            .split(RegExp(r'\s+'))
            .map((n) => n.isNotEmpty ? n[0] : '')
            .take(2)
            .join()
            .toUpperCase();

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: _kBorder, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),

            // Roster header info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: _kPrimary.withValues(alpha: 0.1),
                    child: Text(initials,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: _kPrimary)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontFamily: AppFonts.heading,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: _kText)),
                        Text(
                            'Roll Number: ${widget.student['roll_number']} · Avg: ${widget.student['average']}%',
                            style:
                                const TextStyle(fontSize: 12, color: _kText2)),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: _kPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      'Grade ${widget.student['grade']}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _kPrimary,
                          fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tab bar
            TabBar(
              controller: _tabController,
              labelColor: _kPrimary,
              unselectedLabelColor: _kText3,
              indicatorColor: _kPrimary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold, fontFamily: AppFonts.heading),
              tabs: const [
                Tab(text: 'Homework Assignments'),
                Tab(text: 'Exam Grades'),
              ],
            ),

            // View list
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildHomeworkTab(),
                  _buildExamsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeworkTab() {
    final hwList = _studentHomeworks;
    if (hwList.isEmpty) {
      return const Center(
          child: Text('No homework assignments assigned to this class.',
              style: TextStyle(fontStyle: FontStyle.italic, color: _kText3)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: hwList.length,
      itemBuilder: (context, index) {
        final item = hwList[index];
        final hw = item['homework'] as Map<String, dynamic>;
        final sub = item['submission'] as Map<String, dynamic>?;

        final status =
            (sub?['status'] ?? 'not_submitted').toString().toLowerCase();
        final maxMarks =
            double.tryParse(hw['max_marks']?.toString() ?? '25.0') ?? 25.0;

        Widget subStatusBadge;
        Color statusColor = _kText3;
        String statusLabel = 'NOT SUBMITTED';

        if (status == 'graded') {
          statusColor = _kSuccess;
          statusLabel = 'GRADED (${sub!['marks']} / ${maxMarks.toInt()})';
        } else if (status == 'submitted') {
          statusColor = _kWarning;
          statusLabel = 'PENDING EVALUATION';
        } else if (status == 'returned') {
          statusColor = Colors.purple;
          statusLabel = 'RETURNED FOR REVISION';
        }

        subStatusBadge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6)),
          child: Text(
            statusLabel,
            style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.bold, color: statusColor),
          ),
        );

        final isEditing = sub != null && _editingSubmissionId == sub['id'];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kBorder),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02), blurRadius: 8)
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      hw['title'] ?? 'Homework Assignment',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: _kText),
                    ),
                  ),
                  const SizedBox(width: 8),
                  subStatusBadge,
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Max Marks: ${maxMarks.toInt()} · Due: ${hw['due_date']}',
                style: const TextStyle(fontSize: 11, color: _kText2),
              ),
              if (sub != null &&
                  sub['submission_text'] != null &&
                  sub['submission_text'].toString().isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: _kBg, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    'Notes: "${sub['submission_text']}"',
                    style: const TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: _kText2),
                  ),
                ),
              ],
              if (sub != null &&
                  sub['teacher_remarks'] != null &&
                  sub['teacher_remarks'].toString().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Remarks: ${sub['teacher_remarks']}',
                  style: const TextStyle(fontSize: 11, color: _kText2),
                ),
              ],

              // Grading Input fields if editing
              if (isEditing) ...[
                const SizedBox(height: 14),
                const Divider(height: 1, color: _kBorder),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _marksController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Marks...',
                          labelText: 'Score',
                          errorText: _gradingError,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 7,
                      child: TextField(
                        controller: _remarksController,
                        decoration: InputDecoration(
                          hintText: 'Remarks (optional)...',
                          labelText: 'Feedback',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () =>
                          setState(() => _editingSubmissionId = null),
                      child: const Text('Cancel',
                          style: TextStyle(
                              color: _kText3, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => _submitHomeworkReturn(sub['id']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                      child: const Text('Return Revision',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => _submitHomeworkGrade(sub['id'], maxMarks),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kSuccess,
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Save Grade',
                              style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ] else ...[
                // Action buttons to toggle grading panel
                if (status == 'submitted' || status == 'returned') ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _editingSubmissionId = sub!['id'];
                          _marksController.text =
                              sub['marks']?.toString() ?? '';
                          _remarksController.text =
                              sub['teacher_remarks'] ?? '';
                          _gradingError = null;
                        });
                      },
                      icon: const Icon(Icons.edit_note,
                          size: 16, color: Colors.white),
                      label: const Text('Grade Submission',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _kSecondary, elevation: 0),
                    ),
                  ),
                ] else if (status == 'graded') ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _editingSubmissionId = sub!['id'];
                          _marksController.text =
                              sub['marks']?.toString() ?? '';
                          _remarksController.text =
                              sub['teacher_remarks'] ?? '';
                          _gradingError = null;
                        });
                      },
                      icon: const Icon(Icons.edit, size: 14, color: _kPrimary),
                      label: const Text('Edit Grade',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _kPrimary)),
                    ),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildExamsTab() {
    final exams = _studentExams;
    if (exams.isEmpty) {
      return const Center(
          child: Text('No exam grades found for this selection.',
              style: TextStyle(fontStyle: FontStyle.italic, color: _kText3)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: exams.length,
      itemBuilder: (context, index) {
        final exam = exams[index];
        final marks =
            double.tryParse(exam['marks_obtained']?.toString() ?? '0.0') ?? 0.0;
        final total =
            int.tryParse(exam['total_marks']?.toString() ?? '100') ?? 100;
        final pct = total > 0 ? (marks / total * 100) : 0.0;
        final g = exam['grade'] ?? 'F';
        final color = _getGradeColor(g);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    g,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exam['exam_title'] ?? exam['exam_type'] ?? 'Exam',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: _kText),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Subject: ${exam['subject_name'] ?? 'General'} · Type: ${exam['exam_type'] ?? 'General'}',
                      style: const TextStyle(fontSize: 11, color: _kText2),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Marks: ${marks.toInt()} / $total (${pct.toStringAsFixed(1)}%)',
                      style: const TextStyle(fontSize: 11, color: _kText2),
                    ),
                  ],
                ),
              ),
              const Text('Reported',
                  style: TextStyle(
                      fontSize: 10,
                      color: _kText3,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitHomeworkGrade(
      String submissionId, double maxMarks) async {
    final parsed = double.tryParse(_marksController.text);
    if (parsed == null) {
      setState(() => _gradingError = 'Please enter a valid number');
      return;
    }
    if (parsed < 0 || parsed > maxMarks) {
      setState(() =>
          _gradingError = 'Score must be between 0 and ${maxMarks.toInt()}');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _gradingError = null;
    });

    try {
      await _apiService.gradeSubmission(
        submissionId: submissionId,
        marks: parsed,
        feedback: _remarksController.text.trim().isEmpty
            ? null
            : _remarksController.text,
      );

      widget.onGraded();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✅ Grade submitted successfully!'),
              backgroundColor: _kSuccess),
        );
        setState(() {
          _editingSubmissionId = null;
          _isSubmitting = false;
        });
        Navigator.pop(
            context); // Close the sheet to force refresh dashboard stats
      }
    } catch (e) {
      setState(() {
        _gradingError = 'Failed to submit grade: $e';
        _isSubmitting = false;
      });
    }
  }

  Future<void> _submitHomeworkReturn(String submissionId) async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      await _apiService.returnSubmission(
        submissionId: submissionId,
        feedback: _remarksController.text.trim().isEmpty
            ? null
            : _remarksController.text,
      );

      widget.onGraded();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('↩️ Homework returned for revision!'),
              backgroundColor: Colors.purple),
        );
        setState(() {
          _editingSubmissionId = null;
          _isSubmitting = false;
        });
        Navigator.pop(context); // Close sheet
      }
    } catch (e) {
      setState(() {
        _gradingError = 'Failed to return homework: $e';
        _isSubmitting = false;
      });
    }
  }
}

Color _getGradeColor(String grade) {
  switch (grade) {
    case 'A+':
    case 'A':
      return _kSuccess;
    case 'B+':
    case 'B':
      return _kSecondary;
    case 'C':
      return _kWarning;
    default:
      return _kDanger;
  }
}
