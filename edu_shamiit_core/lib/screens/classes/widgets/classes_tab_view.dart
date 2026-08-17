import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/role_provider.dart';
import '../../../providers/auth_provider.dart';
import '../models/class_models.dart';
import '../providers/class_provider.dart';
import 'class_card_item.dart';
import 'sections_table_in_class.dart';
import 'subjects_table_in_class.dart';
import 'dialogs/create_edit_class_dialog.dart';
import 'dialogs/assign_class_teacher_dialog.dart';
import 'dialogs/assign_students_dialog.dart';
import 'dialogs/manage_subjects_dialog.dart';
import 'dialogs/archive_confirmation_dialog.dart';

class ClassesTabView extends ConsumerStatefulWidget {
  const ClassesTabView({super.key});

  @override
  ConsumerState<ClassesTabView> createState() => _ClassesTabViewState();
}

class _ClassesTabViewState extends ConsumerState<ClassesTabView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(classProvider);
    final notifier = ref.read(classProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final selectedClass = state.selectedClassDetail ?? state.selectedClass;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 900;

        if (isMobile) {
          // Responsive Mobile / Tablet Layout (Vertical Stack with Top Class Selector)
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Class Quick Selector Bar
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (v) => notifier.setSearchQuery(v),
                              decoration: InputDecoration(
                                hintText: 'Search classes...',
                                hintStyle: TextStyle(
                                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                  fontSize: 12.5,
                                ),
                                prefixIcon: const Icon(Icons.search, size: 16),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                ),
                              ),
                              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 12.5),
                            ),
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              ),
                              child: const Icon(Icons.filter_list_rounded, size: 16),
                            ),
                            onSelected: (val) => notifier.setStatusFilter(val),
                            itemBuilder: (ctx) => const [
                              PopupMenuItem(value: 'ALL', child: Text('All Classes')),
                              PopupMenuItem(value: 'ACTIVE', child: Text('Active Only')),
                              PopupMenuItem(value: 'INACTIVE', child: Text('Inactive Only')),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Horizontal scrollable class chips
                      SizedBox(
                        height: 38,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: state.classes.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, idx) {
                            final cls = state.classes[idx];
                            final isSel = selectedClass?.id == cls.id;

                            return ChoiceChip(
                              label: Text(cls.name),
                              selected: isSel,
                              selectedColor: const Color(0xFF4F46E5),
                              labelStyle: TextStyle(
                                color: isSel ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                fontSize: 12,
                              ),
                              backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              onSelected: (_) => notifier.selectClass(cls),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (selectedClass != null) ...[
                  // Header of Selected Class
                  _buildClassHeader(context, selectedClass, isDark, notifier, isMobile: true),
                  const SizedBox(height: 16),

                  // 4 Summary Metrics Cards (Responsive Grid)
                  _buildSummaryMetricCards(selectedClass, isDark),
                  const SizedBox(height: 20),

                  // Sections Table In Class
                  SectionsTableInClass(
                    academicClass: selectedClass,
                    sections: state.selectedClassDetail?.sections ?? [],
                  ),
                  const SizedBox(height: 20),

                  // Subjects Table In Class
                  SubjectsTableInClass(
                    academicClass: selectedClass,
                    subjects: state.selectedClassDetail?.subjects ?? [],
                  ),
                ] else
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No class selected.'),
                    ),
                  ),
              ],
            ),
          );
        }

        // Desktop 2-Column Master-Detail Layout
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Master List (Width: 340)
            SizedBox(
              width: 340,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A).withOpacity(0.4) : const Color(0xFFF8FAFC),
                  border: Border(
                    right: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    // Search & Filter
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (v) => notifier.setSearchQuery(v),
                              decoration: InputDecoration(
                                hintText: 'Search classes...',
                                hintStyle: TextStyle(
                                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                  fontSize: 13,
                                ),
                                prefixIcon: const Icon(Icons.search, size: 18),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                ),
                              ),
                              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              ),
                              child: const Icon(Icons.filter_list_rounded, size: 18),
                            ),
                            tooltip: 'Filter by Status',
                            onSelected: (val) => notifier.setStatusFilter(val),
                            itemBuilder: (ctx) => const [
                              PopupMenuItem(value: 'ALL', child: Text('All Classes')),
                              PopupMenuItem(value: 'ACTIVE', child: Text('Active Only')),
                              PopupMenuItem(value: 'INACTIVE', child: Text('Inactive Only')),
                              PopupMenuItem(value: 'ARCHIVED', child: Text('Archived')),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Classes List
                    Expanded(
                      child: state.isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : state.classes.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.class_outlined, size: 36, color: isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1)),
                                        const SizedBox(height: 12),
                                        Text(
                                          'No classes found',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  itemCount: state.classes.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final cls = state.classes[index];
                                    final isSelected = selectedClass?.id == cls.id;

                                    return ClassCardItem(
                                      academicClass: cls,
                                      isSelected: isSelected,
                                      onTap: () => notifier.selectClass(cls),
                                    );
                                  },
                                ),
                    ),

                    // Pagination Footer
                    if (state.totalPages > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${(state.page - 1) * state.pageSize + 1}-${((state.page) * state.pageSize).clamp(0, state.totalCount)} of ${state.totalCount}',
                              style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: state.page > 1 ? () => notifier.setPage(state.page - 1) : null,
                                  icon: const Icon(Icons.chevron_left, size: 20),
                                  splashRadius: 18,
                                ),
                                Text('${state.page} / ${state.totalPages}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                IconButton(
                                  onPressed: state.page < state.totalPages ? () => notifier.setPage(state.page + 1) : null,
                                  icon: const Icon(Icons.chevron_right, size: 20),
                                  splashRadius: 18,
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

            // Right Detail View (Expanded full width on desktop)
            Expanded(
              child: selectedClass == null
                  ? Center(
                      child: Text(
                        'Select a class to view overview and details.',
                        style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header of Selected Class
                          _buildClassHeader(context, selectedClass, isDark, notifier),
                          const SizedBox(height: 20),

                          // 4 Summary Metrics Cards
                          _buildSummaryMetricCards(selectedClass, isDark),
                          const SizedBox(height: 24),

                          // Sections Table In Class
                          SectionsTableInClass(
                            academicClass: selectedClass,
                            sections: state.selectedClassDetail?.sections ?? [],
                          ),
                          const SizedBox(height: 24),

                          // Subjects Table In Class
                          SubjectsTableInClass(
                            academicClass: selectedClass,
                            subjects: state.selectedClassDetail?.subjects ?? [],
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildClassHeader(
    BuildContext context,
    AcademicClassModel cls,
    bool isDark,
    ClassNotifier notifier, {
    bool isMobile = false,
  }) {
    final match = RegExp(r'\d+').firstMatch(cls.name);
    final badgeText = match != null ? match.group(0)! : cls.code;
    final badgeColor = cls.badgeColor;

    final badgeAndTitle = Row(
      children: [
        // Big Colored Badge
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: badgeColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: badgeColor.withOpacity(0.3), width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(
            badgeText,
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Class Name & Stage
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      cls.name,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: cls.status.toUpperCase() == 'ARCHIVED'
                          ? const Color(0xFFF59E0B).withOpacity(0.15)
                          : (cls.isActive
                              ? const Color(0xFF10B981).withOpacity(0.15)
                              : const Color(0xFFEF4444).withOpacity(0.15)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      cls.status.toUpperCase() == 'ARCHIVED'
                          ? 'Archived'
                          : (cls.isActive ? 'Active' : 'Inactive'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: cls.status.toUpperCase() == 'ARCHIVED'
                            ? const Color(0xFFF59E0B)
                            : (cls.isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${cls.stage} Stage • Code: ${cls.code} • Academic Year ${cls.academicYear}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final roleState = ref.watch(roleProvider);
    final authState = ref.watch(authProvider);
    final isTeacher = roleState.isTeacher || authState.role == UserRole.teacher;

    final actions = isTeacher
        ? const SizedBox.shrink()
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => CreateEditClassDialog(
                      classToEdit: cls,
                      academicYear: cls.academicYear,
                      onSave: (payload) => notifier.updateClass(
                        cls.id,
                        name: payload['name'],
                        code: payload['code'],
                        stage: payload['stage'],
                        displayOrder: payload['display_order'],
                        status: payload['status'],
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.edit_outlined, size: 15),
                label: const Text('Edit Class', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
              ),
              const SizedBox(width: 8),

              PopupMenuButton<String>(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  child: const Icon(Icons.more_vert, size: 18),
                ),
                onSelected: (val) {
                  if (val == 'assign_teachers') {
                    showDialog(
                      context: context,
                      builder: (ctx) => AssignClassTeacherDialog(
                        classId: cls.id,
                        className: cls.name,
                        currentlyAssigned: cls.classTeachers,
                        onSave: (teacherIds) => notifier.assignTeachers(
                          classId: cls.id,
                          teacherIds: teacherIds,
                        ),
                      ),
                    );
                  } else if (val == 'assign_students') {
                    showDialog(
                      context: context,
                      builder: (ctx) => AssignStudentsDialog(
                        classId: cls.id,
                        className: cls.name,
                        academicYear: cls.academicYear,
                        onSave: (studentIds, confirmMove) => notifier.assignStudents(
                          classId: cls.id,
                          studentIds: studentIds,
                          confirmMove: confirmMove,
                        ),
                      ),
                    );
                  } else if (val == 'assign_subjects') {
                    final classState = ref.read(classProvider);
                    showDialog(
                      context: context,
                      builder: (ctx) => ManageSubjectsDialog(
                        classId: cls.id,
                        className: cls.name,
                        currentlyAssigned: classState.selectedClassDetail?.id == cls.id ? (classState.selectedClassDetail?.subjects ?? const []) : const [],
                        onSave: (subjectIds) => notifier.manageSubjects(
                          classId: cls.id,
                          subjectIds: subjectIds,
                        ),
                      ),
                    );
                  } else if (val == 'restore') {
                    notifier.restoreClass(cls.id);
                  } else if (val == 'archive') {
                    showDialog(
                      context: context,
                      builder: (ctx) => ArchiveConfirmationDialog(
                        title: 'Archive Class',
                        itemName: cls.name,
                        impactDetails: {
                          'Sections Affected': cls.sectionsCount,
                          'Students Enrolled': cls.studentsCount,
                          'Subjects Linked': cls.subjectsCount,
                        },
                        onConfirm: (force) => notifier.archiveClass(cls.id, force: force),
                      ),
                    );
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'assign_teachers',
                    child: Row(children: [Icon(Icons.person_pin_outlined, size: 16), SizedBox(width: 8), Text('Assign Class Teachers')]),
                  ),
                  const PopupMenuItem(
                    value: 'assign_students',
                    child: Row(children: [Icon(Icons.group_add_outlined, size: 16), SizedBox(width: 8), Text('Assign Students Directly')]),
                  ),
                  const PopupMenuItem(
                    value: 'assign_subjects',
                    child: Row(children: [Icon(Icons.auto_stories_outlined, size: 16), SizedBox(width: 8), Text('Manage Class Subjects')]),
                  ),
                  const PopupMenuDivider(),
                  if (cls.status.toUpperCase() == 'ARCHIVED')
                    const PopupMenuItem(
                      value: 'restore',
                      child: Row(children: [Icon(Icons.unarchive_outlined, size: 16, color: Color(0xFF10B981)), SizedBox(width: 8), Text('Restore Class', style: TextStyle(color: Color(0xFF10B981)))]),
                    )
                  else
                    const PopupMenuItem(
                      value: 'archive',
                      child: Row(children: [Icon(Icons.archive_outlined, size: 16, color: Color(0xFFEF4444)), SizedBox(width: 8), Text('Archive Class', style: TextStyle(color: Color(0xFFEF4444)))]),
                    ),
                ],
              ),
            ],
          );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          badgeAndTitle,
          if (!isTeacher) ...[
            const SizedBox(height: 12),
            actions,
          ],
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: badgeAndTitle),
        actions,
      ],
    );
  }

  Widget _buildSummaryMetricCards(AcademicClassModel cls, bool isDark) {
    final primaryTeacher = cls.primaryTeacher ?? (cls.classTeachers.isNotEmpty ? cls.classTeachers.first : null);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final int cols = availableWidth >= 800 ? 4 : (availableWidth >= 450 ? 2 : 1);
        final cardWidth = (availableWidth - (cols - 1) * 16) / cols;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            // Card 1: Sections
            _buildMetricCard(
              width: cardWidth,
              icon: Icons.grid_view_rounded,
              iconColor: const Color(0xFF4F46E5),
              title: '${cls.sectionsCount}',
              subtitle: 'Sections',
              isDark: isDark,
            ),

            // Card 2: Students
            _buildMetricCard(
              width: cardWidth,
              icon: Icons.people_alt_rounded,
              iconColor: const Color(0xFF10B981),
              title: '${cls.studentsCount}',
              subtitle: 'Students',
              isDark: isDark,
            ),

            // Card 3: Class Teacher
            _buildTeacherMetricCard(
              width: cardWidth,
              teacher: primaryTeacher,
              isDark: isDark,
            ),

            // Card 4: Status
            _buildStatusMetricCard(
              width: cardWidth,
              status: cls.status,
              isDark: isDark,
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required double width,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherMetricCard({
    required double width,
    required AcademicTeacherModel? teacher,
    required bool isDark,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.person_pin_rounded, color: Color(0xFF6366F1), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  teacher != null ? teacher.fullName : 'Not Assigned',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Class Teacher',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusMetricCard({
    required double width,
    required String status,
    required bool isDark,
  }) {
    final isArchived = status.toUpperCase() == 'ARCHIVED';
    final isActive = status.toUpperCase() == 'ACTIVE';
    final color = isArchived
        ? const Color(0xFFF59E0B)
        : (isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444));
    final icon = isArchived
        ? Icons.archive_rounded
        : (isActive ? Icons.check_circle_rounded : Icons.cancel_rounded);
    final text = isArchived ? 'Archived' : (isActive ? 'Active' : 'Inactive');

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'Status',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
