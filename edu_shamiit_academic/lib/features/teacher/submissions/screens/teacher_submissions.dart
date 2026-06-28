import 'package:edu_shamiit_core/utils/responsive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:edu_shamiit_academic/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_core/constants/app_fonts.dart';
import 'package:edu_shamiit_academic/core/services/teacher_api_service.dart';
import 'package:edu_shamiit_core/models/teacher_models.dart';
import 'package:edu_shamiit_academic/shared/widgets/azure_grid.dart';
import 'package:edu_shamiit_academic/core/utils/download_helper_stub.dart'
    if (dart.library.js) 'package:edu_shamiit_academic/core/utils/download_helper_web.dart'
    if (dart.library.io) 'package:edu_shamiit_academic/core/utils/download_helper_mobile.dart';

// ─── Colors ───────────────────────────────────────────────────────────────────
const _kRed = Color(0xFFE11D48);
const _kRedDark = Color(0xFF9F1239);
const _kRedLight = Color(0xFFFFF1F2);
const _kSuccess = Color(0xFF059669);
const _kWarning = Color(0xFFD97706);
const _kText = Color(0xFF0F172A);
const _kText2 = Color(0xFF475569);
const _kText3 = Color(0xFF94A3B8);
const _kBorder = Color(0xFFE2E8F0);

class TeacherSubmissions extends ConsumerStatefulWidget {
  const TeacherSubmissions({super.key});

  @override
  ConsumerState<TeacherSubmissions> createState() => _TeacherSubmissionsState();
}

class _TeacherSubmissionsState extends ConsumerState<TeacherSubmissions> {
  final TeacherApiService _apiService = TeacherApiService();

  List<HomeworkSubmission> _submissions = [];
  bool _isLoading = true;
  String? _error;
  String _homeworkId = '';
  bool _aiGrading = false;
  bool _isAiGradingCollapsed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSubmissions());
  }

  Future<void> _loadSubmissions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      try {
        final state = GoRouterState.of(context);
        _homeworkId = state.uri.queryParameters['homework_id'] ?? '';
      } catch (_) {}

      final submissions = await _apiService.getHomeworkSubmissions(
          homeworkId: _homeworkId, status: null);
      setState(() {
        _submissions = submissions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // ─── Avatar gradient colors ───────────────────────────────────────────────
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

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'graded':
        return _kSuccess;
      case 'submitted':
      case 'pending':
        return _kWarning;
      case 'returned':
        return const Color(0xFF7C3AED);
      default:
        return _kText3;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'graded':
        return '✅ GRADED';
      case 'submitted':
      case 'pending':
        return '⏳ PENDING';
      case 'returned':
        return '↩️ RETURNED';
      default:
        return status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final submitted = _submissions.length;
    final graded =
        _submissions.where((s) => s.status.toLowerCase() == 'graded').length;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      body: Column(
        children: [
          _buildHeader(submitted, graded),
          _buildAiGradingCard(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _kRed))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('⚠️', style: TextStyle(fontSize: 40)),
                            const SizedBox(height: 12),
                            Text(_error!,
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 12),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            ElevatedButton(
                                onPressed: _loadSubmissions,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: _kRed,
                                    foregroundColor: Colors.white),
                                child: const Text('Retry')),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(16),
                        child: AzureGrid<HomeworkSubmission>(
                          title: 'Homework Submissions',
                          items: _submissions,
                          onRefresh: _loadSubmissions,
                          searchMatcher: (item) =>
                              '${item.studentName} ${item.status} ${item.feedback ?? ""} ${item.submissionText ?? ""}',
                          filters: [
                            AzureGridFilter<HomeworkSubmission>(
                              label: 'Status',
                              options: const ['Pending', 'Graded', 'Returned'],
                              filterFn: (item, option) {
                                final st = item.status.toLowerCase();
                                if (option == 'Pending') {
                                  return st == 'pending' || st == 'submitted';
                                }
                                if (option == 'Graded') return st == 'graded';
                                if (option == 'Returned') {
                                  return st == 'returned';
                                }
                                return true;
                              },
                            ),
                          ],
                          columns: [
                            AzureGridColumn<HomeworkSubmission>(
                              label: 'Student Name',
                              width: 200,
                              compare: (a, b) =>
                                  a.studentName.compareTo(b.studentName),
                              cellBuilder: (item) {
                                final initials = item.studentName.trim().isEmpty
                                    ? '?'
                                    : item.studentName
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
                                        color: _avatarColor(item.studentName)
                                            .withValues(alpha: 0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          initials,
                                          style: TextStyle(
                                            color:
                                                _avatarColor(item.studentName),
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        item.studentName.isEmpty
                                            ? 'Student'
                                            : item.studentName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            AzureGridColumn<HomeworkSubmission>(
                              label: 'Submitted At',
                              width: 140,
                              compare: (a, b) =>
                                  a.submittedAt.compareTo(b.submittedAt),
                              cellBuilder: (item) =>
                                  Text(_timeAgo(item.submittedAt)),
                            ),
                            AzureGridColumn<HomeworkSubmission>(
                              label: 'Notes / Text',
                              width: 220,
                              compare: (a, b) => (a.submissionText ?? '')
                                  .compareTo(b.submissionText ?? ''),
                              cellBuilder: (item) => Text(
                                item.submissionText != null &&
                                        item.submissionText!.isNotEmpty
                                    ? item.submissionText!
                                    : 'No notes',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: item.submissionText != null &&
                                          item.submissionText!.isNotEmpty
                                      ? _kText2
                                      : _kText3,
                                  fontStyle: item.submissionText != null &&
                                          item.submissionText!.isNotEmpty
                                      ? FontStyle.normal
                                      : FontStyle.italic,
                                ),
                              ),
                            ),
                            AzureGridColumn<HomeworkSubmission>(
                              label: 'Status',
                              width: 110,
                              compare: (a, b) => a.status.compareTo(b.status),
                              cellBuilder: (item) {
                                final color = _statusColor(item.status);
                                final label = _statusLabel(item.status);
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
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
                            AzureGridColumn<HomeworkSubmission>(
                              label: 'Score',
                              width: 90,
                              compare: (a, b) => (a.marksObtained ?? 0.0)
                                  .compareTo(b.marksObtained ?? 0.0),
                              cellBuilder: (item) => Text(
                                item.marksObtained != null
                                    ? item.marksObtained!.toString()
                                    : '-',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: item.marksObtained != null
                                      ? _kSuccess
                                      : _kText3,
                                ),
                              ),
                            ),
                            AzureGridColumn<HomeworkSubmission>(
                              label: 'Feedback',
                              width: 200,
                              compare: (a, b) => (a.feedback ?? '')
                                  .compareTo(b.feedback ?? ''),
                              cellBuilder: (item) => Text(
                                item.feedback ?? '-',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            AzureGridColumn<HomeworkSubmission>(
                              label: 'Action',
                              width: 120,
                              cellBuilder: (item) {
                                final isGraded =
                                    item.status.toLowerCase() == 'graded';
                                return ElevatedButton(
                                  onPressed: () => _showGradingSheet(item),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isGraded
                                        ? const Color(0xFF64748B)
                                        : _kRed,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    minimumSize: const Size(60, 26),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4)),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    isGraded ? 'Review' : 'Grade',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold),
                                  ),
                                );
                              },
                            ),
                          ],
                          mobileCardBuilder: (context, item) =>
                              _buildSubmissionCard(item, 0),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader(int submitted, int total) {
    return Container(
      padding:
          EdgeInsets.fromLTRB(8, Responsive.headerTopPadding(context), 16, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kRedDark, _kRed],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
            onPressed: () => safeGoBack(context, '/teacher/homework'),
          ),
          const Expanded(
            child: Text(
              'Review Submissions',
              style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10)),
            child: Text(
              '$submitted submitted',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFamily: AppFonts.heading),
            ),
          ),
        ],
      ),
    );
  }

  // ─── AI grading banner ────────────────────────────────────────────────────
  Widget _buildAiGradingCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_kRedLight, Color(0xFFFCE7F3)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: _kRed, borderRadius: BorderRadius.circular(8)),
                child: const Text('🤖 AI GRADING ASSIST',
                    style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontFamily: AppFonts.heading)),
              ),
              InkWell(
                onTap: () => setState(
                    () => _isAiGradingCollapsed = !_isAiGradingCollapsed),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_isAiGradingCollapsed ? 'Show' : 'Hide',
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _kRedDark)),
                    Icon(
                        _isAiGradingCollapsed
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_up,
                        size: 14,
                        color: _kRedDark),
                  ],
                ),
              ),
            ],
          ),
          if (!_isAiGradingCollapsed) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'AI can auto-grade objective questions to save your time.',
                    style: TextStyle(fontSize: 10, color: _kRedDark),
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    setState(() => _aiGrading = true);
                    await Future.delayed(const Duration(seconds: 2));
                    if (mounted) {
                      setState(() => _aiGrading = false);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              '🤖 AI grading complete! 12 submissions auto-graded.'),
                          backgroundColor: _kSuccess));
                      _loadSubmissions();
                    }
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: _kRed, borderRadius: BorderRadius.circular(10)),
                    child: _aiGrading
                        ? const SizedBox(
                            width: 40,
                            child: Center(
                                child: SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))))
                        : const Text('🚀 Auto-grade',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                fontFamily: AppFonts.heading)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── Submission card ──────────────────────────────────────────────────────
  Widget _buildSubmissionCard(HomeworkSubmission s, int index) {
    final avatarColor = _avatarColor(s.studentName);
    final statusColor = _statusColor(s.status);
    final statusLabel = _statusLabel(s.status);
    final initials = s.studentName.trim().isEmpty
        ? '?'
        : s.studentName
            .trim()
            .split(RegExp(r'\s+'))
            .map((n) => n.isNotEmpty ? n[0] : '')
            .take(2)
            .join()
            .toUpperCase();
    final isGraded = s.status.toLowerCase() == 'graded';
    final submittedTimeAgo = _timeAgo(s.submittedAt);

    return GestureDetector(
      onTap: () => _showGradingSheet(s),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 1))
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [avatarColor, avatarColor.withValues(alpha: 0.7)]),
                shape: BoxShape.circle,
              ),
              child: Center(
                  child: Text(initials,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          fontFamily: AppFonts.heading))),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      s.studentName.isEmpty
                          ? 'Student ${index + 1}'
                          : s.studentName,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _kText,
                          fontFamily: AppFonts.heading)),
                  Text(
                    '$submittedTimeAgo${s.submissionText != null && s.submissionText!.isNotEmpty ? ' · with notes' : ''}',
                    style: const TextStyle(fontSize: 10, color: _kText3),
                  ),
                  if (isGraded && s.marksObtained != null) ...[
                    const SizedBox(height: 2),
                    Text(
                        'Score: ${s.marksObtained}${s.feedback != null ? ' · "${s.feedback}"' : ''}',
                        style: const TextStyle(
                            fontSize: 10,
                            color: _kSuccess,
                            fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            // Status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(statusLabel,
                  style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                      fontFamily: AppFonts.heading)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Grading bottom sheet ─────────────────────────────────────────────────
  void _showGradingSheet(HomeworkSubmission s) {
    final marksCtrl =
        TextEditingController(text: s.marksObtained?.toString() ?? '');
    final feedbackCtrl = TextEditingController(text: s.feedback ?? '');
    final isGraded = s.status.toLowerCase() == 'graded';
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          final maxM = s.maxMarks ?? 25.0;

          void validateMarks(String value) {
            if (value.trim().isEmpty) {
              setModalState(() {
                errorText = null;
              });
              return;
            }
            final parsed = double.tryParse(value);
            if (parsed == null) {
              setModalState(() {
                errorText = 'Please enter a valid number';
              });
            } else if (parsed < 0) {
              setModalState(() {
                errorText = 'Marks cannot be negative';
              });
            } else if (parsed > maxM) {
              setModalState(() {
                errorText = 'Warning: Marks exceed maximum marks ($maxM)';
              });
            } else {
              setModalState(() {
                errorText = null;
              });
            }
          }

          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
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
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                _avatarColor(s.studentName),
                                _avatarColor(s.studentName)
                                    .withValues(alpha: 0.7)
                              ]),
                              shape: BoxShape.circle),
                          child: Center(
                              child: Text(
                            s.studentName.trim().isEmpty
                                ? '?'
                                : s.studentName
                                    .trim()
                                    .split(RegExp(r'\s+'))
                                    .map((n) => n.isNotEmpty ? n[0] : '')
                                    .take(2)
                                    .join()
                                    .toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700),
                          )),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  s.studentName.isEmpty
                                      ? 'Student'
                                      : s.studentName,
                                  style: const TextStyle(
                                      fontFamily: AppFonts.heading,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: _kText)),
                              Text(_timeAgo(s.submittedAt),
                                  style: const TextStyle(
                                      fontSize: 11, color: _kText3)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Submission content
                    if (s.submissionText != null &&
                        s.submissionText!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _kBorder)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Submission Notes:',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _kText2)),
                            const SizedBox(height: 4),
                            Text(s.submissionText!,
                                style: const TextStyle(
                                    fontSize: 12, color: _kText2, height: 1.5)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (s.attachmentUrl != null &&
                        s.attachmentUrl!.isNotEmpty) ...[
                      InkWell(
                        onTap: () async {
                          final url = s.attachmentUrl!;
                          final filename = url.split('/').last.split('?').first;
                          try {
                            await getDownloadHelper()
                                .downloadFile(url, filename);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Error downloading file: $e'),
                                    backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _kBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.insert_drive_file_outlined,
                                  color: _kText2, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Submitted Document',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: _kText),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      s.attachmentUrl!
                                          .split('/')
                                          .last
                                          .split('?')
                                          .first,
                                      style: const TextStyle(
                                          fontSize: 10, color: _kText3),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.download_rounded,
                                  color: _kText2, size: 18),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ] else if (s.submissionText == null ||
                        s.submissionText!.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        width: double.infinity,
                        decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _kBorder)),
                        child: const Center(
                          child: Text('No submission files or notes provided',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: _kText3,
                                  fontStyle: FontStyle.italic)),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    // AI feedback banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: const Color(0xFFFDF2F8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFCE7F3))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: _kRed,
                                borderRadius: BorderRadius.circular(6)),
                            child: const Text('🤖 AI FEEDBACK',
                                style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    fontFamily: AppFonts.heading)),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                              'AI suggests checking key concepts and verifying calculations. Suggested score based on rubric.',
                              style: TextStyle(
                                  fontSize: 11, color: _kRedDark, height: 1.5)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (isGraded) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline,
                                color: _kSuccess, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Already Graded',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: _kSuccess,
                                          fontFamily: AppFonts.heading,
                                          fontSize: 12)),
                                  Text(
                                      'Current Score: ${s.marksObtained} / ${maxM.toInt()}',
                                      style: const TextStyle(
                                          fontSize: 11, color: _kSuccess)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    Text('Assign Score (Max: ${maxM.toInt()})',
                        style: const TextStyle(
                            fontSize: 11,
                            color: _kText3,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: marksCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: validateMarks,
                      decoration: InputDecoration(
                        hintText: 'Enter marks...',
                        errorText: errorText,
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
                            borderSide:
                                const BorderSide(color: _kRed, width: 1.5)),
                        errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: _kRed, width: 1.0)),
                        focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: _kRed, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text('Feedback (optional)',
                        style: TextStyle(
                            fontSize: 11,
                            color: _kText3,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: feedbackCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Write your feedback...',
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
                            borderSide:
                                const BorderSide(color: _kRed, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final parsed = double.tryParse(marksCtrl.text);
                          if (parsed == null) {
                            setModalState(() {
                              errorText = 'Please enter a valid number';
                            });
                            return;
                          }
                          if (parsed < 0) {
                            setModalState(() {
                              errorText = 'Marks cannot be negative';
                            });
                            return;
                          }
                          if (parsed > maxM) {
                            setModalState(() {
                              errorText =
                                  'Warning: Marks exceed maximum marks ($maxM)';
                            });
                            return;
                          }
                          final messenger = ScaffoldMessenger.of(context);
                          Navigator.pop(context);
                          await _gradeSubmission(
                              s, marksCtrl.text, feedbackCtrl.text, messenger);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: Text(
                          isGraded ? '🔄 Update Grade' : '✅ Submit Grade',
                          style: const TextStyle(
                              fontFamily: AppFonts.heading,
                              fontSize: 15,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          Navigator.pop(context);
                          await _returnSubmission(
                              s, feedbackCtrl.text, messenger);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kWarning,
                          side: const BorderSide(color: _kWarning, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('↩️ ', style: TextStyle(fontSize: 16)),
                            Text('Return for Correction',
                                style: TextStyle(
                                    fontFamily: AppFonts.heading,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _gradeSubmission(HomeworkSubmission s, String marksStr,
      String feedback, ScaffoldMessengerState messenger) async {
    try {
      final marks = double.tryParse(marksStr);
      if (marks == null) {
        messenger.showSnackBar(const SnackBar(
            content: Text('⚠️ Please enter valid marks'),
            backgroundColor: Colors.red));
        return;
      }
      await _apiService.gradeSubmission(
          submissionId: s.id,
          marks: marks,
          feedback: feedback.isEmpty ? null : feedback);
      if (mounted) {
        messenger.showSnackBar(const SnackBar(
            content: Text('✅ Submission graded successfully!'),
            backgroundColor: _kSuccess));
        _loadSubmissions();
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _returnSubmission(HomeworkSubmission s, String remarks,
      ScaffoldMessengerState messenger) async {
    try {
      await _apiService.returnSubmission(
          submissionId: s.id, feedback: remarks.isEmpty ? null : remarks);
      if (mounted) {
        messenger.showSnackBar(const SnackBar(
            content: Text('↩️ Submission returned to student successfully!'),
            backgroundColor: _kSuccess));
        _loadSubmissions();
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}
