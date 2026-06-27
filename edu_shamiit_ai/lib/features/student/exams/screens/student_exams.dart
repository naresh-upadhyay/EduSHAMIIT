import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/services/student_api_service.dart';
import 'package:edu_shamiit_ai/core/models/student_models.dart';
import 'package:edu_shamiit_ai/shared/widgets/azure_grid.dart';
import 'dart:async';

/// Student Exams Screen - Premium Dashboard for both Online & Offline Exams
class StudentExamsScreen extends ConsumerStatefulWidget {
  const StudentExamsScreen({super.key});

  @override
  ConsumerState<StudentExamsScreen> createState() => _StudentExamsScreenState();
}

class _StudentExamsScreenState extends ConsumerState<StudentExamsScreen> {
  final StudentApiService _apiService = StudentApiService();

  // Timer for updating live progress status dynamically
  Timer? _timer;

  List<ExamSchedule> _allExams = [];
  List<String> _categories = ['All'];
  bool _isLoading = true;
  String? _error;
  bool _isAiBannerCollapsed = true;

  @override
  void initState() {
    super.initState();
    _loadExams();
    // Refresh UI every 10 seconds to update countdown/active statuses dynamically
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadExams() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final examsList = await _apiService.getExamSchedule();
      examsList.sort((a, b) => b.dateTime.compareTo(a.dateTime));

      final Set<String> catSet = {};
      for (var e in examsList) {
        if (e.examCategory.trim().isNotEmpty) {
          catSet.add(e.examCategory.trim());
        }
      }
      final dynamicCats = catSet.toList()..sort();

      setState(() {
        _allExams = examsList;
        _categories = ['All', ...dynamicCats];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  String _getSubjectIcon(String subject) {
    const icons = {
      'Mathematics': '📐',
      'Physics': '⚛️',
      'Chemistry': '⚗️',
      'English': '📖',
      'Computer Science': '💻',
      'History': '📜',
      'Biology': '🧬',
    };
    return icons[subject] ?? '📚';
  }

  Color _getTypeColor(String category) {
    switch (category.toLowerCase()) {
      case 'term':
      case 'mid term':
        return Colors.blue;
      case 'unit':
      case 'unit test':
      case 'weekly test':
        return Colors.green;
      case 'quiz':
      case 'practice test':
        return Colors.orange;
      case 'final':
      case 'final exam':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getMonthAbbreviation(int month) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC'
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body:
            Center(child: CircularProgressIndicator(color: Color(0xFF134E4A))),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading exams: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadExams,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF134E4A)),
                child: Text('Retry'.tr(ref),
                    style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final now = DateTime.now();
    final upcomingExams =
        _allExams.where((e) => now.isBefore(e.dateTime)).toList();
    Widget? countdownWidget;
    if (upcomingExams.isNotEmpty) {
      countdownWidget = _buildNextExamCountdownCard(
        upcomingExams.reduce((a, b) => a.dateTime.isBefore(b.dateTime) ? a : b),
      );
    }

    // Grid Columns
    final columns = [
      AzureGridColumn<ExamSchedule>(
        label: 'Date',
        width: 80.0,
        compare: (a, b) => a.dateTime.compareTo(b.dateTime),
        cellBuilder: (exam) {
          final date = exam.dateTime.toLocal();
          return Text(
            '${date.day.toString().padLeft(2, '0')} ${_getMonthAbbreviation(date.month)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          );
        },
      ),
      AzureGridColumn<ExamSchedule>(
        label: 'Subject',
        width: 140.0,
        compare: (a, b) => a.subject.compareTo(b.subject),
        cellBuilder: (exam) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_getSubjectIcon(exam.subject)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                exam.subject,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      AzureGridColumn<ExamSchedule>(
        label: 'Title',
        width: 160.0,
        compare: (a, b) => a.title.compareTo(b.title),
        cellBuilder: (exam) => Text(
          exam.title.isNotEmpty ? exam.title : 'Assessment',
          overflow: TextOverflow.ellipsis,
        ),
      ),
      AzureGridColumn<ExamSchedule>(
        label: 'Type',
        width: 90.0,
        compare: (a, b) => a.examType.compareTo(b.examType),
        cellBuilder: (exam) {
          final isOnline = exam.examType.toLowerCase() == 'online';
          final tagBg =
              isOnline ? const Color(0xFFEEF2FF) : const Color(0xFFF0FDF4);
          final tagText =
              isOnline ? const Color(0xFF4F46E5) : const Color(0xFF16A34A);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: tagBg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isOnline ? '🖥️ Online' : '📝 Offline',
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.bold, color: tagText),
            ),
          );
        },
      ),
      AzureGridColumn<ExamSchedule>(
        label: 'Category',
        width: 110.0,
        compare: (a, b) => a.examCategory.compareTo(b.examCategory),
        cellBuilder: (exam) {
          final color = _getTypeColor(exam.examCategory);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(
              exam.examCategory.trim().isEmpty ? 'General' : exam.examCategory,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          );
        },
      ),
      AzureGridColumn<ExamSchedule>(
        label: 'Schedule',
        width: 150.0,
        cellBuilder: (exam) {
          final date = exam.dateTime.toLocal();
          final hour = date.hour;
          final minute = date.minute.toString().padLeft(2, '0');
          final period = hour >= 12 ? 'PM' : 'AM';
          final formattedHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
          final formattedTime = '$formattedHour:$minute $period';
          return Text('$formattedTime (${exam.duration})');
        },
      ),
      AzureGridColumn<ExamSchedule>(
        label: 'Venue',
        width: 120.0,
        cellBuilder: (exam) {
          final isOnline = exam.examType.toLowerCase() == 'online';
          return Text(isOnline ? 'Online Portal' : exam.venue,
              overflow: TextOverflow.ellipsis);
        },
      ),
      AzureGridColumn<ExamSchedule>(
        label: 'Max Marks',
        width: 90.0,
        compare: (a, b) => a.totalMarks.compareTo(b.totalMarks),
        cellBuilder: (exam) => Text('${exam.totalMarks} Marks'),
      ),
      AzureGridColumn<ExamSchedule>(
        label: 'Status / Actions',
        width: 210.0,
        cellBuilder: (exam) {
          final status = exam.submissionStatus;
          final isDone = status == 'graded' ||
              status == 'submitted' ||
              exam.sessionStatus == 'completed';

          if (isDone) {
            String statusText = 'Submitted';
            Color textCol = const Color(0xFF1D4ED8);
            if (status == 'graded' && exam.obtainedScore != null) {
              statusText = 'Graded: ${exam.obtainedScore}/${exam.totalMarks}';
              textCol = const Color(0xFF15803D);
              return InkWell(
                onTap: () => context.push('/student/exams/result/${exam.id}'),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.analytics_outlined, size: 14, color: textCol),
                      const SizedBox(width: 4),
                      Text(statusText,
                          style: TextStyle(
                              color: textCol, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              );
            } else if (exam.sessionStatus == 'completed' &&
                status != 'submitted') {
              statusText = 'Unsubmitted';
              textCol = const Color(0xFFF97316); // Orange
            }
            return Text(statusText,
                style: TextStyle(color: textCol, fontWeight: FontWeight.bold));
          }

          final isActive =
              now.isAfter(exam.dateTime) && now.isBefore(exam.endTime);
          final isUpcoming = now.isBefore(exam.dateTime);

          if (isActive) {
            final isOnline = exam.examType.toLowerCase() == 'online';
            if (isOnline) {
              return SizedBox(
                height: 28,
                child: ElevatedButton(
                  onPressed: () =>
                      context.push('/student/exams/details/${exam.id}'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    backgroundColor: Colors.red,
                  ),
                  child: Text(
                    (status == 'active' || exam.hasSession)
                        ? 'Resume Now'
                        : 'Join Now',
                    style: const TextStyle(fontSize: 11, color: Colors.white),
                  ),
                ),
              );
            } else {
              return Text('Venue: ${exam.venue}',
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold));
            }
          } else if (isUpcoming) {
            final diff = exam.dateTime.difference(now);
            final hours = diff.inHours;
            final mins = diff.inMinutes.remainder(60);
            String text = 'Starts in ';
            if (hours > 24) {
              text += '${diff.inDays} days';
            } else {
              text += '${hours}h ${mins}m';
            }
            return Text('⏳ $text',
                style: const TextStyle(
                    color: Color(0xFF64748B), fontWeight: FontWeight.bold));
          } else {
            String statusText = 'Completed';
            Color textCol = const Color(0xFF475569);
            if (status == 'active' || exam.hasSession) {
              statusText = 'Unsubmitted';
              textCol = const Color(0xFFF97316); // Orange
            } else if (exam.examType.toLowerCase() == 'online') {
              statusText = 'Absent';
              textCol = const Color(0xFF991B1B);
            }
            return Text(statusText,
                style: TextStyle(color: textCol, fontWeight: FontWeight.bold));
          }
        },
      ),
    ];

    // Grid Filters
    final filters = [
      AzureGridFilter<ExamSchedule>(
        label: 'Category',
        options: _categories.where((c) => c != 'All').toList(),
        filterFn: (exam, selected) =>
            exam.examCategory.trim().toLowerCase() ==
            selected.trim().toLowerCase(),
      ),
      AzureGridFilter<ExamSchedule>(
        label: 'Type',
        options: ['Online', 'Offline'],
        filterFn: (exam, selected) =>
            exam.examType.trim().toLowerCase() == selected.trim().toLowerCase(),
      ),
      AzureGridFilter<ExamSchedule>(
        label: 'Status',
        options: ['Active', 'Upcoming', 'Completed'],
        filterFn: (exam, selected) {
          if (selected == 'Active') {
            return now.isAfter(exam.dateTime) && now.isBefore(exam.endTime);
          } else if (selected == 'Upcoming') {
            return now.isBefore(exam.dateTime);
          } else {
            return now.isAfter(exam.endTime);
          }
        },
      ),
    ];

    String searchMatcher(ExamSchedule exam) {
      return '${exam.subject} ${exam.title} ${exam.venue} ${exam.examCategory}';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF9),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Collapsible Toggle Button
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => setState(
                        () => _isAiBannerCollapsed = !_isAiBannerCollapsed),
                    icon: Icon(
                        _isAiBannerCollapsed
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_up,
                        size: 16),
                    label: Text(
                        _isAiBannerCollapsed
                            ? 'Show AI Assistant'
                            : 'Hide AI Assistant',
                        style: const TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF0F766E),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                    ),
                  ),
                ],
              ),
            ),

            // Main Responsive Content
            if (!_isAiBannerCollapsed) ...[
              if (Responsive.isWide(context)) ...[
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: countdownWidget != null
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: countdownWidget),
                            const SizedBox(width: 16),
                            Expanded(child: _buildAiPrepCard()),
                          ],
                        )
                      : _buildAiPrepCard(),
                ),
              ] else ...[
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Column(
                    children: [
                      if (countdownWidget != null) countdownWidget,
                      const SizedBox(height: 8),
                      _buildAiPrepCard(),
                    ],
                  ),
                ),
              ],
            ],
            Padding(
              padding: Responsive.contentPadding(context).copyWith(bottom: 80),
              child: AzureGrid<ExamSchedule>(
                title: 'All Exam Schedules',
                items: _allExams,
                columns: columns,
                filters: filters,
                searchMatcher: searchMatcher,
                onRefresh: _loadExams,
                disableVerticalScroll: true,
                mobileCardBuilder: (context, exam) {
                  final nowTime = DateTime.now();
                  final isActive = nowTime.isAfter(exam.dateTime) &&
                      nowTime.isBefore(exam.endTime);
                  final isUpcoming = nowTime.isBefore(exam.dateTime);
                  final isPast = nowTime.isAfter(exam.endTime);
                  return _buildExamCard(exam,
                      isActive: isActive,
                      isUpcoming: isUpcoming,
                      isPast: isPast);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(0, Responsive.headerTopPadding(context), 16,
          Responsive.isWide(context) ? 8 : 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF134E4A), Color(0xFF0F766E)],
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            onPressed: () => safeGoBack(context, '/student/dashboard'),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Examinations',
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
            onPressed: _loadExams,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
          // AI Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🤖', style: TextStyle(fontSize: 10)),
                SizedBox(width: 4),
                Text(
                  'AI Prep',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextExamCountdownCard(ExamSchedule nextExam) {
    final diff = nextExam.dateTime.difference(DateTime.now());
    final days = diff.inDays;
    final hours = diff.inHours.remainder(24);
    final minutes = diff.inMinutes.remainder(60);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StudentColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF134E4A).withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'COUNTDOWN TO NEXT EXAM',
            style: TextStyle(
              fontSize: 10,
              color: StudentColors.text3,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_getSubjectIcon(nextExam.subject),
                  style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${nextExam.subject} — ${nextExam.title.isNotEmpty ? nextExam.title : 'Term Assessment'}',
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: StudentColors.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildCountdownBox(days.toString().padLeft(2, '0'), 'Days'),
              const SizedBox(width: 8),
              _buildCountdownBox(hours.toString().padLeft(2, '0'), 'Hours'),
              const SizedBox(width: 8),
              _buildCountdownBox(minutes.toString().padLeft(2, '0'), 'Mins'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownBox(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF134E4A), Color(0xFF0F766E)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              color: Colors.white.withValues(alpha: 0.6),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiPrepCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF134E4A), Color(0xFF0F766E)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🤖', style: TextStyle(fontSize: 14)),
              SizedBox(width: 6),
              Text(
                'AI Exam Prep Helper',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your upcoming exams are online proctored. Focus heavily on key topics, practice sample papers and use our secure portal for validation checks.',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.75),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => context.push('/student/ai-chat'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('💬', style: TextStyle(fontSize: 12)),
                  SizedBox(width: 6),
                  Text(
                    'Ask AI Study Assistant',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamCard(ExamSchedule exam,
      {bool isActive = false, bool isUpcoming = false, bool isPast = false}) {
    final date = exam.dateTime.toLocal();
    final isOnline = exam.examType.toLowerCase() == 'online';

    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final formattedTime = '$formattedHour:$minute $period';

    // Tag formatting colors
    final tagBg = isOnline ? const Color(0xFFEEF2FF) : const Color(0xFFF0FDF4);
    final tagText =
        isOnline ? const Color(0xFF4F46E5) : const Color(0xFF16A34A);
    final tagBorder =
        isOnline ? const Color(0xFFC7D2FE) : const Color(0xFFBBF7D0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? Colors.red.shade200 : Colors.grey.shade100,
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Date Box & Subject Info & Tags
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Calendar Date Box
              Container(
                width: 48,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isActive
                        ? [const Color(0xFFDC2626), const Color(0xFFEF4444)]
                        : [const Color(0xFF134E4A), const Color(0xFF0F766E)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      date.day.toString().padLeft(2, '0'),
                      style: const TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      _getMonthAbbreviation(date.month),
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Subject Name & Category
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(_getSubjectIcon(exam.subject),
                            style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            exam.subject,
                            style: const TextStyle(
                              fontFamily: AppFonts.heading,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      exam.title.isNotEmpty ? exam.title : 'Assessment',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Mode tag (Online/Offline)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tagBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tagBorder),
                ),
                child: Text(
                  isOnline ? '🖥️ Online' : '📝 Offline',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: tagText,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          // Row 2: Metadata values (Topic, Location, Duration, Marks)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (exam.syllabus != null && exam.syllabus!.isNotEmpty) ...[
                      _buildMetaText('📚 Topics', exam.syllabus!),
                      const SizedBox(height: 4),
                    ],
                    _buildMetaText(
                        '🕒 Time', '$formattedTime • ${exam.duration}'),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMetaText(
                        '📍 Venue', isOnline ? 'Online Portal' : exam.venue),
                    const SizedBox(height: 4),
                    _buildMetaText('🏆 Max Marks', '${exam.totalMarks} Marks'),
                  ],
                ),
              ),
            ],
          ),
          // Row 3: Action triggers based on status
          if (isActive) ...[
            const SizedBox(height: 12),
            if (isOnline)
              _buildJoinButton(exam)
            else
              _buildOfflineStatusBanner('Go to Venue: ${exam.venue}'),
          ] else if (isUpcoming) ...[
            const SizedBox(height: 12),
            _buildUpcomingStatus(exam),
          ] else if (isPast) ...[
            const SizedBox(height: 12),
            _buildCompletedStatus(exam),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaText(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w600),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF334155),
                fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildJoinButton(ExamSchedule exam) {
    final status = exam.submissionStatus;
    final isSubmitted = status == 'submitted' || status == 'graded';

    if (isSubmitted) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: Text(
            '✅ Submission Received',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        context.push('/student/exams/details/${exam.id}');
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE11D48), Color(0xFFBE123C)],
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            status == 'active'
                ? '⚡ RESUME ONLINE EXAM'
                : '✍️ JOIN ONLINE EXAM NOW',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineStatusBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: Colors.red, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.red.shade900,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingStatus(ExamSchedule exam) {
    final diff = exam.dateTime.difference(DateTime.now());
    final hours = diff.inHours;
    final mins = diff.inMinutes.remainder(60);

    String text = 'Exam Starts in ';
    if (hours > 24) {
      text += '${diff.inDays} days';
    } else {
      text += '${hours}h ${mins}m';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Text(
          '⏳ $text',
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedStatus(ExamSchedule exam) {
    final status = exam.submissionStatus;

    String statusText = 'Exam Completed';
    Color bg = const Color(0xFFF1F5F9);
    Color textCol = const Color(0xFF475569);
    bool canViewResult = false;

    if (status == 'graded' && exam.obtainedScore != null) {
      statusText = 'Graded: ${exam.obtainedScore}/${exam.totalMarks} Marks';
      bg = const Color(0xFFF0FDF4);
      textCol = const Color(0xFF15803D);
      canViewResult = true;
    } else if (status == 'submitted') {
      statusText = 'Submission Received • Pending Evaluation';
      bg = const Color(0xFFEFF6FF);
      textCol = const Color(0xFF1D4ED8);
    } else if (status == 'active' ||
        exam.hasSession ||
        exam.sessionStatus == 'completed') {
      statusText = 'Unsubmitted';
      bg = const Color(0xFFFFF7ED); // Light Orange
      textCol = const Color(0xFFC2410C); // Dark Orange
    } else if (exam.examType.toLowerCase() == 'online') {
      statusText = 'Absent';
      bg = const Color(0xFFFEF2F2);
      textCol = const Color(0xFF991B1B);
    }

    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (canViewResult) ...[
              Icon(Icons.analytics_outlined, size: 14, color: textCol),
              const SizedBox(width: 6),
            ],
            Text(
              canViewResult ? '$statusText - View Analysis' : statusText,
              style: TextStyle(
                color: textCol,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );

    if (canViewResult) {
      return GestureDetector(
        onTap: () => context.push('/student/exams/result/${exam.id}'),
        child: card,
      );
    }
    return card;
  }
}
