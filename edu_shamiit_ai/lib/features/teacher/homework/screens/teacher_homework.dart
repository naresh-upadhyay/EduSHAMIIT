import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/services/teacher_api_service.dart';
import 'package:edu_shamiit_ai/core/models/teacher_models.dart';

// ─── Color tokens (teacher palette) ─────────────────────────────────────────
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

class TeacherHomework extends ConsumerStatefulWidget {
  const TeacherHomework({super.key});

  @override
  ConsumerState<TeacherHomework> createState() => _TeacherHomeworkState();
}

class _TeacherHomeworkState extends ConsumerState<TeacherHomework>
    with SingleTickerProviderStateMixin {
  final TeacherApiService _apiService = TeacherApiService();
  late TabController _tabController;

  List<TeacherHomeworkAssignment> _active = [];
  List<TeacherHomeworkAssignment> _submissions = [];
  List<TeacherHomeworkAssignment> _graded = [];
  bool _isLoading = true;
  String? _error;

  // Create form fields
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _marksCtrl = TextEditingController(text: '25');
  String _selectedClass = 'X-A';
  String _selectedSubject = 'Mathematics';
  DateTime _dueDate = DateTime.now().add(const Duration(days: 3));

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _marksCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final results = await Future.wait([
        _apiService.getHomeworkAssignments(status: 'active'),
        _apiService.getHomeworkAssignments(status: 'pending'),
        _apiService.getHomeworkAssignments(status: 'completed'),
      ]);
      setState(() {
        _active = results[0];
        _submissions = results[1];
        _graded = results[2];
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  // ─── Subject icon helper ──────────────────────────────────────────────────
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

  // ─── Due colour ───────────────────────────────────────────────────────────
  Color _dueColor(TeacherHomeworkAssignment hw) {
    if (hw.isOverdue) return _kError;
    final diff = hw.dueDate.difference(DateTime.now()).inDays;
    if (diff == 0) return _kError;
    if (diff <= 2) return _kWarning;
    return _kSuccess;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPinkBg,
      body: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _kPink))
                : _error != null
                    ? _buildError()
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildActiveTab(),
                          _buildSubmissionsTab(),
                          _buildGradedTab(),
                        ],
                      ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateModal,
        backgroundColor: _kPink,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create', style: TextStyle(fontFamily: AppFonts.heading, fontWeight: FontWeight.w700)),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(8, Responsive.headerTopPadding(context), 16, 12),
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
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
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
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  // ─── Tab bar ──────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    final tabs = [
      'Active (${_active.length})',
      'Submissions (${_submissions.length})',
      'Graded (${_graded.length})',
    ];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final sel = _tabController.index == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => _tabController.animateTo(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(right: i < tabs.length - 1 ? 6 : 0, bottom: 10),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? _kPink : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: sel ? _kPink : _kBorder),
                ),
                child: Text(
                  tabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: sel ? Colors.white : _kText3,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─── Active Tab ───────────────────────────────────────────────────────────
  Widget _buildActiveTab() {
    if (_active.isEmpty) return _buildEmpty('No active homework', '📝');
    return RefreshIndicator(
      onRefresh: _loadAll,
      color: _kPink,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 100),
        itemCount: _active.length,
        itemBuilder: (_, i) => _buildActiveCard(_active[i]),
      ),
    );
  }

  Widget _buildActiveCard(TeacherHomeworkAssignment hw) {
    final color = _dueColor(hw);
    final icon = _subjectIcon(hw.subject);
    final pct = hw.submissionRate;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Class + submission count row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$icon ${hw.class_} · ${hw.subject}',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color, fontFamily: AppFonts.heading),
                  ),
                ),
                Text(
                  '${hw.submittedCount}/${hw.totalCount} submitted',
                  style: const TextStyle(fontSize: 10, color: _kText3),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(hw.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kText, fontFamily: AppFonts.heading)),
            const SizedBox(height: 4),
            Text(
              hw.description,
              style: const TextStyle(fontSize: 11, color: _kText3, height: 1.5),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // Progress bar
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
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: _buildBtn(
                    label: '📋 Review (${hw.submittedCount})',
                    bg: color,
                    fg: Colors.white,
                    onTap: () => context.push('/teacher/submissions?homework_id=${hw.id}'),
                  ),
                ),
                const SizedBox(width: 6),
                _buildIconBtn(icon: '⏰', bg: _kPinkLight, fg: _kPink, onTap: () => _showReminderDialog(hw)),
                const SizedBox(width: 6),
                _buildIconBtn(icon: '⋯', bg: _kPinkLight, fg: _kPink, onTap: () => _showEditSheet(hw)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Submissions Tab ──────────────────────────────────────────────────────
  Widget _buildSubmissionsTab() {
    final all = [..._active, ..._submissions];
    if (all.isEmpty) return _buildEmpty('No submissions yet', '📋');
    return RefreshIndicator(
      onRefresh: _loadAll,
      color: _kPink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _kPink.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '📊 Overview of recent submissions across all classes.',
              style: TextStyle(fontSize: 11, color: _kPink, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 100),
              itemCount: all.length,
              itemBuilder: (_, i) => _buildSubmissionRow(all[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionRow(TeacherHomeworkAssignment hw) {
    final icon = _subjectIcon(hw.subject);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: _kPinkLight, borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${hw.subject} — ${hw.class_}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kText)),
                Text('${hw.title} · ${hw.submittedCount} Submissions', style: const TextStyle(fontSize: 10, color: _kText3)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => context.push('/teacher/submissions?homework_id=${hw.id}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPink,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('View All', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, fontFamily: AppFonts.heading)),
          ),
        ],
      ),
    );
  }

  // ─── Graded Tab ───────────────────────────────────────────────────────────
  Widget _buildGradedTab() {
    if (_graded.isEmpty) return _buildEmpty('No graded homework yet', '✅');
    return RefreshIndicator(
      onRefresh: _loadAll,
      color: _kPink,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Text('✅ ', style: TextStyle(fontSize: 14)),
              Expanded(
                child: Text(
                  'Great job! ${_graded.length} homework tasks were graded this week.',
                  style: const TextStyle(fontSize: 11, color: _kSuccess, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 100),
              itemCount: _graded.length,
              itemBuilder: (_, i) => _buildGradedRow(_graded[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradedRow(TeacherHomeworkAssignment hw) {
    final icon = _subjectIcon(hw.subject);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${hw.subject} — ${hw.class_}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kText)),
                Text('${hw.title} · Graded: ${hw.submittedCount}/${hw.totalCount}', style: const TextStyle(fontSize: 10, color: _kText3)),
              ],
            ),
          ),
          const Text('COMPLETED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _kSuccess, fontFamily: AppFonts.heading)),
        ],
      ),
    );
  }

  // ─── Edit bottom sheet ────────────────────────────────────────────────────
  void _showEditSheet(TeacherHomeworkAssignment hw) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(hw.title, textAlign: TextAlign.center, style: const TextStyle(fontFamily: AppFonts.heading, fontSize: 14, fontWeight: FontWeight.w800, color: _kText)),
            const SizedBox(height: 4),
            Text('${hw.class_} · ${hw.subject}', style: const TextStyle(fontSize: 11, color: _kText3)),
            const SizedBox(height: 20),
            _buildSheetOption(emoji: '📋', label: 'Review Submissions', sublabel: '${hw.submittedCount} submitted', color: _kPink, onTap: () { Navigator.pop(context); context.push('/teacher/submissions?homework_id=${hw.id}'); }),
            _buildSheetOption(emoji: '✏️', label: 'Edit Assignment Details', sublabel: 'Change title, dates, marks', color: const Color(0xFF7C3AED), onTap: () { Navigator.pop(context); _showEditAssignmentModal(hw); }),
            _buildSheetOption(emoji: '🔔', label: 'Send Reminder', sublabel: 'Notify students who haven\'t submitted', color: const Color(0xFFD97706), onTap: () { Navigator.pop(context); _showReminderDialog(hw); }),
            _buildSheetOption(emoji: '📊', label: 'View Analytics', sublabel: 'Submission trends and performance', color: const Color(0xFF0EA5E9), onTap: () { Navigator.pop(context); _showAnalytics(hw); }),
            _buildSheetOption(emoji: '🗑️', label: 'Delete Assignment', sublabel: 'This action cannot be undone', color: _kError, onTap: () { Navigator.pop(context); _confirmDelete(hw); }),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetOption({required String emoji, required String label, required String sublabel, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color, fontFamily: AppFonts.heading)),
                  Text(sublabel, style: const TextStyle(fontSize: 10, color: _kText3)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color.withOpacity(0.5), size: 18),
          ],
        ),
      ),
    );
  }

  // ─── Create Assignment Modal ───────────────────────────────────────────────
  void _showCreateModal() {
    _titleCtrl.clear();
    _descCtrl.clear();
    _marksCtrl.text = '25';
    _selectedClass = 'X-A';
    _selectedSubject = 'Mathematics';
    _dueDate = DateTime.now().add(const Duration(days: 3));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: StatefulBuilder(builder: (ctx, setS) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                const Center(child: Text('📝 Create Assignment', style: TextStyle(fontFamily: AppFonts.heading, fontSize: 16, fontWeight: FontWeight.w800, color: _kText))),
                const SizedBox(height: 16),
                _buildLabel('Title'),
                _buildInput(_titleCtrl, 'Assignment title...'),
                _buildLabel('Class'),
                _buildDropdown(
                  value: _selectedClass,
                  items: ['X-A', 'X-B', 'IX-A', 'IX-B', 'VIII-A', 'VIII-B'],
                  onChanged: (v) => setS(() => _selectedClass = v!),
                ),
                _buildLabel('Subject'),
                _buildDropdown(
                  value: _selectedSubject,
                  items: ['Mathematics', 'Physics', 'Chemistry', 'Biology', 'English', 'History', 'Geography', 'Computer Science'],
                  onChanged: (v) => setS(() => _selectedSubject = v!),
                ),
                _buildLabel('Due Date'),
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _dueDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
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
                        const Icon(Icons.calendar_today_outlined, size: 14, color: _kText2),
                        const SizedBox(width: 8),
                        Text('${_dueDate.day}/${_dueDate.month}/${_dueDate.year}', style: const TextStyle(fontSize: 13, color: _kText)),
                      ],
                    ),
                  ),
                ),
                _buildLabel('Max Marks'),
                _buildInput(_marksCtrl, '25', type: TextInputType.number),
                _buildLabel('Instructions'),
                _buildInput(_descCtrl, 'Write instructions for students...', maxLines: 3),
                const SizedBox(height: 8),
                // Attach section (visual only)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: _kBorder, width: 1.5),
                    borderRadius: BorderRadius.circular(14),
                    color: const Color(0xFFF8FAFC),
                  ),
                  child: const Column(
                    children: [
                      Text('📎', style: TextStyle(fontSize: 24)),
                      SizedBox(height: 4),
                      Text('Attach Files (optional)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kText)),
                      Text('PDF, DOC, JPG up to 10MB', style: TextStyle(fontSize: 10, color: _kText3)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _createHomework(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPink,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text('📤 Assign to Class', style: TextStyle(fontFamily: AppFonts.heading, fontSize: 15, fontWeight: FontWeight.w700)),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontFamily: AppFonts.heading, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        )),
      ),
    );
  }

  Future<void> _createHomework(BuildContext ctx) async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please enter a title'), backgroundColor: _kError));
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
      );
      _loadAll();
      if (mounted) {
        _showSuccessDialog('Assignment Created! 🎉', '${_titleCtrl.text} has been assigned to $_selectedClass. Students will be notified.');
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: _kError));
      }
    }
  }

  // ─── Edit assignment modal ─────────────────────────────────────────────────
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
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: StatefulBuilder(builder: (ctx, setS) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                const Center(child: Text('✏️ Edit Assignment', style: TextStyle(fontFamily: AppFonts.heading, fontSize: 16, fontWeight: FontWeight.w800, color: _kText))),
                const SizedBox(height: 16),
                _buildLabel('Title'),
                _buildInput(_titleCtrl, 'Assignment title...'),
                _buildLabel('Max Marks'),
                _buildInput(_marksCtrl, '25', type: TextInputType.number),
                _buildLabel('Due Date'),
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(context: context, initialDate: editDue, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (d != null) setS(() => editDue = d);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: _kBorder)),
                    child: Row(children: [
                      const Icon(Icons.calendar_today_outlined, size: 14, color: _kText2),
                      const SizedBox(width: 8),
                      Text('${editDue.day}/${editDue.month}/${editDue.year}', style: const TextStyle(fontSize: 13, color: _kText)),
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
                        await _apiService.updateHomework(homeworkId: hw.id, updates: {'title': _titleCtrl.text.trim(), 'max_marks': int.tryParse(_marksCtrl.text), 'due_date': editDue.toIso8601String().split('T')[0]});
                        _loadAll();
                        if (mounted) _showSuccessDialog('Saved! 💾', 'Assignment updated successfully.');
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: _kError));
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: _kPink, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                    child: const Text('💾 Save Changes', style: TextStyle(fontFamily: AppFonts.heading, fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => Navigator.pop(ctx), style: OutlinedButton.styleFrom(foregroundColor: _kPink, side: const BorderSide(color: _kPink), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: const Text('Cancel', style: TextStyle(fontFamily: AppFonts.heading, fontWeight: FontWeight.w700)))),
              ],
            ),
          ),
        )),
      ),
    );
  }

  // ─── Reminder dialog ──────────────────────────────────────────────────────
  void _showReminderDialog(TeacherHomeworkAssignment hw) {
    final pending = hw.totalCount - hw.submittedCount;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(children: [Text('🔔', style: TextStyle(fontSize: 40)), SizedBox(height: 4), Text('Send Reminder?', style: TextStyle(fontFamily: AppFonts.heading, fontWeight: FontWeight.w800, color: _kPink))]),
        content: Text('Send a push notification to $pending students who haven\'t submitted "${hw.title}".', style: const TextStyle(fontSize: 12, color: _kText2), textAlign: TextAlign.center),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: _kText3))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📤 Reminder sent to students!'), backgroundColor: _kSuccess));
            },
            style: ElevatedButton.styleFrom(backgroundColor: _kPink, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('📤 Send Reminder', style: TextStyle(fontFamily: AppFonts.heading, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ─── Analytics dialog ─────────────────────────────────────────────────────
  void _showAnalytics(TeacherHomeworkAssignment hw) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('📊 ${hw.title}', style: const TextStyle(fontFamily: AppFonts.heading, fontSize: 16, fontWeight: FontWeight.w800, color: _kText)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatBox('${hw.submittedCount}', 'Submitted', _kSuccess),
                _buildStatBox('${hw.totalCount - hw.submittedCount}', 'Pending', _kWarning),
                _buildStatBox('${hw.submissionRate.toInt()}%', 'Rate', _kPink),
                _buildStatBox('${hw.maxMarks ?? 25}', 'Max Marks', const Color(0xFF7C3AED)),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () { Navigator.pop(context); context.push('/teacher/submissions?homework_id=${hw.id}'); },
                style: ElevatedButton.styleFrom(backgroundColor: _kPink, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text('View All Submissions', style: TextStyle(fontFamily: AppFonts.heading, fontWeight: FontWeight.w700)),
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
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontFamily: AppFonts.heading, fontSize: 20, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 9, color: _kText3, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ─── Delete confirm ───────────────────────────────────────────────────────
  void _confirmDelete(TeacherHomeworkAssignment hw) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Assignment?', style: TextStyle(fontFamily: AppFonts.heading, fontWeight: FontWeight.w800, color: _kError)),
        content: Text('Are you sure you want to delete "${hw.title}"? This action cannot be undone.', style: const TextStyle(fontSize: 12, color: _kText2)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: _kText3))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _apiService.deleteHomework(hw.id);
                _loadAll();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assignment deleted'), backgroundColor: _kSuccess));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: _kError));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _kError, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('🗑️ Delete', style: TextStyle(fontFamily: AppFonts.heading, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ─── Success dialog ───────────────────────────────────────────────────────
  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(children: [
          const Text('✅', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontFamily: AppFonts.heading, fontWeight: FontWeight.w800, color: _kSuccess), textAlign: TextAlign.center),
        ]),
        content: Text(message, style: const TextStyle(fontSize: 12, color: _kText2), textAlign: TextAlign.center),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: _kPink, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Done', style: TextStyle(fontFamily: AppFonts.heading, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Empty state ──────────────────────────────────────────────────────────
  Widget _buildEmpty(String text, String emoji) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(fontSize: 14, color: _kText3, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _showCreateModal,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Create Homework', style: TextStyle(fontFamily: AppFonts.heading, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(backgroundColor: _kPink, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
          Text(_error ?? 'Something went wrong', style: const TextStyle(color: _kError, fontSize: 13)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _loadAll, style: ElevatedButton.styleFrom(backgroundColor: _kPink, foregroundColor: Colors.white), child: const Text('Retry')),
        ],
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(text, style: const TextStyle(fontSize: 11, color: _kText3, fontWeight: FontWeight.w700)),
  );

  Widget _buildInput(TextEditingController ctrl, String hint, {TextInputType type = TextInputType.text, int maxLines = 1}) {
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kPink, width: 1.5)),
          contentPadding: const EdgeInsets.all(12),
        ),
      ),
    );
  }

  Widget _buildDropdown({required String value, required List<String> items, required void Function(String?) onChanged}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        style: const TextStyle(fontSize: 13, color: _kText),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildBtn({required String label, required Color bg, required Color fg, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg, fontFamily: AppFonts.heading)),
      ),
    );
  }

  Widget _buildIconBtn({required String icon, required Color bg, required Color fg, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Center(child: Text(icon, style: TextStyle(fontSize: 14, color: fg))),
      ),
    );
  }
}
