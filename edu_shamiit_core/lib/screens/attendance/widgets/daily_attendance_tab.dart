import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../constants/app_fonts.dart';
import '../../../../utils/responsive.dart';
import '../models/attendance_models.dart';
import '../../classes/models/class_models.dart';
import '../providers/attendance_provider.dart';
import 'dialogs/attendance_override_dialog.dart';
import 'dialogs/attendance_confirmation_dialog.dart';
import 'drawers/student_attendance_drawer.dart';

class DailyAttendanceTab extends ConsumerStatefulWidget {
  final Function(AttendanceStudentRowModel student)? onSelectStudent;

  const DailyAttendanceTab({Key? key, this.onSelectStudent}) : super(key: key);

  @override
  ConsumerState<DailyAttendanceTab> createState() => _DailyAttendanceTabState();
}

class _DailyAttendanceTabState extends ConsumerState<DailyAttendanceTab> {
  final TextEditingController _searchController = TextEditingController();
  AttendanceStudentRowModel? _selectedDrawerStudent;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceProvider);
    final notifier = ref.read(attendanceProvider.notifier);
    final isDesktop = Responsive.isDesktop(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ═════════════════════════════════════════════════════════════════════
        // MAIN ATTENDANCE WORKSPACE (Left / Center)
        // ═════════════════════════════════════════════════════════════════════
        Expanded(
          flex: 7,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top Controls & Filters Bar (Date, Class, Section, Mode, Load, Reset)
                _buildTopFilterBar(state, notifier, isDark, theme),
                const SizedBox(height: 16),

                // 2. Mode Notification Banner / Period Selector Bar
                if (state.selectedMode == AttendanceMode.allDay)
                  _buildAllDayLockBanner(state, isDark)
                else if (state.selectedMode == AttendanceMode.byPeriod)
                  _buildSinglePeriodSelectionBar(state, notifier, isDark, theme)
                else if (state.selectedMode == AttendanceMode.customSelection)
                  _buildMultiPeriodSelectionBar(state, notifier, isDark, theme),
                const SizedBox(height: 16),

                // 3. Class Header & Stats Summary Row
                _buildClassHeaderAndStats(state, notifier, isDark, theme),
                const SizedBox(height: 14),

                // 4. Student Search Bar & Action Buttons Toolbar
                _buildSearchBarAndActionsToolbar(state, notifier, isDark, theme),
                const SizedBox(height: 14),

                // Floating Bulk Action Bar (when students are selected)
                if (state.selectedStudentIds.isNotEmpty) ...[
                  _buildFloatingBulkActionBar(state, notifier, isDark, theme),
                  const SizedBox(height: 14),
                ],

                // 5. Student Attendance Roster Table
                _buildStudentRosterTable(state, notifier, isDark, theme),
                const SizedBox(height: 14),

                // 6. Quick Status Legend Row
                _buildStatusLegendRow(isDark),
                const SizedBox(height: 16),

                // 7. Bottom Pagination & Sticky Save Bar
                _buildBottomSaveAndPaginationBar(state, notifier, isDark, theme),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),

        // ═════════════════════════════════════════════════════════════════════
        // RIGHT SIDEBAR (Desktop: Day Summary, Today's Schedule, Quick Actions)
        // ═════════════════════════════════════════════════════════════════════
        if (isDesktop && _selectedDrawerStudent == null)
          Container(
            width: 330,
            padding: const EdgeInsets.only(top: 18, right: 24, left: 12, bottom: 24),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDaySummaryCard(state, isDark, theme),
                  const SizedBox(height: 18),
                  _buildTodaysScheduleCard(state, notifier, isDark, theme),
                  const SizedBox(height: 18),
                  _buildQuickActionsCard(state, notifier, isDark, theme),
                ],
              ),
            ),
          ),

        // Student Detail Side Drawer (if student row clicked)
        if (_selectedDrawerStudent != null)
          Builder(
            builder: (context) {
              final activeStudent = state.roster.firstWhere(
                (s) => s.studentId == _selectedDrawerStudent!.studentId,
                orElse: () => _selectedDrawerStudent!,
              );
              return StudentAttendanceDrawer(
                student: activeStudent,
                dateStr: state.displayDateString,
                schedules: state.schedulesToday,
                onClose: () => setState(() => _selectedDrawerStudent = null),
              );
            },
          ),
      ],
    );
  }

  // ==========================================================================
  // 1. FILTER BAR (Responsive for all screen widths)
  // ==========================================================================
  Widget _buildTopFilterBar(
    AttendanceState state,
    AttendanceNotifier notifier,
    bool isDark,
    ThemeData theme,
  ) {
    final dateStr = DateFormat('dd MMM yyyy, EEE').format(state.selectedDate);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 900;

          // 1. Date Field
          final dateField = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Date',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: state.selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) notifier.setDate(picked);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF4F46E5)),
                    ],
                  ),
                ),
              ),
            ],
          );

          // 2. Class Dropdown
          final uniqueClasses = <String, AcademicClassModel>{};
          for (final c in state.availableClasses) {
            if (c.id.isNotEmpty && !uniqueClasses.containsKey(c.id)) {
              uniqueClasses[c.id] = c;
            }
          }
          final classList = uniqueClasses.values.toList();
          final effectiveClassId = classList.any((c) => c.id == state.selectedClassId)
              ? state.selectedClassId
              : (classList.isNotEmpty ? classList.first.id : null);

          final classField = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Class',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: effectiveClassId,
                    isExpanded: true,
                    icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    hint: Text('Select Class', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                    items: classList.map((c) {
                      return DropdownMenuItem<String>(
                        value: c.id,
                        child: Text(c.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) notifier.setClass(val);
                    },
                  ),
                ),
              ),
            ],
          );

          // 3. Section Dropdown
          final currentClass = classList.firstWhere(
            (c) => c.id == effectiveClassId,
            orElse: () => classList.isNotEmpty ? classList.first : AcademicClassModel(id: '', name: 'Class 10', code: 'C10', stage: 'Secondary'),
          );
          final uniqueSections = <String, AcademicSectionModel>{};
          for (final s in currentClass.sections) {
            if (s.id.isNotEmpty && !uniqueSections.containsKey(s.id)) {
              uniqueSections[s.id] = s;
            }
          }
          final sectionList = uniqueSections.values.toList();
          final effectiveSectionId = sectionList.any((s) => s.id == state.selectedSectionId)
              ? state.selectedSectionId
              : null;

          final sectionField = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Section',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: effectiveSectionId,
                    isExpanded: true,
                    icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    hint: Text('All Sections', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All Sections', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                      ...sectionList.map((s) {
                        return DropdownMenuItem<String?>(
                          value: s.id,
                          child: Text(s.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                        );
                      }),
                    ],
                    onChanged: (val) => notifier.setSection(val),
                  ),
                ),
              ),
            ],
          );

          // 4. Mode Dropdown
          final modeField = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Mode',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 6),
              PopupMenuButton<AttendanceMode>(
                tooltip: 'Select Attendance Mode',
                onSelected: (mode) => notifier.setMode(mode),
                offset: const Offset(0, 42),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: AttendanceMode.allDay,
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF4F46E5)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('By Schedule (All Day)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                              Text('Mark for all periods of the day', style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        if (state.selectedMode == AttendanceMode.allDay)
                          const Icon(Icons.check_rounded, size: 16, color: Color(0xFF4F46E5)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: AttendanceMode.byPeriod,
                    child: Row(
                      children: [
                        const Icon(Icons.schedule_rounded, size: 16, color: Color(0xFF3B82F6)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('By Period', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                              Text('Mark attendance for a specific period', style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        if (state.selectedMode == AttendanceMode.byPeriod)
                          const Icon(Icons.check_rounded, size: 16, color: Color(0xFF4F46E5)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: AttendanceMode.customSelection,
                    child: Row(
                      children: [
                        const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF8B5CF6)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Custom Selection', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                              Text('Select multiple periods', style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        if (state.selectedMode == AttendanceMode.customSelection)
                          const Icon(Icons.check_rounded, size: 16, color: Color(0xFF4F46E5)),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          state.selectedMode.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ],
                  ),
                ),
              ),
            ],
          );

          // 5. Action Buttons
          final actionButtons = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 38,
                child: ElevatedButton(
                  onPressed: () => notifier.refreshAll(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: const Text('Load', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 38,
                child: OutlinedButton(
                  onPressed: () => notifier.resetDrafts(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                    side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Reset', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: dateField),
                    const SizedBox(width: 10),
                    Expanded(child: classField),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: sectionField),
                    const SizedBox(width: 10),
                    Expanded(child: modeField),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: actionButtons,
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(flex: 3, child: dateField),
              const SizedBox(width: 12),
              Expanded(flex: 3, child: classField),
              const SizedBox(width: 12),
              Expanded(flex: 3, child: sectionField),
              const SizedBox(width: 12),
              Expanded(flex: 4, child: modeField),
              const SizedBox(width: 12),
              actionButtons,
            ],
          );
        },
      ),
    );
  }

  // ==========================================================================
  // 2. ALL-DAY LOCK BANNER (Matching Image 1)
  // ==========================================================================
  Widget _buildAllDayLockBanner(AttendanceState state, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B4B).withValues(alpha: 0.4) : const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF3730A3) : const Color(0xFFC7D2FE)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.info_outline_rounded, color: Color(0xFF4F46E5), size: 18),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'All Day Mode Selected',
                  style: TextStyle(color: Color(0xFF312E81), fontWeight: FontWeight.w700, fontSize: 12.5),
                ),
                SizedBox(height: 1),
                Text(
                  'Attendance marked in this mode will be applied to all periods for the selected date. Once saved, it will be locked for all periods.',
                  style: TextStyle(color: Color(0xFF4338CA), fontSize: 11.5),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFC7D2FE)),
            ),
            child: const Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFF4F46E5)),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 2A. SINGLE PERIOD SELECTION BAR (For 'By Period' Mode)
  // ==========================================================================
  Widget _buildSinglePeriodSelectionBar(
    AttendanceState state,
    AttendanceNotifier notifier,
    bool isDark,
    ThemeData theme,
  ) {
    final schedules = state.schedulesToday;

    if (schedules.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Color(0xFF3B82F6), size: 18),
            const SizedBox(width: 10),
            Text(
              'No Academic Calendar schedule found for this class on selected date.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 16, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 8),
                  Text(
                    'Select Academic Period / Subject',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Text(
                '${schedules.length} Periods Available Today',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: schedules.map((sched) {
                final isSelected = sched.periodNumber == state.selectedPeriodNumber;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: InkWell(
                    onTap: () {
                      notifier.setPeriod(
                        sched.periodNumber,
                        sched.subjectId,
                        scheduleId: sched.scheduleId ?? sched.id,
                      );
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark ? const Color(0xFF312E81).withValues(alpha: 0.5) : const Color(0xFFEEF2FF))
                            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF4F46E5)
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          width: isSelected ? 1.8 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF4F46E5)
                                  : sched.subjectColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              sched.periodLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isSelected ? Colors.white : sched.subjectColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    sched.subjectName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                                      color: isSelected
                                          ? (isDark ? Colors.white : const Color(0xFF312E81))
                                          : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                    ),
                                  ),
                                  if (state.selectedSectionId == null && sched.sectionName != null && sched.sectionName!.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFF4F46E5).withValues(alpha: 0.2)
                                            : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Sec ${sched.sectionName}',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected
                                              ? (isDark ? Colors.white : const Color(0xFF312E81))
                                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (sched.isCompleted) ...[
                                    const SizedBox(width: 6),
                                    const Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF10B981)),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    sched.timeRange,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '• ${sched.teacherName}',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.radio_button_checked_rounded, size: 16, color: Color(0xFF4F46E5)),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 2B. MULTI-PERIOD SELECTION BAR (For 'Custom Selection' Mode)
  // ==========================================================================
  Widget _buildMultiPeriodSelectionBar(
    AttendanceState state,
    AttendanceNotifier notifier,
    bool isDark,
    ThemeData theme,
  ) {
    final schedules = state.schedulesToday;
    final selectedCount = schedules.where((s) => state.selectedScheduleIds.contains(s.id) || (s.scheduleId != null && state.selectedScheduleIds.contains(s.scheduleId))).length;
    final allSelected = schedules.isNotEmpty && selectedCount == schedules.length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 8),
                  Text(
                    'Custom Selection: Choose Target Periods',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$selectedCount of ${schedules.length} Selected',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF7C3AED)),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => notifier.selectAllSchedules(!allSelected),
                    icon: Icon(allSelected ? Icons.deselect_rounded : Icons.select_all_rounded, size: 14),
                    label: Text(allSelected ? 'Deselect All' : 'Select All', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF7C3AED),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (schedules.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No Academic Calendar schedule found for this class on selected date.',
                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: schedules.map((sched) {
                  final isChecked = state.selectedScheduleIds.contains(sched.id) ||
                      (sched.scheduleId != null && state.selectedScheduleIds.contains(sched.scheduleId));

                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: InkWell(
                      onTap: () => notifier.toggleScheduleSelection(sched.id),
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isChecked
                              ? (isDark ? const Color(0xFF581C87).withValues(alpha: 0.3) : const Color(0xFFFAF5FF))
                              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isChecked
                                ? const Color(0xFF8B5CF6)
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            width: isChecked ? 1.6 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: isChecked,
                              onChanged: (_) => notifier.toggleScheduleSelection(sched.id),
                              activeColor: const Color(0xFF8B5CF6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: sched.subjectColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                sched.periodLabel,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: sched.subjectColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      sched.subjectName,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: isChecked ? FontWeight.w800 : FontWeight.w700,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    if (state.selectedSectionId == null && sched.sectionName != null && sched.sectionName!.isNotEmpty) ...[
                                      const SizedBox(width: 5),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: Text(
                                          'Sec ${sched.sectionName}',
                                          style: TextStyle(
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  '${sched.timeRange} • ${sched.teacherName}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1B4B).withValues(alpha: 0.3) : const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF8B5CF6)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    selectedCount > 0
                        ? 'Attendance saved below will be simultaneously applied across all $selectedCount selected periods.'
                        : 'Please select at least 1 period above to mark attendance.',
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF6D28D9), fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 3. CLASS HEADER & CONTEXT STATS ROW (Adaptive Wrap)
  // ==========================================================================
  Widget _buildClassHeaderAndStats(
    AttendanceState state,
    AttendanceNotifier notifier,
    bool isDark,
    ThemeData theme,
  ) {
    final selectedClass = state.availableClasses.firstWhere(
      (c) => c.id == state.selectedClassId,
      orElse: () => state.availableClasses.isNotEmpty
          ? state.availableClasses.first
          : AcademicClassModel(id: '', name: 'Class', code: '', stage: ''),
    );
    final className = selectedClass.name.isNotEmpty ? selectedClass.name : 'Class';
    String sectionName = '';
    if (state.selectedSectionId != null && selectedClass.sections.isNotEmpty) {
      final foundSection = selectedClass.sections.where((s) => s.id == state.selectedSectionId);
      if (foundSection.isNotEmpty) {
        sectionName = foundSection.first.name;
      }
    }
    final classDisplayTitle = state.selectedSectionId == null
        ? '$className - All Sections'
        : (sectionName.isNotEmpty ? '$className - $sectionName' : className);

    final total = state.totalCount > 0 ? state.totalCount : state.roster.length;
    final present = state.roster.where((s) => (state.draftStatuses[s.studentId] ?? s.status) == AttendanceStatus.present).length;
    final absent = state.roster.where((s) => (state.draftStatuses[s.studentId] ?? s.status) == AttendanceStatus.absent).length;
    final lateCount = state.roster.where((s) => (state.draftStatuses[s.studentId] ?? s.status) == AttendanceStatus.late).length;
    final onLeave = state.roster.where((s) => (state.draftStatuses[s.studentId] ?? s.status) == AttendanceStatus.onLeave).length;
    final halfDay = state.roster.where((s) => (state.draftStatuses[s.studentId] ?? s.status) == AttendanceStatus.halfDay).length;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        Text(
          classDisplayTitle,
          style: TextStyle(
            fontFamily: AppFonts.heading,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(width: 6),

        // Total Students Pill
        _buildStatPill('Total Students: $total', const Color(0xFF64748B), isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),

        // Present Pill
        _buildStatPill('Present: $present', const Color(0xFF15803D), const Color(0xFFECFDF5)),

        // Absent Pill
        _buildStatPill('Absent: $absent', const Color(0xFFB91C1C), const Color(0xFFFEF2F2)),

        // Late Pill
        _buildStatPill('Late: $lateCount', const Color(0xFFB45309), const Color(0xFFFFFBEB)),

        // On Leave Pill
        _buildStatPill('On Leave: $onLeave', const Color(0xFF1D4ED8), const Color(0xFFEFF6FF)),

        if (halfDay > 0)
          _buildStatPill('Half Day: $halfDay', const Color(0xFF6B21A8), const Color(0xFFFAF5FF)),
      ],
    );
  }

  Widget _buildStatPill(String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 11.5,
        ),
      ),
    );
  }

  // ==========================================================================
  // 4. STUDENT SEARCH BAR & ACTION BUTTONS TOOLBAR (Responsive)
  // ==========================================================================
  Widget _buildSearchBarAndActionsToolbar(
    AttendanceState state,
    AttendanceNotifier notifier,
    bool isDark,
    ThemeData theme,
  ) {
    final searchWidget = SizedBox(
      height: 38,
      child: TextField(
        controller: _searchController,
        onChanged: (val) => notifier.setSearch(val),
        style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white : const Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: 'Search by student name, roll no, admission no...',
          hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
          prefixIcon: Icon(Icons.search_rounded, size: 17, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 15),
                  onPressed: () {
                    _searchController.clear();
                    notifier.setSearch('');
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          filled: true,
          fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
          ),
        ),
      ),
    );

    final selectedCount = state.selectedStudentIds.length;
    final bool hasSelection = selectedCount > 0;

    // Scope label & color
    String modeScopeLabel;
    Color modeScopeColor;
    IconData modeScopeIcon;

    if (state.selectedMode == AttendanceMode.allDay) {
      modeScopeLabel = 'Whole Day (All Periods)';
      modeScopeColor = const Color(0xFF3B82F6);
      modeScopeIcon = Icons.wb_sunny_rounded;
    } else if (state.selectedMode == AttendanceMode.byPeriod) {
      final activePNum = state.selectedPeriodNumber ?? 1;
      final matchingSched = state.schedulesToday.firstWhere(
        (s) => s.periodNumber == activePNum,
        orElse: () => AttendanceScheduleItemModel(
          id: '',
          periodNumber: activePNum,
          periodLabel: 'P$activePNum',
          timeRange: '',
          subjectId: '',
          subjectName: 'Period $activePNum',
          subjectCode: '',
          subjectColor: const Color(0xFFF59E0B),
          teacherName: '',
          status: '',
        ),
      );
      modeScopeLabel = 'Period $activePNum (${matchingSched.subjectName})';
      modeScopeColor = const Color(0xFFF59E0B);
      modeScopeIcon = Icons.timelapse_rounded;
    } else {
      final customCount = state.selectedScheduleIds.length;
      modeScopeLabel = 'Custom ($customCount Periods)';
      modeScopeColor = const Color(0xFF8B5CF6);
      modeScopeIcon = Icons.tune_rounded;
    }

    final actionButtons = Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Scope Indicator Badge
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: modeScopeColor.withValues(alpha: isDark ? 0.18 : 0.09),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: modeScopeColor.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(modeScopeIcon, size: 14, color: modeScopeColor),
              const SizedBox(width: 6),
              Text(
                'Scope: $modeScopeLabel',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: modeScopeColor,
                ),
              ),
            ],
          ),
        ),

        // Quick Mark: Mark Present (Selected / All)
        ElevatedButton.icon(
          onPressed: () => _handleBulkMarkAttendance(context, state, notifier, AttendanceStatus.present, hasSelection),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          icon: Icon(hasSelection ? Icons.check_circle_outline_rounded : Icons.done_all_rounded, size: 15),
          label: Text(
            hasSelection ? 'Mark Selected Present ($selectedCount)' : 'Mark All Present',
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
        ),

        // Quick Mark: Mark Absent (Selected / All)
        ElevatedButton.icon(
          onPressed: () => _handleBulkMarkAttendance(context, state, notifier, AttendanceStatus.absent, hasSelection),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          icon: const Icon(Icons.cancel_outlined, size: 15),
          label: Text(
            hasSelection ? 'Mark Selected Absent ($selectedCount)' : 'Mark All Absent',
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
        ),

        // Quick Mark: Mark Late (Selected / All)
        OutlinedButton.icon(
          onPressed: () => _handleBulkMarkAttendance(context, state, notifier, AttendanceStatus.late, hasSelection),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFD97706),
            backgroundColor: const Color(0xFFFFFBEB),
            side: const BorderSide(color: Color(0xFFFDE68A)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: const Icon(Icons.watch_later_outlined, size: 15),
          label: Text(
            hasSelection ? 'Mark Selected Late ($selectedCount)' : 'Mark All Late',
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
        ),

        // More Actions Dropdown
        PopupMenuButton<String>(
          tooltip: 'More Bulk Actions',
          onSelected: (val) {
            if (val == 'leave') _handleBulkMarkAttendance(context, state, notifier, AttendanceStatus.onLeave, hasSelection);
            if (val == 'half') _handleBulkMarkAttendance(context, state, notifier, AttendanceStatus.halfDay, hasSelection);
            if (val == 'remark') _showBulkRemarksDialog(state, notifier, hasSelection);
            if (val == 'deselect') notifier.selectAllStudents(false);
            if (val == 'reset') notifier.resetDrafts();
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'leave',
              child: Row(
                children: [
                  const Icon(Icons.event_busy_rounded, size: 16, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 8),
                  Text(
                    hasSelection ? 'Mark Selected On Leave ($selectedCount)' : 'Mark All On Leave',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'half',
              child: Row(
                children: [
                  const Icon(Icons.pie_chart_rounded, size: 16, color: Color(0xFF6366F1)),
                  const SizedBox(width: 8),
                  Text(
                    hasSelection ? 'Mark Selected Half Day ($selectedCount)' : 'Mark All Half Day',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'remark',
              child: Row(
                children: [
                  const Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFF0284C7)),
                  const SizedBox(width: 8),
                  Text(
                    hasSelection ? 'Add Remark to Selected ($selectedCount)' : 'Add Remark to All',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            if (hasSelection) ...[
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'deselect',
                child: Row(
                  children: [
                    const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Text('Deselect All ($selectedCount)', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'reset',
              child: Row(
                children: [
                  Icon(Icons.restore_rounded, size: 16, color: Color(0xFF94A3B8)),
                  SizedBox(width: 8),
                  Text('Reset Drafts to Saved Status', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'More Actions',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ],
            ),
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1100) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              searchWidget,
              const SizedBox(height: 10),
              actionButtons,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: searchWidget),
            const SizedBox(width: 14),
            actionButtons,
          ],
        );
      },
    );
  }

  void _showBulkRemarksDialog(AttendanceState state, AttendanceNotifier notifier, bool hasSelection) {
    final count = hasSelection ? state.selectedStudentIds.length : state.roster.length;
    final textController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.edit_note_rounded, color: Color(0xFF4F46E5), size: 22),
            const SizedBox(width: 8),
            Text(
              'Add Remarks for $count ${count == 1 ? "Student" : "Students"}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This remark will be applied to ${hasSelection ? "the $count selected students" : "all $count students in this roster"}.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                maxLines: 3,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'e.g. Participated in sports event / Medical excuse / Late due to rain...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = textController.text.trim();
              if (val.isNotEmpty) {
                notifier.applyBulkRemarks(val);
              }
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Apply Remarks'),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 5. STUDENT ATTENDANCE ROSTER TABLE (Scrollable & Responsive)
  // ==========================================================================
  Widget _buildStudentRosterTable(
    AttendanceState state,
    AttendanceNotifier notifier,
    bool isDark,
    ThemeData theme,
  ) {
    if (state.isLoading) {
      return Container(
        height: 260,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        ),
        child: const CircularProgressIndicator(color: Color(0xFF4F46E5)),
      );
    }

    final roster = state.roster;
    if (roster.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            const Icon(Icons.people_outline_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              'No students found for the selected class/section',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      );
    }

    final isAllSelected = roster.isNotEmpty && state.selectedStudentIds.length == roster.length;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Table Header Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: Checkbox(
                      value: isAllSelected,
                      onChanged: (val) => notifier.selectAllStudents(val ?? false),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 55,
                    child: Text(
                      'Roll No.',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Student Name',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Row(
                      children: [
                        const Icon(Icons.view_timeline_rounded, size: 14, color: Color(0xFF6366F1)),
                        const SizedBox(width: 5),
                        Text(
                          'Periods Breakdown',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Status',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Remarks (Optional)',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Last Updated',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 32),
                ],
              ),
            ),
            Divider(height: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),

            // Student Rows
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: roster.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final student = roster[index];
                final currentStatus = state.draftStatuses[student.studentId] ?? student.status;
                final isSelected = state.selectedStudentIds.contains(student.studentId);
                final rollStr = student.rollNumber.isNotEmpty ? student.rollNumber : '${index + 1}';

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: isSelected
                      ? (isDark ? const Color(0xFF1E1B4B).withValues(alpha: 0.4) : const Color(0xFFEEF2FF))
                      : Colors.transparent,
                  child: Row(
                    children: [
                      // Checkbox
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: Checkbox(
                          value: isSelected,
                          onChanged: (_) => notifier.toggleStudentSelection(student.studentId),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Roll Number
                      SizedBox(
                        width: 55,
                        child: Text(
                          rollStr,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                          ),
                        ),
                      ),

                      // Student Photo Avatar + Full Name
                      Expanded(
                        flex: 3,
                        child: InkWell(
                          onTap: () {
                            setState(() => _selectedDrawerStudent = student);
                            widget.onSelectStudent?.call(student);
                          },
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                                  border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.2)),
                                ),
                                child: ClipOval(
                                  child: student.avatarUrl != null
                                      ? Image.network(student.avatarUrl!, fit: BoxFit.cover)
                                      : Center(
                                          child: Text(
                                            student.fullName.isNotEmpty ? student.fullName[0].toUpperCase() : 'S',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF4F46E5)),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  student.fullName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Periods Attendance Breakdown (Interactive Period Chips)
                      Expanded(
                        flex: 4,
                        child: _buildStudentPeriodsCell(student, state, notifier, isDark),
                      ),

                      // Interactive Status Pill (with 1-click mode-aware dropdown & rich hover breakdown)
                      Expanded(
                        flex: 3,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _buildInteractiveStatusPill(student, currentStatus, state, notifier, isDark),
                        ),
                      ),

                      // Remarks Field / Interactive Editable Box
                      Expanded(
                        flex: 3,
                        child: _buildEditableRemarksCell(student, state, notifier, isDark),
                      ),

                      // Last Updated (09:15 AM by Neha Sharma)
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              student.lastUpdatedAt != null
                                  ? '${student.lastUpdatedAt!.hour.toString().padLeft(2, '0')}:${student.lastUpdatedAt!.minute.toString().padLeft(2, '0')} AM'
                                  : '09:15 AM',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'by ${student.updatedByName ?? "Neha Sharma"}',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Row Action Menu ⋮
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert_rounded, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onSelected: (val) {
                          if (val == 'view') {
                            setState(() => _selectedDrawerStudent = student);
                          } else if (val == 'remark') {
                            final curRem = state.draftRemarks[student.studentId] ?? student.remarks;
                            _showEditRemarkDialog(student, curRem, notifier);
                          } else if (val == 'override') {
                            _showOverrideDialog(student, currentStatus, notifier);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'view',
                            child: Row(
                              children: [
                                Icon(Icons.visibility_rounded, size: 16, color: Color(0xFF4F46E5)),
                                SizedBox(width: 8),
                                Text('View Details & History', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'remark',
                            child: Row(
                              children: [
                                Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFF6366F1)),
                                SizedBox(width: 8),
                                Text('Add / Edit Remark', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'override',
                            child: Row(
                              children: [
                                Icon(Icons.lock_reset_rounded, size: 16, color: Color(0xFFD97706)),
                                SizedBox(width: 8),
                                Text('Override Lock with Reason', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // PERIOD ATTENDANCE BREAKDOWN CELL (Interactive Period Badges for Student)
  // ==========================================================================
  Widget _buildStudentPeriodsCell(
    AttendanceStudentRowModel student,
    AttendanceState state,
    AttendanceNotifier notifier,
    bool isDark,
  ) {
    if (student.periods.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'No Periods',
          style: TextStyle(
            fontSize: 10.5,
            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: student.periods.map((period) {
          final isSelectedInMulti = state.selectedScheduleIds.contains(period.scheduleId) ||
              (period.subjectId != null && state.selectedScheduleIds.contains(period.subjectId));

          Color statusColor;
          IconData statusIcon;
          switch (period.status) {
            case AttendanceStatus.present:
              statusColor = const Color(0xFF10B981);
              statusIcon = Icons.check_circle_rounded;
              break;
            case AttendanceStatus.absent:
              statusColor = const Color(0xFFEF4444);
              statusIcon = Icons.cancel_rounded;
              break;
            case AttendanceStatus.late:
              statusColor = const Color(0xFFF59E0B);
              statusIcon = Icons.watch_later_rounded;
              break;
            case AttendanceStatus.onLeave:
              statusColor = const Color(0xFF8B5CF6);
              statusIcon = Icons.event_busy_rounded;
              break;
            case AttendanceStatus.halfDay:
              statusColor = const Color(0xFF6366F1);
              statusIcon = Icons.pie_chart_rounded;
              break;
            default:
              statusColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
              statusIcon = Icons.remove_circle_outline_rounded;
          }

          final tooltipMsg = '${period.periodLabel}: ${period.subjectName}\n'
              'Time: ${period.timeRange}\n'
              'Teacher: ${period.teacherName}\n'
              'Status: ${period.status.label}${period.updatedByName != null ? ' (by ${period.updatedByName})' : ''}'
              '${period.remarks.isNotEmpty ? '\nRemarks: ${period.remarks}' : ''}\n'
              '👉 Click to quick change attendance';

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Tooltip(
              message: tooltipMsg,
              preferBelow: false,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
              ),
              textStyle: const TextStyle(fontSize: 11, color: Colors.white, height: 1.3),
              child: PopupMenuButton<AttendanceStatus>(
                tooltip: '',
                offset: const Offset(0, 28),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                onSelected: (newStatus) {
                  if (period.isLocked) {
                    _showOverridePeriodDialog(
                      student: student,
                      period: period,
                      targetStatus: newStatus,
                      notifier: notifier,
                    );
                  } else {
                    notifier.quickMarkStudentPeriod(
                      studentId: student.studentId,
                      periodNumber: period.periodNumber,
                      status: newStatus,
                      subjectId: period.subjectId,
                      scheduleId: period.scheduleId,
                    );
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${period.periodLabel}: ${period.subjectName}',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          '${student.fullName} • ${period.timeRange}',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                        ),
                        const Divider(height: 12),
                      ],
                    ),
                  ),
                  _buildStatusMenuItem(AttendanceStatus.present, 'Mark Present', Icons.check_circle_rounded, const Color(0xFF10B981)),
                  _buildStatusMenuItem(AttendanceStatus.absent, 'Mark Absent', Icons.cancel_rounded, const Color(0xFFEF4444)),
                  _buildStatusMenuItem(AttendanceStatus.late, 'Mark Late', Icons.watch_later_rounded, const Color(0xFFF59E0B)),
                  _buildStatusMenuItem(AttendanceStatus.onLeave, 'Mark On Leave', Icons.event_busy_rounded, const Color(0xFF8B5CF6)),
                  _buildStatusMenuItem(AttendanceStatus.halfDay, 'Mark Half Day', Icons.pie_chart_rounded, const Color(0xFF6366F1)),
                  _buildStatusMenuItem(AttendanceStatus.notMarked, 'Reset (Not Marked)', Icons.remove_circle_outline_rounded, const Color(0xFF94A3B8)),
                ],
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: period.status != AttendanceStatus.notMarked
                        ? statusColor.withValues(alpha: isDark ? 0.2 : 0.1)
                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelectedInMulti
                          ? const Color(0xFF8B5CF6)
                          : (period.status != AttendanceStatus.notMarked
                              ? statusColor.withValues(alpha: 0.5)
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                      width: isSelectedInMulti ? 1.6 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: period.subjectColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        period.periodLabel,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        statusIcon,
                        size: 12,
                        color: statusColor,
                      ),
                      if (period.isLocked) ...[
                        const SizedBox(width: 2),
                        Icon(Icons.lock_rounded, size: 9, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ==========================================================================
  // INTERACTIVE STATUS PROGRESS PILL (with Rich Hover Tooltip & 1-Click Dropdown)
  // ==========================================================================
  Widget _buildInteractiveStatusPill(
    AttendanceStudentRowModel student,
    AttendanceStatus status,
    AttendanceState state,
    AttendanceNotifier notifier,
    bool isDark,
  ) {
    Color bg;
    Color text;
    Color border;
    IconData icon;
    String displayLabel;
    final summary = student.periodsSummary;

    AttendanceStatus effectiveStatus;
    if (state.selectedMode == AttendanceMode.byPeriod) {
      final activePNum = state.selectedPeriodNumber ?? (student.periods.isNotEmpty ? student.periods.first.periodNumber : 1);
      final activeP = student.periods.where((p) => p.periodNumber == activePNum).firstOrNull;
      effectiveStatus = activeP?.status ?? AttendanceStatus.notMarked;
    } else {
      effectiveStatus = status;
    }

    switch (effectiveStatus) {
      case AttendanceStatus.present:
        bg = const Color(0xFFECFDF5);
        text = const Color(0xFF15803D);
        border = const Color(0xFFBBF7D0);
        icon = Icons.check_rounded;
        displayLabel = 'Present';
        break;
      case AttendanceStatus.absent:
        bg = const Color(0xFFFEF2F2);
        text = const Color(0xFFB91C1C);
        border = const Color(0xFFFECACA);
        icon = Icons.close_rounded;
        displayLabel = 'Absent';
        break;
      case AttendanceStatus.late:
        bg = const Color(0xFFFFFBEB);
        text = const Color(0xFFB45309);
        border = const Color(0xFFFDE68A);
        icon = Icons.access_time_filled_rounded;
        displayLabel = 'Late';
        break;
      case AttendanceStatus.onLeave:
        bg = const Color(0xFFEFF6FF);
        text = const Color(0xFF1D4ED8);
        border = const Color(0xFFBFDBFE);
        icon = Icons.calendar_month_rounded;
        displayLabel = 'On Leave';
        break;
      case AttendanceStatus.halfDay:
        bg = const Color(0xFFFAF5FF);
        text = const Color(0xFF6B21A8);
        border = const Color(0xFFE9D5FF);
        icon = Icons.pie_chart_rounded;
        displayLabel = 'Half Day';
        break;
      case AttendanceStatus.partialPeriods:
        bg = const Color(0xFFE0F2FE);
        text = const Color(0xFF0369A1);
        border = const Color(0xFFBAE6FD);
        icon = Icons.pie_chart_outline_rounded;
        displayLabel = 'Partial';
        break;
      default:
        bg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
        text = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
        border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
        icon = Icons.remove_rounded;
        displayLabel = 'Not Marked';
    }

    // Build rich, multi-line formatted hover tooltip
    String tooltipMsg;
    if (student.periods.isNotEmpty) {
      final periodLines = student.periods.map((p) {
        String iconStr = p.status == AttendanceStatus.present
            ? '✓'
            : (p.status == AttendanceStatus.absent
                ? '✗'
                : (p.status == AttendanceStatus.late
                    ? '🕒'
                    : (p.status == AttendanceStatus.onLeave
                        ? '📋'
                        : (p.status == AttendanceStatus.halfDay ? '◐' : '-'))));
        return '• ${p.periodLabel} (${p.subjectName}): ${p.status.label} $iconStr';
      }).join('\n');

      final summaryLine = summary != null
          ? 'Summary: ${summary.presentCount} Present, ${summary.absentCount} Absent, ${summary.lateCount} Late, ${summary.onLeaveCount} Leave (${summary.markedPeriods}/${summary.totalPeriods} Periods Marked)'
          : '${student.periods.length} Periods Scheduled';

      tooltipMsg = '${student.fullName} • Status: $displayLabel${student.isLocked ? " (Locked)" : ""}\n'
          '─────────────────────────────\n'
          '$periodLines\n'
          '─────────────────────────────\n'
          '$summaryLine\n'
          '👉 Click to change attendance for active mode';
    } else {
      tooltipMsg = '${student.fullName} • Status: $displayLabel${student.isLocked ? " (Locked)" : ""}\n👉 Click to change attendance';
    }

    String modeHelpText;
    if (state.selectedMode == AttendanceMode.allDay) {
      modeHelpText = 'Whole Day (Updates all periods)';
    } else if (state.selectedMode == AttendanceMode.byPeriod) {
      modeHelpText = 'Period ${state.selectedPeriodNumber ?? 1} Only';
    } else {
      modeHelpText = 'Custom (${state.selectedScheduleIds.length} Periods)';
    }

    return Tooltip(
      message: tooltipMsg,
      preferBelow: false,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3))],
      ),
      textStyle: const TextStyle(fontSize: 11, color: Colors.white, height: 1.35),
      child: PopupMenuButton<AttendanceStatus>(
        tooltip: '',
        offset: const Offset(0, 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onSelected: (newStatus) {
          bool isTargetLocked;
          if (state.selectedMode == AttendanceMode.byPeriod) {
            final activePNum = state.selectedPeriodNumber ?? (student.periods.isNotEmpty ? student.periods.first.periodNumber : 1);
            final activeP = student.periods.where((p) => p.periodNumber == activePNum).firstOrNull;
            isTargetLocked = activeP?.isLocked ?? false;
          } else {
            isTargetLocked = student.isLocked && state.isLockedAllDay;
          }

          if (isTargetLocked) {
            _showOverrideDialog(student, newStatus, notifier);
          } else {
            notifier.markAttendance(newStatus, targetStudentIds: {student.studentId});
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            enabled: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.fullName,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                Text(
                  'Mode: $modeHelpText',
                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF6366F1), fontWeight: FontWeight.w600),
                ),
                const Divider(height: 10),
              ],
            ),
          ),
          _buildStatusMenuItem(AttendanceStatus.present, 'Mark Present', Icons.check_circle_rounded, const Color(0xFF10B981)),
          _buildStatusMenuItem(AttendanceStatus.absent, 'Mark Absent', Icons.cancel_rounded, const Color(0xFFEF4444)),
          _buildStatusMenuItem(AttendanceStatus.late, 'Mark Late', Icons.watch_later_rounded, const Color(0xFFF59E0B)),
          _buildStatusMenuItem(AttendanceStatus.onLeave, 'Mark On Leave', Icons.event_busy_rounded, const Color(0xFF8B5CF6)),
          _buildStatusMenuItem(AttendanceStatus.halfDay, 'Mark Half Day', Icons.pie_chart_rounded, const Color(0xFF6366F1)),
          _buildStatusMenuItem(AttendanceStatus.notMarked, 'Reset (Not Marked)', Icons.remove_circle_outline_rounded, const Color(0xFF94A3B8)),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayLabel,
                style: TextStyle(
                  color: text,
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(width: 6),
              Icon(icon, size: 14, color: text),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // FLOATING BULK ACTION BAR (When 1+ Students are Checked)
  // ==========================================================================
  Widget _buildFloatingBulkActionBar(
    AttendanceState state,
    AttendanceNotifier notifier,
    bool isDark,
    ThemeData theme,
  ) {
    final count = state.selectedStudentIds.length;
    if (count == 0) return const SizedBox.shrink();

    String modeText;
    Color modeColor;
    if (state.selectedMode == AttendanceMode.allDay) {
      modeText = 'Whole Day (All Periods)';
      modeColor = const Color(0xFF3B82F6);
    } else if (state.selectedMode == AttendanceMode.byPeriod) {
      modeText = 'Period ${state.selectedPeriodNumber ?? 1}';
      modeColor = const Color(0xFFF59E0B);
    } else {
      modeText = 'Custom (${state.selectedScheduleIds.length} Periods)';
      modeColor = const Color(0xFF8B5CF6);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          // Left: Selection count & Mode Tag
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count Selected',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: modeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: modeColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, size: 13, color: modeColor),
                    const SizedBox(width: 4),
                    Text(
                      'Mode: $modeText',
                      style: TextStyle(color: modeColor, fontWeight: FontWeight.w700, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Center: Instant Action Pills
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildBulkPill('Present', const Color(0xFF10B981), Icons.check_circle_rounded, () {
                _handleBulkMarkAttendance(context, state, notifier, AttendanceStatus.present, true);
              }),
              _buildBulkPill('Absent', const Color(0xFFEF4444), Icons.cancel_rounded, () {
                _handleBulkMarkAttendance(context, state, notifier, AttendanceStatus.absent, true);
              }),
              _buildBulkPill('Late', const Color(0xFFF59E0B), Icons.watch_later_rounded, () {
                _handleBulkMarkAttendance(context, state, notifier, AttendanceStatus.late, true);
              }),
              _buildBulkPill('On Leave', const Color(0xFF8B5CF6), Icons.event_busy_rounded, () {
                _handleBulkMarkAttendance(context, state, notifier, AttendanceStatus.onLeave, true);
              }),
              _buildBulkPill('Half Day', const Color(0xFF6366F1), Icons.pie_chart_rounded, () {
                _handleBulkMarkAttendance(context, state, notifier, AttendanceStatus.halfDay, true);
              }),
              _buildBulkPill('Remarks', isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569), Icons.edit_note_rounded, () {
                _showBulkRemarksDialog(state, notifier, true);
              }),
            ],
          ),

          // Right: Deselect All & Save
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                onPressed: () => notifier.selectAllStudents(false),
                icon: const Icon(Icons.close_rounded, size: 14),
                label: const Text('Deselect', style: TextStyle(fontSize: 11.5)),
                style: TextButton.styleFrom(
                  foregroundColor: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                onPressed: state.isSaving
                    ? null
                    : () {
                        final selectedClass = state.availableClasses.firstWhere(
                          (c) => c.id == state.selectedClassId,
                          orElse: () => AcademicClassModel(id: '', name: 'Class', code: '', stage: ''),
                        );
                        final className = selectedClass.name;
                        String sectionName = 'All Sections';
                        if (state.selectedSectionId != null && selectedClass.sections.isNotEmpty) {
                          final foundSection = selectedClass.sections.where((s) => s.id == state.selectedSectionId);
                          if (foundSection.isNotEmpty) {
                            sectionName = foundSection.first.name;
                          }
                        }
                        showDialog(
                          context: context,
                          builder: (context) => AttendanceConfirmationDialog(
                            dateStr: state.displayDateString,
                            className: className,
                            sectionName: sectionName,
                            modeName: state.selectedMode == AttendanceMode.allDay
                                ? 'All Day'
                                : (state.selectedMode == AttendanceMode.byPeriod
                                    ? 'Period ${state.selectedPeriodNumber ?? 1}'
                                    : 'Custom Selection (${state.selectedScheduleIds.length} Periods)'),
                            totalCount: state.roster.length,
                            presentCount: state.roster.where((s) => (state.draftStatuses[s.studentId] ?? s.status) == AttendanceStatus.present).length,
                            absentCount: state.roster.where((s) => (state.draftStatuses[s.studentId] ?? s.status) == AttendanceStatus.absent).length,
                            lateCount: state.roster.where((s) => (state.draftStatuses[s.studentId] ?? s.status) == AttendanceStatus.late).length,
                            onLeaveCount: state.roster.where((s) => (state.draftStatuses[s.studentId] ?? s.status) == AttendanceStatus.onLeave).length,
                            onConfirm: () => notifier.saveDailyAttendance(),
                          ),
                        );
                      },
                icon: state.isSaving
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 15),
                label: Text(
                  state.isSaving ? 'Saving...' : 'Save & Submit ($count)',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBulkPill(String label, Color color, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<AttendanceStatus> _buildStatusMenuItem(
    AttendanceStatus status,
    String label,
    IconData icon,
    Color color,
  ) {
    return PopupMenuItem(
      value: status,
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ==========================================================================
  // 6. QUICK STATUS LEGEND ROW (Matching Image 1)
  // ==========================================================================
  Widget _buildStatusLegendRow(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildLegendChip('Present (P)', const Color(0xFF10B981)),
          const SizedBox(width: 16),
          _buildLegendChip('Absent (A)', const Color(0xFFEF4444)),
          const SizedBox(width: 16),
          _buildLegendChip('Late (L)', const Color(0xFFF59E0B)),
          const SizedBox(width: 16),
          _buildLegendChip('On Leave (O)', const Color(0xFF3B82F6)),
          const SizedBox(width: 16),
          _buildLegendChip('Half Day (H)', const Color(0xFF8B5CF6)),
          const SizedBox(width: 16),
          _buildLegendChip('Not Marked (-)', const Color(0xFF9CA3AF)),
        ],
      ),
    );
  }

  Widget _buildLegendChip(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 1.5),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // 7. BOTTOM SAVE & PAGINATION BAR (Matching Image 1)
  // ==========================================================================
  Widget _buildBottomSaveAndPaginationBar(
    AttendanceState state,
    AttendanceNotifier notifier,
    bool isDark,
    ThemeData theme,
  ) {
    final selectedCount = state.selectedStudentIds.length;
    final total = state.totalCount > 0 ? state.totalCount : state.roster.length;
    final start = total == 0 ? 0 : ((state.page - 1) * state.pageSize) + 1;
    final end = total == 0 ? 0 : math.min(state.page * state.pageSize, total);

    final currentPage = state.page;
    final totalPages = math.max(1, state.totalPages);

    List<Widget> pageButtons = [];
    if (total == 0 || totalPages <= 1) {
      pageButtons.add(_buildPageNumberButton(1, true, isDark, onTap: null));
    } else {
      int startPage = math.max(1, currentPage - 2);
      int endPage = math.min(totalPages, startPage + 4);
      if (endPage - startPage < 4) {
        startPage = math.max(1, endPage - 4);
      }

      if (startPage > 1) {
        pageButtons.add(_buildPageNumberButton(1, 1 == currentPage, isDark, onTap: () => notifier.setPage(1)));
        if (startPage > 2) {
          pageButtons.add(Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text('...', style: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
          ));
        }
      }

      for (int p = startPage; p <= endPage; p++) {
        final pageNum = p;
        pageButtons.add(_buildPageNumberButton(pageNum, pageNum == currentPage, isDark, onTap: () => notifier.setPage(pageNum)));
      }

      if (endPage < totalPages) {
        if (endPage < totalPages - 1) {
          pageButtons.add(Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text('...', style: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
          ));
        }
        pageButtons.add(_buildPageNumberButton(totalPages, totalPages == currentPage, isDark, onTap: () => notifier.setPage(totalPages)));
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: 0 Selected | Showing 1 to 5 of 40 students
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$selectedCount Selected',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'Showing $start to $end of $total students',
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),

          // Center: Pagination Controls < [1] [2] ... > + 5 / page
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left_rounded, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                onPressed: state.page > 1 ? () => notifier.setPage(state.page - 1) : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              const SizedBox(width: 4),
              ...pageButtons.expand((w) => [w, const SizedBox(width: 4)]).toList()..removeLast(),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.chevron_right_rounded, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                onPressed: state.page < state.totalPages ? () => notifier.setPage(state.page + 1) : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              const SizedBox(width: 10),

              // Page size selector (5, 10, 20, 50 / page)
              Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: [5, 10, 20, 50].contains(state.pageSize) ? state.pageSize : 10,
                    icon: Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    items: [5, 10, 20, 50].map((size) {
                      return DropdownMenuItem<int>(
                        value: size,
                        child: Text('$size / page', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                      );
                    }).toList(),
                    onChanged: (newSize) {
                      if (newSize != null) notifier.setPageSize(newSize);
                    },
                  ),
                ),
              ),
            ],
          ),

          // Right: Cancel + Save Attendance Button
          Row(
            children: [
              OutlinedButton(
                onPressed: () => notifier.resetDrafts(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                  side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Cancel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: state.isSaving
                    ? null
                    : () {
                        final selectedClass = state.availableClasses.firstWhere(
                          (c) => c.id == state.selectedClassId,
                          orElse: () => AcademicClassModel(id: '', name: 'Class', code: '', stage: ''),
                        );
                        final className = selectedClass.name;
                        String sectionName = 'All Sections';
                        if (state.selectedSectionId != null && selectedClass.sections.isNotEmpty) {
                          final foundSection = selectedClass.sections.where((s) => s.id == state.selectedSectionId);
                          if (foundSection.isNotEmpty) {
                            sectionName = foundSection.first.name;
                          }
                        }
                        showDialog(
                          context: context,
                          builder: (context) => AttendanceConfirmationDialog(
                            dateStr: state.displayDateString,
                            className: className,
                            sectionName: sectionName,
                            modeName: state.selectedMode == AttendanceMode.allDay
                                ? 'All Day'
                                : (state.selectedMode == AttendanceMode.byPeriod
                                    ? 'Period ${state.selectedPeriodNumber ?? 1}'
                                    : 'Custom Selection (${state.selectedScheduleIds.length} Periods)'),
                            totalCount: state.roster.length,
                            presentCount: state.roster.where((s) => (state.draftStatuses[s.studentId] ?? s.status) == AttendanceStatus.present).length,
                            absentCount: state.roster.where((s) => (state.draftStatuses[s.studentId] ?? s.status) == AttendanceStatus.absent).length,
                            lateCount: state.roster.where((s) => (state.draftStatuses[s.studentId] ?? s.status) == AttendanceStatus.late).length,
                            onLeaveCount: state.roster.where((s) => (state.draftStatuses[s.studentId] ?? s.status) == AttendanceStatus.onLeave).length,
                            onConfirm: () => notifier.saveDailyAttendance(),
                          ),
                        );
                      },
                icon: state.isSaving
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 15),
                label: Text(
                  state.isSaving ? 'Saving...' : 'Save Attendance',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPageNumberButton(int page, bool isActive, bool isDark, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF4F46E5) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isActive ? null : Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          '$page',
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
            color: isActive ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // RIGHT SIDEBAR CARD 1: DAY SUMMARY CHART (Donut Chart & Percentages)
  // ==========================================================================
  Widget _buildDaySummaryCard(AttendanceState state, bool isDark, ThemeData theme) {
    final selectedClass = state.availableClasses.firstWhere(
      (c) => c.id == state.selectedClassId,
      orElse: () => state.availableClasses.isNotEmpty
          ? state.availableClasses.first
          : AcademicClassModel(id: '', name: 'Class', code: '', stage: ''),
    );
    final className = selectedClass.name.isNotEmpty ? selectedClass.name : 'Class';
    String sectionName = '';
    if (state.selectedSectionId != null && selectedClass.sections.isNotEmpty) {
      final foundSection = selectedClass.sections.where((s) => s.id == state.selectedSectionId);
      if (foundSection.isNotEmpty) {
        sectionName = foundSection.first.name;
      }
    }
    final classDisplayTitle = state.selectedSectionId == null
        ? '$className - All Sections'
        : (sectionName.isNotEmpty ? '$className - $sectionName' : className);

    final total = state.roster.length;
    final present = state.roster.where((s) => (state.draftStatuses[s.studentId] ?? s.status) == AttendanceStatus.present).length;
    final absent = state.roster.where((s) => (state.draftStatuses[s.studentId] ?? s.status) == AttendanceStatus.absent).length;
    final lateCount = state.roster.where((s) => (state.draftStatuses[s.studentId] ?? s.status) == AttendanceStatus.late).length;
    final onLeave = state.roster.where((s) => (state.draftStatuses[s.studentId] ?? s.status) == AttendanceStatus.onLeave).length;
    final halfDay = state.roster.where((s) => (state.draftStatuses[s.studentId] ?? s.status) == AttendanceStatus.halfDay).length;

    final presentPct = total > 0 ? ((present / total) * 100).toStringAsFixed(1) : '0.0';
    final absentPct = total > 0 ? ((absent / total) * 100).toStringAsFixed(1) : '0.0';
    final latePct = total > 0 ? ((lateCount / total) * 100).toStringAsFixed(1) : '0.0';
    final leavePct = total > 0 ? ((onLeave / total) * 100).toStringAsFixed(1) : '0.0';
    final halfDayPct = total > 0 ? ((halfDay / total) * 100).toStringAsFixed(1) : '0.0';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Day Summary ($classDisplayTitle)',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),

          // Donut Chart with '$total Total' Center Label
          Center(
            child: SizedBox(
              width: 140,
              height: 140,
              child: CustomPaint(
                painter: _AttendanceDonutChartPainter(
                  present: present,
                  absent: absent,
                  lateCount: lateCount,
                  onLeave: onLeave,
                  halfDay: halfDay,
                  total: total,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$total',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Legend Breakdown with Counts and Percentages
          _buildDaySummaryLegendRow('Present', '$present ($presentPct%)', const Color(0xFF10B981), isDark),
          const SizedBox(height: 8),
          _buildDaySummaryLegendRow('Absent', '$absent ($absentPct%)', const Color(0xFFEF4444), isDark),
          const SizedBox(height: 8),
          _buildDaySummaryLegendRow('Late', '$lateCount ($latePct%)', const Color(0xFFF59E0B), isDark),
          const SizedBox(height: 8),
          _buildDaySummaryLegendRow('On Leave', '$onLeave ($leavePct%)', const Color(0xFF3B82F6), isDark),
          const SizedBox(height: 8),
          _buildDaySummaryLegendRow('Half Day', '$halfDay ($halfDayPct%)', const Color(0xFF8B5CF6), isDark),
        ],
      ),
    );
  }

  Widget _buildDaySummaryLegendRow(String label, String value, Color color, bool isDark) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // RIGHT SIDEBAR CARD 2: TODAY'S SCHEDULE (Dynamic from API)
  // ==========================================================================
  Widget _buildTodaysScheduleCard(
    AttendanceState state,
    AttendanceNotifier notifier,
    bool isDark,
    ThemeData theme,
  ) {
    final schedules = state.schedulesToday;
    final dateStr = DateFormat('dd MMM yyyy').format(state.selectedDate);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  "Today's Schedule ($dateStr)",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: state.selectedMode == AttendanceMode.allDay
                      ? const Color(0xFFECFDF5)
                      : (state.selectedMode == AttendanceMode.byPeriod ? const Color(0xFFEFF6FF) : const Color(0xFFF5F3FF)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      state.selectedMode == AttendanceMode.allDay
                          ? Icons.flash_on_rounded
                          : (state.selectedMode == AttendanceMode.byPeriod ? Icons.schedule_rounded : Icons.tune_rounded),
                      size: 11,
                      color: state.selectedMode == AttendanceMode.allDay
                          ? const Color(0xFF15803D)
                          : (state.selectedMode == AttendanceMode.byPeriod ? const Color(0xFF2563EB) : const Color(0xFF7C3AED)),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      state.selectedMode.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: state.selectedMode == AttendanceMode.allDay
                            ? const Color(0xFF15803D)
                            : (state.selectedMode == AttendanceMode.byPeriod ? const Color(0xFF2563EB) : const Color(0xFF7C3AED)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (schedules.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'No Academic Calendar schedule found for today',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: schedules.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final p = schedules[idx];
                final isCurrentPeriod = state.selectedMode == AttendanceMode.byPeriod && state.selectedPeriodNumber == p.periodNumber;

                return InkWell(
                  onTap: () {
                    notifier.setMode(AttendanceMode.byPeriod);
                    notifier.setPeriod(p.periodNumber, p.subjectId, scheduleId: p.scheduleId ?? p.id);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: isCurrentPeriod
                          ? (isDark ? const Color(0xFF312E81).withValues(alpha: 0.4) : const Color(0xFFEEF2FF))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: isCurrentPeriod ? Border.all(color: const Color(0xFF4F46E5), width: 1.2) : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 26,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isCurrentPeriod
                                ? const Color(0xFF4F46E5)
                                : p.subjectColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            p.periodLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isCurrentPeriod ? Colors.white : p.subjectColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 80,
                          child: Text(
                            p.timeRange,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      p.subjectName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (state.selectedSectionId == null && p.sectionName != null && p.sectionName!.isNotEmpty) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(
                                        'Sec ${p.sectionName}',
                                        style: TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                p.teacherName,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (p.isLocked)
                          const Icon(Icons.lock_rounded, size: 12, color: Color(0xFF64748B))
                        else if (p.isCompleted)
                          const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF10B981))
                        else
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF59E0B),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ==========================================================================
  // RIGHT SIDEBAR CARD 3: QUICK ACTIONS (2x2 Grid Matching Image 1)
  // ==========================================================================
  Widget _buildQuickActionsCard(
    AttendanceState state,
    AttendanceNotifier notifier,
    bool isDark,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _buildQuickActionTile(
                  title: 'By Period',
                  icon: Icons.calendar_today_rounded,
                  color: const Color(0xFF3B82F6),
                  bgColor: const Color(0xFFEFF6FF),
                  onTap: () => notifier.setMode(AttendanceMode.byPeriod),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildQuickActionTile(
                  title: 'Mark On Leave',
                  icon: Icons.calendar_month_rounded,
                  color: const Color(0xFF10B981),
                  bgColor: const Color(0xFFECFDF5),
                  onTap: () => notifier.setTab(2),
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _buildQuickActionTile(
                  title: 'Bulk Edit',
                  icon: Icons.edit_note_rounded,
                  color: const Color(0xFFEF4444),
                  bgColor: const Color(0xFFFEF2F2),
                  onTap: () => notifier.setTab(3),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildQuickActionTile(
                  title: 'Attendance Report',
                  icon: Icons.description_rounded,
                  color: const Color(0xFF8B5CF6),
                  bgColor: const Color(0xFFFAF5FF),
                  onTap: () => notifier.setTab(4),
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionTile({
    required String title,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? color.withValues(alpha: 0.08) : bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableRemarksCell(
    AttendanceStudentRowModel student,
    AttendanceState state,
    AttendanceNotifier notifier,
    bool isDark,
  ) {
    final currentRemark = state.draftRemarks[student.studentId] ?? student.remarks;
    final hasDraft = state.draftRemarks.containsKey(student.studentId);

    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => _showEditRemarkDialog(student, currentRemark, notifier),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: hasDraft
              ? (isDark ? const Color(0xFF312E81).withValues(alpha: 0.3) : const Color(0xFFEEF2FF))
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: hasDraft
                ? const Color(0xFF6366F1)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: hasDraft ? 1.2 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.edit_note_rounded,
              size: 15,
              color: hasDraft
                  ? const Color(0xFF6366F1)
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                currentRemark.isNotEmpty ? currentRemark : 'Add remark...',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: currentRemark.isNotEmpty ? FontWeight.w500 : FontWeight.normal,
                  fontStyle: currentRemark.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                  color: currentRemark.isNotEmpty
                      ? (isDark ? Colors.white : const Color(0xFF0F172A))
                      : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (currentRemark.isNotEmpty) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: () => notifier.updateStudentRemarks(student.studentId, ''),
                child: Icon(
                  Icons.close_rounded,
                  size: 13,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showOverrideDialog(
    AttendanceStudentRowModel student,
    AttendanceStatus targetStatus,
    AttendanceNotifier notifier,
  ) {
    showDialog(
      context: context,
      builder: (context) => AttendanceOverrideDialog(
        student: student,
        targetStatus: targetStatus,
        onConfirm: (reason) {
          notifier.overrideStudentRecord(
            recordId: student.id.isNotEmpty ? student.id : student.studentId,
            recordType: 'DAILY',
            newStatus: targetStatus,
            reason: reason,
          );
        },
      ),
    );
  }

  void _showOverridePeriodDialog({
    required AttendanceStudentRowModel student,
    required StudentPeriodAttendanceModel period,
    required AttendanceStatus targetStatus,
    required AttendanceNotifier notifier,
  }) {
    showDialog(
      context: context,
      builder: (context) => AttendanceOverrideDialog(
        student: student,
        periodNumber: period.periodNumber,
        periodLabel: '${period.periodLabel} (${period.subjectName})',
        targetStatus: targetStatus,
        onConfirm: (reason) {
          notifier.quickMarkStudentPeriod(
            studentId: student.studentId,
            periodNumber: period.periodNumber,
            status: targetStatus,
            remarks: reason,
            subjectId: period.subjectId,
            scheduleId: period.scheduleId,
          );
        },
      ),
    );
  }

  void _showBulkOverrideDialog({
    required BuildContext context,
    required List<AttendanceStudentRowModel> students,
    required AttendanceStatus targetStatus,
    required AttendanceNotifier notifier,
    bool hasSelection = false,
    Set<String>? targetStudentIds,
  }) {
    showDialog(
      context: context,
      builder: (context) => AttendanceOverrideDialog(
        bulkStudents: students,
        targetStatus: targetStatus,
        onConfirm: (reason) {
          notifier.markAttendance(
            targetStatus,
            remarks: reason,
            targetStudentIds: targetStudentIds,
          );
        },
      ),
    );
  }

  void _handleBulkMarkAttendance(
    BuildContext context,
    AttendanceState state,
    AttendanceNotifier notifier,
    AttendanceStatus status,
    bool hasSelection,
  ) {
    final targetStudents = hasSelection
        ? state.roster.where((s) => state.selectedStudentIds.contains(s.studentId)).toList()
        : state.roster;

    bool anyLocked;
    if (state.selectedMode == AttendanceMode.byPeriod) {
      final activePNum = state.selectedPeriodNumber ?? 1;
      anyLocked = targetStudents.any((s) {
        final p = s.periods.where((p) => p.periodNumber == activePNum).firstOrNull;
        return p?.isLocked ?? false;
      });
    } else {
      anyLocked = targetStudents.any((s) => s.isLocked) && state.isLockedAllDay;
    }

    if (anyLocked) {
      _showBulkOverrideDialog(
        context: context,
        students: targetStudents,
        targetStatus: status,
        notifier: notifier,
        hasSelection: hasSelection,
        targetStudentIds: hasSelection ? state.selectedStudentIds : null,
      );
    } else {
      notifier.markAttendance(
        status,
        targetStudentIds: hasSelection ? state.selectedStudentIds : null,
      );
    }
  }

  void _showEditRemarkDialog(
    AttendanceStudentRowModel student,
    String initialRemark,
    AttendanceNotifier notifier,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController(text: initialRemark);

    final quickChips = [
      'Medical appointment',
      'Late due to bus / transport',
      'Parent informed by phone',
      'Left early for sports / event',
      'Fever / Sick leave',
      'Family emergency',
      'Exempted by Principal',
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              child: Container(
                width: 480,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.edit_note_rounded, size: 22, color: Color(0xFF4F46E5)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Attendance Remark',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${student.fullName} ${student.rollNumber.isNotEmpty ? "(Roll: ${student.rollNumber})" : ""}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.of(ctx).pop(),
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Quick Remark Tags
                    Text(
                      'Quick Presets',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: quickChips.map((chip) {
                        return InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () {
                            controller.text = chip;
                            setDialogState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Text(
                              chip,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Text Field
                    TextField(
                      controller: controller,
                      maxLines: 3,
                      autofocus: true,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter student attendance remark, reason or note...',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFF4F46E5),
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Footer Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (controller.text.isNotEmpty)
                          TextButton.icon(
                            onPressed: () {
                              notifier.updateStudentRemarks(student.studentId, '');
                              Navigator.of(ctx).pop();
                            },
                            icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                            label: const Text('Clear Remark', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                          ),
                        const Spacer(),
                        OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () {
                            notifier.updateStudentRemarks(student.studentId, controller.text.trim());
                            Navigator.of(ctx).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Apply Remark', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// =============================================================================
// CUSTOM DONUT CHART PAINTER FOR DAY SUMMARY (Matching Image 1)
// =============================================================================
class _AttendanceDonutChartPainter extends CustomPainter {
  final int present;
  final int absent;
  final int lateCount;
  final int onLeave;
  final int halfDay;
  final int total;

  _AttendanceDonutChartPainter({
    required this.present,
    required this.absent,
    required this.lateCount,
    required this.onLeave,
    required this.halfDay,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    const strokeWidth = 14.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final safeTotal = total > 0 ? total : 1;
    final presentAngle = (present / safeTotal) * 2 * math.pi;
    final absentAngle = (absent / safeTotal) * 2 * math.pi;
    final lateAngle = (lateCount / safeTotal) * 2 * math.pi;
    final leaveAngle = (onLeave / safeTotal) * 2 * math.pi;
    final halfAngle = (halfDay / safeTotal) * 2 * math.pi;

    double startAngle = -math.pi / 2;
    const gap = 0.04;

    void drawSegment(double sweepAngle, Color color) {
      if (sweepAngle <= 0) return;
      paint.color = color;
      final actualSweep = math.max(0.01, sweepAngle - gap);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        actualSweep,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }

    // 1. Present Segment (Green)
    drawSegment(presentAngle, const Color(0xFF10B981));
    // 2. Absent Segment (Red)
    drawSegment(absentAngle, const Color(0xFFEF4444));
    // 3. Late Segment (Orange)
    drawSegment(lateAngle, const Color(0xFFF59E0B));
    // 4. Leave Segment (Blue)
    drawSegment(leaveAngle, const Color(0xFF3B82F6));
    // 5. Half Day Segment (Purple)
    drawSegment(halfAngle, const Color(0xFF8B5CF6));
  }

  @override
  bool shouldRepaint(covariant _AttendanceDonutChartPainter oldDelegate) {
    return oldDelegate.present != present ||
        oldDelegate.absent != absent ||
        oldDelegate.lateCount != lateCount ||
        oldDelegate.onLeave != onLeave ||
        oldDelegate.halfDay != halfDay ||
        oldDelegate.total != total;
  }
}
