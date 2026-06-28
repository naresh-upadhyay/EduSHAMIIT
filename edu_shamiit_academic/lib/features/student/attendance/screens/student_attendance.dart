import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_academic/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_core/widgets/responsive_content.dart';
import 'package:edu_shamiit_core/utils/responsive.dart';
import 'package:edu_shamiit_core/constants/student_colors.dart';
import 'package:edu_shamiit_core/constants/app_fonts.dart';
import 'package:edu_shamiit_academic/core/providers/student_providers.dart';
import 'package:edu_shamiit_core/utils/l10n.dart';
import 'package:intl/intl.dart';

class StudentAttendance extends ConsumerStatefulWidget {
  const StudentAttendance({super.key});

  @override
  ConsumerState<StudentAttendance> createState() => _StudentAttendanceState();
}

class _StudentAttendanceState extends ConsumerState<StudentAttendance> {
  int _activeTab = 0; // 0 = Calendar, 1 = Subjects, 2 = Logs
  DateTime _currentMonth = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  // Log Search and Filter state
  String _searchQuery = '';
  String _statusFilter = 'All'; // All, Present, Absent, Late, Void

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(attendanceProvider.notifier).fetchAttendance();
    });
  }

  // Helper to get days in month
  int _daysInMonth(DateTime date) {
    var firstOfNextMonth = DateTime(date.year, date.month + 1, 1);
    var lastOfThisMonth = firstOfNextMonth.subtract(const Duration(days: 1));
    return lastOfThisMonth.day;
  }

  @override
  Widget build(BuildContext context) {
    final attendanceState = ref.watch(attendanceProvider);

    if (attendanceState.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: StudentColors.primary,
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (attendanceState.error != null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    size: 64, color: StudentColors.error),
                const SizedBox(height: 16),
                Text(
                  'Failed to load attendance'.tr(ref),
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  attendanceState.error!,
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    ref.read(attendanceProvider.notifier).fetchAttendance();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StudentColors.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: Text('Retry'.tr(ref),
                      style: const TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final records = attendanceState.records;
    final summary = attendanceState.summary;
    final subjectWise = attendanceState.subjectWise;
    final monthly = attendanceState.monthly;

    final overallPct = (summary['overall_pct'] as num? ?? 0.0).toDouble();
    final presentDays = summary['present_days'] as int? ?? 0;
    final absentDays = summary['absent_days'] as int? ?? 0;
    final lateDays = summary['late_days'] as int? ?? 0;
    final voidDays = summary['void_days'] as int? ?? 0;

    return Scaffold(
      backgroundColor:
          isDark ? StudentColors.darkBackground : StudentColors.background,
      body: Column(
        children: [
          // Header with Back Button
          Container(
            padding: EdgeInsets.fromLTRB(
                16, Responsive.headerTopPadding(context), 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [StudentColors.primary, StudentColors.primaryDeep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios,
                      color: Colors.white, size: 20),
                  onPressed: () => safeGoBack(context, '/student/dashboard'),
                ),
                const SizedBox(width: 4),
                Text(
                  'My Attendance'.tr(ref),
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: () {
                    ref.read(attendanceProvider.notifier).fetchAttendance();
                  },
                ),
              ],
            ),
          ),

          Expanded(
            child: ResponsiveContent(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: [
                  // Overall Statistics Card with Glow
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            StudentColors.primary,
                            StudentColors.primaryDeep,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: StudentColors.primary.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ATTENDANCE SCORE',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  overallPct >= 75
                                      ? 'Good Standing'
                                      : 'At Risk',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: AppFonts.heading,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  overallPct >= 75
                                      ? 'Great job! Your attendance is in the safe zone.'
                                      : 'Action needed! Maintain at least 75% attendance.',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Radial Gauge
                          SizedBox(
                            width: 90,
                            height: 90,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 80,
                                  height: 80,
                                  child: CircularProgressIndicator(
                                    value: overallPct / 100,
                                    strokeWidth: 8,
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.15),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                            Colors.white),
                                  ),
                                ),
                                Text(
                                  '${overallPct.toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: AppFonts.heading,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Mini Stats cards row (Present, Absent, Late, Void)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildPremiumStatCard(
                          icon: Icons.check_circle_outline,
                          count: '$presentDays',
                          label: 'Present'.tr(ref),
                          color: StudentColors.success,
                          bgColor: isDark
                              ? StudentColors.success.withValues(alpha: 0.1)
                              : StudentColors.successBg,
                          isDark: isDark,
                        ),
                        const SizedBox(width: 10),
                        _buildPremiumStatCard(
                          icon: Icons.highlight_off,
                          count: '$absentDays',
                          label: 'Absent'.tr(ref),
                          color: StudentColors.error,
                          bgColor: isDark
                              ? StudentColors.error.withValues(alpha: 0.1)
                              : StudentColors.errorBg,
                          isDark: isDark,
                        ),
                        const SizedBox(width: 10),
                        _buildPremiumStatCard(
                          icon: Icons.watch_later_outlined,
                          count: '$lateDays',
                          label: 'Late'.tr(ref),
                          color: StudentColors.warning,
                          bgColor: isDark
                              ? StudentColors.warning.withValues(alpha: 0.1)
                              : StudentColors.warningBg,
                          isDark: isDark,
                        ),
                        const SizedBox(width: 10),
                        _buildPremiumStatCard(
                          icon: Icons.block_flipped,
                          count: '$voidDays',
                          label: 'Void'.tr(ref),
                          color: Colors.grey,
                          bgColor: isDark
                              ? Colors.grey.withValues(alpha: 0.1)
                              : Colors.grey.shade100,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),

                  // Custom Segmented Control for Tabs
                  Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? StudentColors.darkSurface
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        _buildTabButton(
                            0, 'Calendar', Icons.calendar_month, isDark),
                        _buildTabButton(1, 'Subjects', Icons.menu_book, isDark),
                        _buildTabButton(
                            2, 'Logs & History', Icons.list_alt, isDark),
                      ],
                    ),
                  ),

                  // Tab Content Panel
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _activeTab == 0
                        ? _buildCalendarTab(records, isDark)
                        : _activeTab == 1
                            ? _buildSubjectsTab(subjectWise, monthly, isDark)
                            : _buildLogsTab(records, isDark),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon, bool isDark) {
    final isSelected = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeTab = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? StudentColors.primary : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected && !isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? (isDark ? Colors.white : StudentColors.primary)
                    : (isDark ? StudentColors.darkText3 : StudentColors.text2),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.white : StudentColors.primary)
                      : (isDark
                          ? StudentColors.darkText2
                          : StudentColors.text2),
                  fontFamily: AppFonts.heading,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumStatCard({
    required IconData icon,
    required String count,
    required String label,
    required Color color,
    required Color bgColor,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? StudentColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? StudentColors.darkBorder : StudentColors.border,
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 8),
            Text(
              count,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : StudentColors.text,
                fontFamily: AppFonts.heading,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isDark ? StudentColors.darkText3 : StudentColors.text3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // --- CALENDAR TAB ---
  Widget _buildCalendarTab(List<AttendanceRecord> records, bool isDark) {
    final startWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1)
        .weekday; // 1=Mon, 7=Sun
    final startOffset = startWeekday % 7; // Sunday=0, Mon=1...
    final daysNum = _daysInMonth(_currentMonth);
    final totalCells = startOffset + daysNum;

    // Filter selected day records
    final selectedDayRecords = records
        .where((r) =>
            r.date.year == _selectedDay.year &&
            r.date.month == _selectedDay.month &&
            r.date.day == _selectedDay.day)
        .toList();

    return Column(
      key: const ValueKey('CalendarTab'),
      children: [
        // Month Selector Card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? StudentColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? StudentColors.darkBorder : StudentColors.border,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.chevron_left,
                          color: isDark ? Colors.white : StudentColors.text),
                      onPressed: () {
                        setState(() {
                          _currentMonth = DateTime(
                              _currentMonth.year, _currentMonth.month - 1, 1);
                        });
                      },
                    ),
                    Text(
                      DateFormat('MMMM yyyy').format(_currentMonth),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : StudentColors.text,
                        fontFamily: AppFonts.heading,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.chevron_right,
                          color: isDark ? Colors.white : StudentColors.text),
                      onPressed: () {
                        setState(() {
                          _currentMonth = DateTime(
                              _currentMonth.year, _currentMonth.month + 1, 1);
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Weekdays Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                      .map((d) {
                    return Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? StudentColors.darkText3
                                : StudentColors.text3,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),

                // Days Grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 1.0,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: totalCells,
                  itemBuilder: (context, index) {
                    if (index < startOffset) {
                      return const SizedBox.shrink();
                    }

                    final day = index - startOffset + 1;
                    final cellDate =
                        DateTime(_currentMonth.year, _currentMonth.month, day);
                    final isToday = DateTime.now().year == cellDate.year &&
                        DateTime.now().month == cellDate.month &&
                        DateTime.now().day == cellDate.day;
                    final isSelected = _selectedDay.year == cellDate.year &&
                        _selectedDay.month == cellDate.month &&
                        _selectedDay.day == cellDate.day;

                    final dayRecords = records
                        .where((r) =>
                            r.date.year == cellDate.year &&
                            r.date.month == cellDate.month &&
                            r.date.day == cellDate.day)
                        .toList();

                    return _buildCalendarDayCell(
                        day, cellDate, isToday, isSelected, dayRecords, isDark);
                  },
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Day Details
        _buildDayDetailsCard(selectedDayRecords, isDark),
      ],
    );
  }

  Widget _buildCalendarDayCell(
    int day,
    DateTime date,
    bool isToday,
    bool isSelected,
    List<AttendanceRecord> dayRecords,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDay = date;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? StudentColors.primary.withValues(alpha: 0.15)
              : (isToday ? StudentColors.primaryLight : Colors.transparent),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? StudentColors.primary
                : (isToday
                    ? StudentColors.primary.withValues(alpha: 0.3)
                    : Colors.transparent),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                    isToday || isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? StudentColors.primary
                    : (isDark ? Colors.white : StudentColors.text),
              ),
            ),
            const SizedBox(height: 4),
            // Status dots
            if (dayRecords.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: dayRecords.take(4).map((r) {
                  Color dotColor;
                  switch (r.status) {
                    case 'present':
                      dotColor = StudentColors.success;
                      break;
                    case 'absent':
                      dotColor = StudentColors.error;
                      break;
                    case 'late':
                      dotColor = StudentColors.warning;
                      break;
                    case 'void':
                      dotColor = Colors.grey;
                      break;
                    default:
                      dotColor = Colors.grey;
                  }
                  return Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1.0),
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  );
                }).toList(),
              )
            else
              const SizedBox(height: 5),
          ],
        ),
      ),
    );
  }

  Widget _buildDayDetailsCard(List<AttendanceRecord> dayRecords, bool isDark) {
    final formattedDate = DateFormat('EEEE, MMM d, yyyy').format(_selectedDay);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? StudentColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? StudentColors.darkBorder : StudentColors.border,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_note,
                  color: StudentColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                formattedDate,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : StudentColors.text,
                  fontFamily: AppFonts.heading,
                ),
              ),
            ],
          ),
          const Divider(height: 24, thickness: 1),
          if (dayRecords.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                        size: 40),
                    const SizedBox(height: 8),
                    Text(
                      'No attendance marked for this day.',
                      style: TextStyle(
                        color: isDark
                            ? StudentColors.darkText3
                            : StudentColors.text3,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: dayRecords.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final rec = dayRecords[index];
                return _buildDetailedRecordItem(rec, isDark);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDetailedRecordItem(AttendanceRecord rec, bool isDark) {
    Color statusColor;
    Color statusBg;
    String statusText;
    IconData statusIcon;

    switch (rec.status) {
      case 'present':
        statusColor = StudentColors.success;
        statusBg = isDark
            ? StudentColors.success.withValues(alpha: 0.1)
            : StudentColors.successBg;
        statusText = 'Present';
        statusIcon = Icons.check_circle;
        break;
      case 'absent':
        statusColor = StudentColors.error;
        statusBg = isDark
            ? StudentColors.error.withValues(alpha: 0.1)
            : StudentColors.errorBg;
        statusText = 'Absent';
        statusIcon = Icons.cancel;
        break;
      case 'late':
        statusColor = StudentColors.warning;
        statusBg = isDark
            ? StudentColors.warning.withValues(alpha: 0.1)
            : StudentColors.warningBg;
        statusText = 'Late';
        statusIcon = Icons.watch_later;
        break;
      case 'void':
        statusColor = Colors.grey;
        statusBg =
            isDark ? Colors.grey.withValues(alpha: 0.1) : Colors.grey.shade100;
        statusText = 'Void';
        statusIcon = Icons.block;
        break;
      default:
        statusColor = Colors.grey;
        statusBg =
            isDark ? Colors.grey.withValues(alpha: 0.1) : Colors.grey.shade100;
        statusText = 'Unknown';
        statusIcon = Icons.help_outline;
    }

    final hasRemarks = rec.remarks != null && rec.remarks!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? StudentColors.darkBackground : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? StudentColors.darkBorder : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: StudentColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getSubjectIcon(rec.subjectName),
              color: StudentColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rec.subjectName ?? 'Entire Day',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : StudentColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Marked by: ${rec.markedByName ?? "Teacher"} • ${DateFormat('MMM d, yyyy').format(rec.date)}',
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        isDark ? StudentColors.darkText3 : StudentColors.text3,
                  ),
                ),
                if (hasRemarks) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 10,
                            color: isDark ? Colors.white60 : Colors.blueGrey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            rec.remarks!,
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.blueGrey,
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, color: statusColor, size: 12),
                const SizedBox(width: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getSubjectIcon(String? subjectName) {
    if (subjectName == null) return Icons.school;
    final name = subjectName.toLowerCase();
    if (name.contains('math')) return Icons.calculate;
    if (name.contains('sci') ||
        name.contains('phys') ||
        name.contains('chem') ||
        name.contains('bio')) {
      return Icons.science;
    }
    if (name.contains('eng') || name.contains('lit')) return Icons.menu_book;
    if (name.contains('hist') ||
        name.contains('geo') ||
        name.contains('social')) {
      return Icons.public;
    }
    if (name.contains('art') || name.contains('draw')) return Icons.palette;
    if (name.contains('music')) return Icons.music_note;
    if (name.contains('sport') || name.contains('pe') || name.contains('gym')) {
      return Icons.sports_soccer;
    }
    return Icons.school;
  }

  // --- SUBJECTS TAB ---
  Widget _buildSubjectsTab(
    List<Map<String, dynamic>> subjectWise,
    List<Map<String, dynamic>> monthly,
    bool isDark,
  ) {
    return Column(
      key: const ValueKey('SubjectsTab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (subjectWise.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.menu_book,
                      size: 48,
                      color: isDark ? Colors.white24 : Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text(
                    'No subject-wise records available.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: subjectWise.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final subject = subjectWise[index];
              final name = subject['subject'] ?? 'Unknown';
              final present = subject['present'] ?? 0;
              final total = subject['total'] ?? 0;
              final pct = (subject['pct'] as num?)?.toDouble() ?? 0.0;

              Color progressColor;
              if (pct >= 85) {
                progressColor = StudentColors.success;
              } else if (pct >= 75) {
                progressColor = StudentColors.warning;
              } else {
                progressColor = StudentColors.error;
              }

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? StudentColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? StudentColors.darkBorder
                        : StudentColors.border,
                  ),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: progressColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _getSubjectIcon(name),
                            color: progressColor,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white
                                      : StudentColors.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Present in $present of $total lectures',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? StudentColors.darkText3
                                      : StudentColors.text3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${pct.toStringAsFixed(1)}%',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: progressColor,
                                  fontFamily: AppFonts.heading),
                            ),
                            if (pct < 75)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: StudentColors.error
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'At Risk',
                                  style: TextStyle(
                                    color: StudentColors.error,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: total > 0 ? (present / total) : 0.0,
                        backgroundColor: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(progressColor),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: 24),
        _buildMonthlyTrendSection(monthly, isDark),
      ],
    );
  }

  Widget _buildMonthlyTrendSection(
      List<Map<String, dynamic>> monthly, bool isDark) {
    if (monthly.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Monthly Analysis'.tr(ref),
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : StudentColors.text,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: monthly.length,
            itemBuilder: (context, index) {
              final m = monthly[index];
              final name = m['month'] ?? 'Unknown';
              final pct = (m['pct'] as num?)?.toDouble() ?? 0.0;

              Color pctColor;
              if (pct >= 85) {
                pctColor = StudentColors.success;
              } else if (pct >= 75) {
                pctColor = StudentColors.warning;
              } else {
                pctColor = StudentColors.error;
              }

              return Container(
                width: 140,
                margin: const EdgeInsets.only(right: 12, bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? StudentColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? StudentColors.darkBorder
                        : StudentColors.border,
                  ),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.01),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? StudentColors.darkText2
                            : StudentColors.text2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${pct.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: pctColor,
                        fontFamily: AppFonts.heading,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- LOGS TAB ---
  Widget _buildLogsTab(List<AttendanceRecord> records, bool isDark) {
    final filtered = records.where((r) {
      final matchesSearch = (r.subjectName ?? 'Entire Day')
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          (r.markedByName ?? '')
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());
      final matchesStatus =
          _statusFilter == 'All' || r.status == _statusFilter.toLowerCase();
      return matchesSearch && matchesStatus;
    }).toList();

    return Column(
      key: const ValueKey('LogsTab'),
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search by subject or teacher...',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: isDark ? StudentColors.darkSurface : Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color:
                      isDark ? StudentColors.darkBorder : StudentColors.border,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color:
                      isDark ? StudentColors.darkBorder : StudentColors.border,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: StudentColors.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),

        // Status Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children:
                ['All', 'Present', 'Absent', 'Late', 'Void'].map((status) {
              final isSelected = _statusFilter == status;
              Color chipColor;
              switch (status) {
                case 'Present':
                  chipColor = StudentColors.success;
                  break;
                case 'Absent':
                  chipColor = StudentColors.error;
                  break;
                case 'Late':
                  chipColor = StudentColors.warning;
                  break;
                case 'Void':
                  chipColor = Colors.grey;
                  break;
                default:
                  chipColor = StudentColors.primary;
              }

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white60 : Colors.black87),
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _statusFilter = status;
                      });
                    }
                  },
                  selectedColor: chipColor,
                  backgroundColor: isDark
                      ? StudentColors.darkSurface
                      : const Color(0xFFF1F5F9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isSelected
                          ? Colors.transparent
                          : (isDark
                              ? StudentColors.darkBorder
                              : const Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 12),

        // Log List
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.history_toggle_off,
                      size: 48,
                      color: isDark ? Colors.white24 : Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'No matching records found.',
                    style: TextStyle(
                      color: isDark
                          ? StudentColors.darkText3
                          : StudentColors.text3,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filtered.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final rec = filtered[index];
              return _buildDetailedRecordItem(rec, isDark);
            },
          ),
      ],
    );
  }
}
