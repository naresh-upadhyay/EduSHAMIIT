import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/services/teacher_api_service.dart';
import 'package:edu_shamiit_ai/core/models/teacher_models.dart';
import 'package:edu_shamiit_ai/shared/widgets/azure_grid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:edu_shamiit_ai/core/services/api_service.dart';

// ─── Color tokens (teacher homework palette) ───────────────────────────────
const _kPink = Color(0xFFBE185D);
const _kPinkLight = Color(0xFFFDF2F8);
const _kPinkBg = Color(0xFFFFF0F8);
const _kText = Color(0xFF0F172A);
const _kText2 = Color(0xFF475569);
const _kText3 = Color(0xFF94A3B8);
const _kBorder = Color(0xFFE2E8F0);
const _kSurface = Colors.white;
const _kSuccess = Color(0xFF059669);
const _kWarning = Color(0xFFD97706);
const _kError = Color(0xFFEF4444);

class HomeworkActionButtonState {
  final String label;
  final Color backgroundColor;
  final Color textColor;

  const HomeworkActionButtonState({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });
}

class TeacherHomework extends ConsumerStatefulWidget {
  const TeacherHomework({super.key});

  @override
  ConsumerState<TeacherHomework> createState() => _TeacherHomeworkState();
}

class _TeacherHomeworkState extends ConsumerState<TeacherHomework> {
  final TeacherApiService _apiService = TeacherApiService();

  List<TeacherHomeworkAssignment> _active = [];
  List<TeacherHomeworkAssignment> _submissions = [];
  List<TeacherHomeworkAssignment> _graded = [];
  List<TeacherHomeworkAssignment> _allHomework = [];
  bool _isLoading = true;
  String? _error;

  // Create form fields
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _marksCtrl = TextEditingController(text: '25');
  String _selectedClass = '';
  String _selectedSubject = 'Mathematics';
  List<String> _classes = [];
  List<String> _subjects = [
    'Mathematics',
    'Physics',
    'Chemistry',
    'Biology',
    'English',
    'History',
    'Geography',
    'Computer Science'
  ];
  DateTime _dueDate = DateTime.now().add(const Duration(days: 3));
  String _activeStatusFilter = 'All';
  String _activeActionStateFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _marksCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _apiService.getHomeworkAssignments(status: 'active'),
        _apiService.getHomeworkAssignments(status: 'pending'),
        _apiService.getHomeworkAssignments(status: 'completed'),
        _apiService.getSubjects(allSubjects: true),
        _apiService.getMyClasses(),
      ]);
      setState(() {
        _active = results[0] as List<TeacherHomeworkAssignment>;
        _submissions = results[1] as List<TeacherHomeworkAssignment>;
        _graded = results[2] as List<TeacherHomeworkAssignment>;

        final allMap = <String, TeacherHomeworkAssignment>{};
        for (var hw in _active) {
          allMap[hw.id] = hw;
        }
        for (var hw in _submissions) {
          allMap[hw.id] = hw;
        }
        for (var hw in _graded) {
          allMap[hw.id] = hw;
        }
        _allHomework = allMap.values.toList();
        _allHomework.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        final subjectsRes = results[3] as List<TeacherSubject>;
        if (subjectsRes.isNotEmpty) {
          _subjects = subjectsRes.map((s) => s.name).toSet().toList();
          if (!_subjects.contains(_selectedSubject)) {
            _selectedSubject = _subjects.first;
          }
        }
        final classesRes = results[4] as List<TeacherMyClass>;
        if (classesRes.isNotEmpty) {
          _classes = classesRes
              .map((c) {
                final section = c.section.trim();
                if (section.isEmpty || c.name.contains('-$section'))
                  return c.name;
                return '${c.name}-$section';
              })
              .toSet()
              .toList();
          if (!_classes.contains(_selectedClass)) {
            _selectedClass = _classes.first;
          }
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _subjectIcon(String subject) {
    final s = subject.toLowerCase();
    if (s.contains('math')) return '📐';
    if (s.contains('physics')) return '⚛️';
    if (s.contains('chem')) return '⚗️';
    if (s.contains('bio')) return '🧬';
    if (s.contains('english')) return '📖';
    if (s.contains('hist')) return '📜';
    if (s.contains('geo')) return '🌍';
    if (s.contains('comp')) return '💻';
    if (s.contains('eco')) return '📈';
    return '📚';
  }

  Color _dueColor(TeacherHomeworkAssignment hw) {
    if (hw.isOverdue) return _kError;
    final diff = hw.dueDate.difference(DateTime.now()).inDays;
    if (diff == 0) return _kError;
    if (diff <= 2) return _kWarning;
    return _kSuccess;
  }

  HomeworkActionButtonState _getActionButtonState(
      TeacherHomeworkAssignment hw) {
    if (hw.submittedCount == 0) {
      return const HomeworkActionButtonState(
        label: 'Awaiting Submissions',
        backgroundColor: Color(0xFF64748B), // Slate grey
        textColor: Colors.white,
      );
    }

    final graded = hw.gradedCount ?? 0;
    final pending = hw.submittedCount - graded;
    if (pending > 0) {
      return HomeworkActionButtonState(
        label: 'Pending ($pending)',
        backgroundColor: const Color(0xFFD97706), // Warning amber
        textColor: Colors.white,
      );
    }

    if (hw.submittedCount < hw.totalCount) {
      return HomeworkActionButtonState(
        label: 'Waiting (${hw.totalCount - hw.submittedCount} left)',
        backgroundColor: const Color(0xFF0284C7), // Sky blue/Info
        textColor: Colors.white,
      );
    }

    return const HomeworkActionButtonState(
      label: 'All Graded ✓',
      backgroundColor: Color(0xFF059669), // Success green
      textColor: Colors.white,
    );
  }

  List<AzureGridColumn<TeacherHomeworkAssignment>> _buildHomeworkColumns() {
    return [
      AzureGridColumn<TeacherHomeworkAssignment>(
        label: 'Assignment Title',
        width: 170.0,
        compare: (a, b) => a.title.compareTo(b.title),
        cellBuilder: (hw) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(hw.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (hw.description.isNotEmpty)
              Text(
                hw.description,
                style: const TextStyle(fontSize: 10, color: _kText3),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
      AzureGridColumn<TeacherHomeworkAssignment>(
        label: 'Class',
        width: 80.0,
        compare: (a, b) => a.class_.compareTo(b.class_),
        cellBuilder: (hw) => Text(hw.class_),
      ),
      AzureGridColumn<TeacherHomeworkAssignment>(
        label: 'Subject',
        width: 110.0,
        compare: (a, b) => a.subject.compareTo(b.subject),
        cellBuilder: (hw) => Text('${_subjectIcon(hw.subject)} ${hw.subject}'),
      ),
      AzureGridColumn<TeacherHomeworkAssignment>(
        label: 'Submissions',
        width: 110.0,
        compare: (a, b) => a.submissionRate.compareTo(b.submissionRate),
        cellBuilder: (hw) => Text(
            '${hw.submittedCount}/${hw.totalCount} (${hw.submissionRate.toInt()}%)'),
      ),
      AzureGridColumn<TeacherHomeworkAssignment>(
        label: 'Due Date',
        width: 120.0,
        compare: (a, b) => a.dueDate.compareTo(b.dueDate),
        cellBuilder: (hw) {
          final color = _dueColor(hw);
          final daysStr = hw.isOverdue
              ? 'Overdue'
              : 'Due in ${hw.dueDate.difference(DateTime.now()).inDays}d';
          return Text(
            '${hw.dueDate.day}/${hw.dueDate.month}/${hw.dueDate.year} ($daysStr)',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          );
        },
      ),
      AzureGridColumn<TeacherHomeworkAssignment>(
        label: 'Max Marks',
        width: 80.0,
        compare: (a, b) => (a.maxMarks ?? 0).compareTo(b.maxMarks ?? 0),
        cellBuilder: (hw) => Text('${hw.maxMarks ?? 25}'),
      ),
      AzureGridColumn<TeacherHomeworkAssignment>(
        label: 'Status',
        width: 110.0,
        compare: (a, b) => a.computedStatus.compareTo(b.computedStatus),
        cellBuilder: (hw) {
          final st = hw.computedStatus.toLowerCase();
          Color color;
          String label;
          if (st == 'active') {
            color = _kPink;
            label = 'ACTIVE';
          } else if (st == 'pending') {
            color = _kWarning;
            label = 'PENDING';
          } else {
            color = _kSuccess;
            label = 'GRADED';
          }
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          );
        },
      ),
      AzureGridColumn<TeacherHomeworkAssignment>(
        label: 'Actions',
        width: 190.0,
        cellBuilder: (hw) {
          final btnState = _getActionButtonState(hw);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 24,
                child: ElevatedButton(
                  onPressed: () =>
                      context.push('/teacher/submissions?homework_id=${hw.id}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: btnState.backgroundColor,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                    elevation: 0,
                  ),
                  child: Text(btnState.label,
                      style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon:
                    const Icon(Icons.alarm_rounded, size: 14, color: _kWarning),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _showReminderDialog(hw),
                tooltip: 'Send Reminder',
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.more_vert_rounded,
                    size: 14, color: Colors.grey),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _showEditSheet(hw),
                tooltip: 'More Actions',
              ),
            ],
          );
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPinkBg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _kPink))
                : _error != null
                    ? _buildError()
                    : Padding(
                        padding:
                            const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 80.0),
                        child: AzureGrid<TeacherHomeworkAssignment>(
                          title: 'Homework List',
                          items: _allHomework,
                          columns: _buildHomeworkColumns(),
                          mobileCardBuilder: (context, hw) =>
                              _buildActiveCard(hw),
                          searchMatcher: (hw) =>
                              '${hw.title} ${hw.subject} ${hw.class_} ${hw.computedStatus}',
                          onRefresh: _loadAll,
                          enableSelection: true,
                          bulkActions: (context, selected) =>
                              _buildBulkActions(context, selected),
                          onFilterChanged: (label, val) {
                            setState(() {
                              if (label == 'Status') {
                                _activeStatusFilter = val;
                              } else if (label == 'Action State') {
                                _activeActionStateFilter = val;
                              }
                            });
                          },
                          filters: [
                            AzureGridFilter<TeacherHomeworkAssignment>(
                              label: 'Status',
                              options: const ['Active', 'Pending', 'Graded'],
                              filterFn: (hw, option) {
                                if (option == 'All') return true;
                                final st = hw.computedStatus.toLowerCase();
                                if (option == 'Active') return st == 'active';
                                if (option == 'Pending') return st == 'pending';
                                if (option == 'Graded')
                                  return st == 'completed';
                                return true;
                              },
                            ),
                            AzureGridFilter<TeacherHomeworkAssignment>(
                              label: 'Action State',
                              options: const [
                                'Awaiting Submissions',
                                'Pending Grade',
                                'Waiting for Submissions',
                                'All Graded'
                              ],
                              filterFn: (hw, option) {
                                if (option == 'All') return true;
                                final graded = hw.gradedCount ?? 0;
                                final pending = hw.submittedCount - graded;
                                if (option == 'Awaiting Submissions') {
                                  return hw.submittedCount == 0;
                                }
                                if (option == 'Pending Grade') {
                                  return hw.submittedCount > 0 && pending > 0;
                                }
                                if (option == 'Waiting for Submissions') {
                                  return hw.submittedCount > 0 &&
                                      pending == 0 &&
                                      hw.submittedCount < hw.totalCount;
                                }
                                if (option == 'All Graded') {
                                  return hw.submittedCount > 0 &&
                                      pending == 0 &&
                                      hw.submittedCount == hw.totalCount;
                                }
                                return true;
                              },
                            ),
                            if (_classes.isNotEmpty)
                              AzureGridFilter<TeacherHomeworkAssignment>(
                                label: 'Class',
                                options: _classes,
                                filterFn: (hw, option) {
                                  if (option == 'All') return true;
                                  return hw.class_ == option;
                                },
                              ),
                            if (_subjects.isNotEmpty)
                              AzureGridFilter<TeacherHomeworkAssignment>(
                                label: 'Subject',
                                options: _subjects,
                                filterFn: (hw, option) {
                                  if (option == 'All') return true;
                                  return hw.subject == option;
                                },
                              ),
                          ],
                          extraCommandActions: [
                            IconButton(
                              icon:
                                  const Icon(Icons.add_rounded, color: _kPink),
                              tooltip: 'Create Homework',
                              onPressed: _showCreateModal,
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding:
          EdgeInsets.fromLTRB(8, Responsive.headerTopPadding(context), 16, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kPink, Color(0xFFDB2777)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
            onPressed: () => safeGoBack(context, '/teacher/dashboard'),
          ),
          const Expanded(
            child: Text(
              'Homework Manager',
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh_rounded,
                color: Colors.white, size: 20),
          ),
          IconButton(
            onPressed: _showCreateModal,
            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
            tooltip: 'Create Homework',
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCard(TeacherHomeworkAssignment hw) {
    final color = _dueColor(hw);
    final icon = _subjectIcon(hw.subject);
    final pct = hw.submissionRate;
    final st = hw.computedStatus.toLowerCase();
    final statusLabel = st == 'active'
        ? 'ACTIVE'
        : st == 'pending'
            ? 'PENDING'
            : 'GRADED';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$icon ${hw.class_} · ${hw.subject} · $statusLabel',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: color,
                        fontFamily: AppFonts.heading),
                  ),
                ),
                Text(
                  '${hw.submittedCount}/${hw.totalCount} submitted',
                  style: const TextStyle(fontSize: 10, color: _kText3),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(hw.title,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _kText,
                    fontFamily: AppFonts.heading)),
            const SizedBox(height: 4),
            Text(
              hw.description,
              style: const TextStyle(fontSize: 11, color: _kText3, height: 1.5),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct / 100,
                backgroundColor: _kBorder,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Builder(builder: (context) {
                    final btnState = _getActionButtonState(hw);
                    return _buildBtn(
                      label: btnState.label,
                      bg: btnState.backgroundColor,
                      fg: btnState.textColor,
                      onTap: () => context
                          .push('/teacher/submissions?homework_id=${hw.id}'),
                    );
                  }),
                ),
                const SizedBox(width: 6),
                _buildIconBtn(
                    icon: '⏰',
                    bg: _kPinkLight,
                    fg: _kPink,
                    onTap: () => _showReminderDialog(hw)),
                const SizedBox(width: 6),
                _buildIconBtn(
                    icon: '⋯',
                    bg: _kPinkLight,
                    fg: _kPink,
                    onTap: () => _showEditSheet(hw)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSheet(TeacherHomeworkAssignment hw) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: _kBorder, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text(hw.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _kText)),
              const SizedBox(height: 4),
              Text('${hw.class_} · ${hw.subject}',
                  style: const TextStyle(fontSize: 11, color: _kText3)),
              const SizedBox(height: 20),
              _buildSheetOption(
                  emoji: '📋',
                  label: 'Review Submissions',
                  sublabel: '${hw.submittedCount} submitted',
                  color: _kPink,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/teacher/submissions?homework_id=${hw.id}');
                  }),
              _buildSheetOption(
                  emoji: '✏️',
                  label: 'Edit Assignment Details',
                  sublabel: 'Change title, dates, marks',
                  color: const Color(0xFF7C3AED),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditAssignmentModal(hw);
                  }),
              _buildSheetOption(
                  emoji: '🔔',
                  label: 'Send Reminder',
                  sublabel: 'Notify students who haven\'t submitted',
                  color: const Color(0xFFD97706),
                  onTap: () {
                    Navigator.pop(context);
                    _showReminderDialog(hw);
                  }),
              _buildSheetOption(
                  emoji: '📊',
                  label: 'View Analytics',
                  sublabel: 'Submission trends and performance',
                  color: const Color(0xFF0EA5E9),
                  onTap: () {
                    Navigator.pop(context);
                    _showAnalytics(hw);
                  }),
              _buildSheetOption(
                  emoji: '🗑️',
                  label: 'Delete Assignment',
                  sublabel: 'This action cannot be undone',
                  color: _kError,
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDelete(hw);
                  }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetOption(
      {required String emoji,
      required String label,
      required String sublabel,
      required Color color,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: color,
                          fontFamily: AppFonts.heading)),
                  Text(sublabel,
                      style: const TextStyle(fontSize: 10, color: _kText3)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: color.withValues(alpha: 0.5), size: 18),
          ],
        ),
      ),
    );
  }

  void _showCreateModal() {
    _titleCtrl.clear();
    _descCtrl.clear();
    _marksCtrl.text = '25';
    _selectedClass = _classes.isNotEmpty ? _classes.first : '';
    _selectedSubject = _subjects.isNotEmpty ? _subjects.first : 'Mathematics';
    _dueDate = DateTime.now().add(const Duration(days: 3));

    String? attachmentUrl;
    String? attachmentName;
    bool isUploadingAttachment = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: StatefulBuilder(
            builder: (ctx, setS) => Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                            child: Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                    color: _kBorder,
                                    borderRadius: BorderRadius.circular(2)))),
                        const SizedBox(height: 16),
                        const Center(
                            child: Text('📝 Create Assignment',
                                style: TextStyle(
                                    fontFamily: AppFonts.heading,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: _kText))),
                        const SizedBox(height: 16),
                        _buildLabel('Title'),
                        _buildInput(_titleCtrl, 'Assignment title...'),
                        _buildLabel('Class'),
                        _buildDropdown(
                          value: _selectedClass,
                          items: _classes,
                          onChanged: (v) => setS(() => _selectedClass = v!),
                        ),
                        _buildLabel('Subject'),
                        _buildDropdown(
                          value: _selectedSubject,
                          items: _subjects,
                          onChanged: (v) => setS(() => _selectedSubject = v!),
                        ),
                        _buildLabel('Due Date'),
                        InkWell(
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _dueDate,
                              firstDate: DateTime.now(),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                            );
                            if (d != null) setS(() => _dueDate = d);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _kBorder),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined,
                                    size: 14, color: _kText2),
                                const SizedBox(width: 8),
                                Text(
                                    '${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
                                    style: const TextStyle(
                                        fontSize: 13, color: _kText)),
                              ],
                            ),
                          ),
                        ),
                        _buildLabel('Max Marks'),
                        _buildInput(_marksCtrl, '25',
                            type: TextInputType.number),
                        _buildLabel('Instructions'),
                        _buildInput(
                            _descCtrl, 'Write instructions for students...',
                            maxLines: 3),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: isUploadingAttachment
                              ? null
                              : () async {
                                  final result =
                                      await FilePicker.platform.pickFiles(
                                    type: FileType.any,
                                    allowMultiple: false,
                                    withData: true,
                                  );
                                  if (result != null &&
                                      result.files.single.bytes != null) {
                                    final file = result.files.single;
                                    setS(() {
                                      isUploadingAttachment = true;
                                      attachmentName = file.name;
                                    });
                                    try {
                                      final response =
                                          await ApiService().multipartPostBytes(
                                        '/documents/upload',
                                        file.bytes!,
                                        file.name,
                                        'file',
                                        fields: {
                                          'title': file.name,
                                          'category': 'homework_instruction',
                                          'description':
                                              'Homework instructions/guidelines',
                                        },
                                      );
                                      if (response['success'] == true) {
                                        final doc = response['data']['document']
                                            as Map<String, dynamic>;
                                        setS(() {
                                          attachmentUrl =
                                              doc['file_url'] as String;
                                        });
                                      } else {
                                        throw Exception(response['detail'] ??
                                            'Upload failed');
                                      }
                                    } catch (e) {
                                      setS(() {
                                        attachmentUrl = null;
                                        attachmentName = null;
                                      });
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(
                                              content:
                                                  Text('Failed to upload: $e'),
                                              backgroundColor: _kError),
                                        );
                                      }
                                    } finally {
                                      setS(() {
                                        isUploadingAttachment = false;
                                      });
                                    }
                                  }
                                },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: _kBorder, width: 1.5),
                              borderRadius: BorderRadius.circular(14),
                              color: const Color(0xFFF8FAFC),
                            ),
                            child: isUploadingAttachment
                                ? const Column(
                                    children: [
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                            color: _kPink, strokeWidth: 2),
                                      ),
                                      SizedBox(height: 8),
                                      Text('Uploading attachment...',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: _kText)),
                                    ],
                                  )
                                : attachmentUrl != null
                                    ? Row(
                                        children: [
                                          const Text('📎',
                                              style: TextStyle(fontSize: 24)),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                    attachmentName ??
                                                        'File Attached',
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: _kText),
                                                    overflow:
                                                        TextOverflow.ellipsis),
                                                const Text('Upload complete ✅',
                                                    style: TextStyle(
                                                        fontSize: 10,
                                                        color: _kSuccess)),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.cancel,
                                                color: _kError, size: 20),
                                            onPressed: () {
                                              setS(() {
                                                attachmentUrl = null;
                                                attachmentName = null;
                                              });
                                            },
                                          ),
                                        ],
                                      )
                                    : const Column(
                                        children: [
                                          Text('📎',
                                              style: TextStyle(fontSize: 24)),
                                          SizedBox(height: 4),
                                          Text('Attach Files (optional)',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: _kText)),
                                          Text('PDF, DOC, JPG up to 10MB',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: _kText3)),
                                        ],
                                      ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () =>
                                _createHomework(ctx, attachmentUrl),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kPink,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: const Text('📤 Assign to Class',
                                style: TextStyle(
                                    fontFamily: AppFonts.heading,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _kPink,
                              side: const BorderSide(color: _kPink),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('Cancel',
                                style: TextStyle(
                                    fontFamily: AppFonts.heading,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
      ),
    );
  }

  Future<void> _createHomework(BuildContext ctx, String? attachmentUrl) async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
          content: Text('Please enter a title'), backgroundColor: _kError));
      return;
    }
    final messenger = ScaffoldMessenger.of(ctx);
    Navigator.pop(ctx);
    try {
      await _apiService.createHomework(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        classId: _selectedClass,
        subject: _selectedSubject,
        dueDate: _dueDate,
        maxMarks: int.tryParse(_marksCtrl.text) ?? 25,
        instructions: _descCtrl.text.trim(),
        attachmentUrl: attachmentUrl,
      );
      _loadAll();
      if (mounted) {
        _showSuccessDialog('Assignment Created! 🎉',
            '${_titleCtrl.text} has been assigned to $_selectedClass. Students will be notified.');
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: _kError));
      }
    }
  }

  void _showEditAssignmentModal(TeacherHomeworkAssignment hw) {
    _titleCtrl.text = hw.title;
    _descCtrl.text = hw.description;
    _marksCtrl.text = (hw.maxMarks ?? 25).toString();
    var editDue = hw.dueDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: StatefulBuilder(
            builder: (ctx, setS) => Container(
                  decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24))),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                            child: Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                    color: _kBorder,
                                    borderRadius: BorderRadius.circular(2)))),
                        const SizedBox(height: 16),
                        const Center(
                            child: Text('✏️ Edit Assignment',
                                style: TextStyle(
                                    fontFamily: AppFonts.heading,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: _kText))),
                        const SizedBox(height: 16),
                        _buildLabel('Title'),
                        _buildInput(_titleCtrl, 'Assignment title...'),
                        _buildLabel('Max Marks'),
                        _buildInput(_marksCtrl, '25',
                            type: TextInputType.number),
                        _buildLabel('Due Date'),
                        InkWell(
                          onTap: () async {
                            final d = await showDatePicker(
                                context: context,
                                initialDate: editDue,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365)));
                            if (d != null) setS(() => editDue = d);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _kBorder)),
                            child: Row(children: [
                              const Icon(Icons.calendar_today_outlined,
                                  size: 14, color: _kText2),
                              const SizedBox(width: 8),
                              Text(
                                  '${editDue.day}/${editDue.month}/${editDue.year}',
                                  style: const TextStyle(
                                      fontSize: 13, color: _kText)),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              try {
                                await _apiService.updateHomework(
                                    homeworkId: hw.id,
                                    updates: {
                                      'title': _titleCtrl.text.trim(),
                                      'max_marks':
                                          int.tryParse(_marksCtrl.text),
                                      'due_date': editDue
                                          .toIso8601String()
                                          .split('T')[0]
                                    });
                                _loadAll();
                                if (mounted)
                                  _showSuccessDialog('Saved! 💾',
                                      'Assignment updated successfully.');
                              } catch (e) {
                                if (mounted)
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text('Error: $e'),
                                          backgroundColor: _kError));
                              }
                            },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: _kPink,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                elevation: 0),
                            child: const Text('💾 Save Changes',
                                style: TextStyle(
                                    fontFamily: AppFonts.heading,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: OutlinedButton.styleFrom(
                                    foregroundColor: _kPink,
                                    side: const BorderSide(color: _kPink),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14))),
                                child: const Text('Cancel',
                                    style: TextStyle(
                                        fontFamily: AppFonts.heading,
                                        fontWeight: FontWeight.w700)))),
                      ],
                    ),
                  ),
                )),
      ),
    );
  }

  void _showReminderDialog(TeacherHomeworkAssignment hw) {
    final pending = hw.totalCount - hw.submittedCount;
    bool isSending = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Column(
            children: [
              Text('🔔', style: TextStyle(fontSize: 40)),
              SizedBox(height: 4),
              Text('Send Reminder?',
                  style: TextStyle(
                      fontFamily: AppFonts.heading,
                      fontWeight: FontWeight.w800,
                      color: _kPink)),
            ],
          ),
          content: isSending
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: _kPink),
                    SizedBox(height: 12),
                    Text('Sending reminders...',
                        style: TextStyle(fontSize: 12, color: _kText2)),
                  ],
                )
              : Text(
                  'Send a push notification to $pending students who haven\'t submitted "${hw.title}".',
                  style: const TextStyle(fontSize: 12, color: _kText2),
                  textAlign: TextAlign.center,
                ),
          actions: isSending
              ? []
              : [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child:
                        const Text('Cancel', style: TextStyle(color: _kText3)),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      setS(() {
                        isSending = true;
                      });
                      try {
                        await _apiService.sendHomeworkReminder(hw.id);
                        if (dialogCtx.mounted) {
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(dialogCtx).showSnackBar(
                            const SnackBar(
                              content: Text('📤 Reminder sent to students!'),
                              backgroundColor: _kSuccess,
                            ),
                          );
                        }
                      } catch (e) {
                        setS(() {
                          isSending = false;
                        });
                        if (dialogCtx.mounted) {
                          ScaffoldMessenger.of(dialogCtx).showSnackBar(
                            SnackBar(
                              content: Text('Error sending reminder: $e'),
                              backgroundColor: _kError,
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPink,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('📤 Send Reminder',
                        style: TextStyle(
                            fontFamily: AppFonts.heading,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
        ),
      ),
    );
  }

  void _showAnalytics(TeacherHomeworkAssignment hw) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: _kBorder, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('📊 ${hw.title}',
                style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _kText)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatBox('${hw.submittedCount}', 'Submitted', _kSuccess),
                _buildStatBox('${hw.totalCount - hw.submittedCount}', 'Pending',
                    _kWarning),
                _buildStatBox('${hw.submissionRate.toInt()}%', 'Rate', _kPink),
                _buildStatBox('${hw.maxMarks ?? 25}', 'Max Marks',
                    const Color(0xFF7C3AED)),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/teacher/submissions?homework_id=${hw.id}');
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: _kPink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                child: const Text('View All Submissions',
                    style: TextStyle(
                        fontFamily: AppFonts.heading,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 9, color: _kText3, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _confirmDelete(TeacherHomeworkAssignment hw) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Assignment?',
            style: TextStyle(
                fontFamily: AppFonts.heading,
                fontWeight: FontWeight.w800,
                color: _kError)),
        content: Text(
            'Are you sure you want to delete "${hw.title}"? This action cannot be undone.',
            style: const TextStyle(fontSize: 12, color: _kText2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: _kText3)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await _apiService.deleteHomework(hw.id);
                _loadAll();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Assignment deleted'),
                        backgroundColor: _kSuccess),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Error: $e'), backgroundColor: _kError),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kError,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('🗑️ Delete',
                style: TextStyle(
                    fontFamily: AppFonts.heading, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(children: [
          const Text('✅', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          Text(title,
              style: const TextStyle(
                  fontFamily: AppFonts.heading,
                  fontWeight: FontWeight.w800,
                  color: _kSuccess),
              textAlign: TextAlign.center),
        ]),
        content: Text(message,
            style: const TextStyle(fontSize: 12, color: _kText2),
            textAlign: TextAlign.center),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _kPink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: const Text('Done',
                  style: TextStyle(
                      fontFamily: AppFonts.heading,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(_error ?? 'Something went wrong',
              style: const TextStyle(color: _kError, fontSize: 13)),
          const SizedBox(height: 12),
          ElevatedButton(
              onPressed: _loadAll,
              style: ElevatedButton.styleFrom(
                  backgroundColor: _kPink, foregroundColor: Colors.white),
              child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11, color: _kText3, fontWeight: FontWeight.w700)),
      );

  Widget _buildInput(TextEditingController ctrl, String hint,
      {TextInputType type = TextInputType.text, int maxLines = 1}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 13, color: _kText),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _kText3, fontSize: 13),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kBorder)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kBorder)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kPink, width: 1.5)),
          contentPadding: const EdgeInsets.all(12),
        ),
      ),
    );
  }

  Widget _buildDropdown(
      {required String value,
      required List<String> items,
      required void Function(String?) onChanged}) {
    final effectiveItems =
        items.isEmpty ? [value.isEmpty ? 'N/A' : value] : items;
    final effectiveValue =
        value.isEmpty ? (items.isNotEmpty ? items.first : 'N/A') : value;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: DropdownButton<String>(
        value: effectiveValue,
        isExpanded: true,
        underline: const SizedBox(),
        style: const TextStyle(fontSize: 13, color: _kText),
        items: effectiveItems
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: items.isEmpty ? null : onChanged,
      ),
    );
  }

  Widget _buildBtn(
      {required String label,
      required Color bg,
      required Color fg,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: fg,
                fontFamily: AppFonts.heading)),
      ),
    );
  }

  Widget _buildIconBtn(
      {required String icon,
      required Color bg,
      required Color fg,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Center(
            child: Text(icon, style: TextStyle(fontSize: 14, color: fg))),
      ),
    );
  }

  List<Widget> _buildBulkActions(
      BuildContext context, List<TeacherHomeworkAssignment> selected) {
    return [
      SizedBox(
        height: 32,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.notifications_active_rounded,
              size: 14, color: Colors.white),
          label: const Text('Send Targeted Notifications',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.bold)),
          onPressed: () => _showBulkNotificationDialog(selected),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPink,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            elevation: 0,
          ),
        ),
      ),
    ];
  }

  void _showBulkNotificationDialog(List<TeacherHomeworkAssignment> selected) {
    final homeworkIds = selected.map((e) => e.id).toList();

    int totalReminders = 0;
    int totalGrades = 0;
    for (var hw in selected) {
      totalReminders += (hw.totalCount - hw.submittedCount);
      totalGrades += (hw.gradedCount ?? 0);
    }

    String initialMode = 'reminder';
    bool isPendingState = false;

    if (_activeActionStateFilter == 'Awaiting Submissions' ||
        _activeActionStateFilter == 'Waiting for Submissions' ||
        _activeStatusFilter == 'Active') {
      initialMode = 'reminder';
    } else if (_activeActionStateFilter == 'All Graded' ||
        _activeStatusFilter == 'Graded') {
      initialMode = 'graded';
    } else if (_activeActionStateFilter == 'Pending Grade' ||
        _activeStatusFilter == 'Pending') {
      isPendingState = true;
    } else {
      if (totalReminders > 0) {
        initialMode = 'reminder';
      } else if (totalGrades > 0) {
        initialMode = 'graded';
      }
    }

    bool isSending = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setS) {
          Widget content;
          if (isSending) {
            content = const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: _kPink),
                SizedBox(height: 12),
                Text('Sending notifications...',
                    style: TextStyle(fontSize: 12, color: _kText2)),
              ],
            );
          } else if (isPendingState) {
            content = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _kWarning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kWarning.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Text('⚠️', style: TextStyle(fontSize: 20)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Evaluation Phase Active',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _kWarning),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'The selected homework assignments are currently pending teacher grading. Students do not need any notifications until grading is complete. No actions will be taken.',
                  style: TextStyle(fontSize: 12, color: _kText2),
                  textAlign: TextAlign.center,
                ),
              ],
            );
          } else {
            content = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select the targeted notification group for the ${selected.length} selected assignments:',
                  style: const TextStyle(
                      fontSize: 12, color: _kText, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () {
                    setS(() {
                      initialMode = 'reminder';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: initialMode == 'reminder'
                          ? _kPink.withValues(alpha: 0.05)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: initialMode == 'reminder' ? _kPink : _kBorder,
                        width: initialMode == 'reminder' ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text('📥', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Send Submission Reminders ($totalReminders students)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: initialMode == 'reminder'
                                      ? _kPink
                                      : _kText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Notify students who have not submitted their homework yet.',
                                style: TextStyle(fontSize: 10, color: _kText3),
                              ),
                            ],
                          ),
                        ),
                        Radio<String>(
                          value: 'reminder',
                          groupValue: initialMode,
                          activeColor: _kPink,
                          onChanged: (val) {
                            if (val != null) setS(() => initialMode = val);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () {
                    setS(() {
                      initialMode = 'graded';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: initialMode == 'graded'
                          ? _kPink.withValues(alpha: 0.05)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: initialMode == 'graded' ? _kPink : _kBorder,
                        width: initialMode == 'graded' ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text('📝', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Send Grade Releases ($totalGrades students)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      initialMode == 'graded' ? _kPink : _kText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Notify students whose assignments have been graded to view results.',
                                style: TextStyle(fontSize: 10, color: _kText3),
                              ),
                            ],
                          ),
                        ),
                        Radio<String>(
                          value: 'graded',
                          groupValue: initialMode,
                          activeColor: _kPink,
                          onChanged: (val) {
                            if (val != null) setS(() => initialMode = val);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Column(
              children: [
                Text('🔔', style: TextStyle(fontSize: 40)),
                SizedBox(height: 4),
                Text('Targeted Notifications',
                    style: TextStyle(
                        fontFamily: AppFonts.heading,
                        fontWeight: FontWeight.w800,
                        color: _kPink,
                        fontSize: 16),
                    textAlign: TextAlign.center),
              ],
            ),
            content: content,
            actions: isSending
                ? []
                : [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogCtx),
                      child: const Text('Cancel',
                          style: TextStyle(color: _kText3)),
                    ),
                    if (!isPendingState)
                      ElevatedButton(
                        onPressed: () async {
                          setS(() {
                            isSending = true;
                          });
                          try {
                            final result = await _apiService
                                .sendBulkHomeworkNotifications(homeworkIds,
                                    mode: initialMode);
                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                              _loadAll();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      '📤 Success! Sent ${result['reminders_sent']} reminders and ${result['grades_sent']} grade notifications.'),
                                  backgroundColor: _kSuccess,
                                ),
                              );
                            }
                          } catch (e) {
                            setS(() {
                              isSending = false;
                            });
                            if (dialogCtx.mounted) {
                              ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: _kError,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kPink,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Send Notifications',
                            style: TextStyle(
                                fontFamily: AppFonts.heading,
                                fontWeight: FontWeight.w700)),
                      ),
                  ],
          );
        },
      ),
    );
  }
}
