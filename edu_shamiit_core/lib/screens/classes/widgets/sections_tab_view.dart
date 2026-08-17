import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/role_provider.dart';
import '../../../providers/auth_provider.dart';
import '../providers/class_provider.dart';
import 'dialogs/create_edit_section_dialog.dart';
import 'dialogs/assign_class_teacher_dialog.dart';
import 'dialogs/assign_students_dialog.dart';
import 'dialogs/manage_subjects_dialog.dart';
import 'dialogs/archive_confirmation_dialog.dart';

class SectionsTabView extends ConsumerStatefulWidget {
  const SectionsTabView({super.key});

  @override
  ConsumerState<SectionsTabView> createState() => _SectionsTabViewState();
}

class _SectionsTabViewState extends ConsumerState<SectionsTabView> {
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
    final roleState = ref.watch(roleProvider);
    final authState = ref.watch(authProvider);
    final isTeacher = roleState.isTeacher || authState.role == UserRole.teacher;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final sections = state.sections;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter & Search Controls Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 700;

                final searchField = TextField(
                  controller: _searchController,
                  onChanged: (v) => notifier.setSearchQuery(v),
                  decoration: InputDecoration(
                    hintText: 'Search section by name, room or code...',
                    hintStyle: TextStyle(
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
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
                );

                final classFilterDropdown = Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: state.selectedClassIdFilter ?? 'ALL',
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                      items: [
                        const DropdownMenuItem(value: 'ALL', child: Text('All Classes')),
                        ...state.classes.map(
                          (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                        ),
                      ],
                      onChanged: (v) => notifier.setClassFilter(v == 'ALL' ? null : v),
                    ),
                  ),
                );

                final statusFilterDropdown = Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: state.statusFilter,
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('All Status')),
                        DropdownMenuItem(value: 'ACTIVE', child: Text('Active Only')),
                        DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive Only')),
                        DropdownMenuItem(value: 'ARCHIVED', child: Text('Archived')),
                      ],
                      onChanged: (v) => notifier.setStatusFilter(v ?? 'ALL'),
                    ),
                  ),
                );

                if (isNarrow) {
                  return Column(
                    children: [
                      searchField,
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: classFilterDropdown),
                          const SizedBox(width: 10),
                          Expanded(child: statusFilterDropdown),
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(flex: 3, child: searchField),
                    const SizedBox(width: 12),
                    classFilterDropdown,
                    const SizedBox(width: 12),
                    statusFilterDropdown,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Main Table Container (100% full width)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              children: [
                if (state.isLoading)
                  const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))
                else if (sections.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(48),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.grid_off_rounded, size: 40, color: isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1)),
                          const SizedBox(height: 12),
                          Text(
                            'No sections found.',
                            style: TextStyle(fontSize: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 8),
                          if (!isTeacher)
                            ElevatedButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => CreateEditSectionDialog(
                                    availableClasses: state.classes,
                                    academicYear: state.academicYear,
                                    onSave: (payload) => notifier.createSection(
                                      classId: payload['class_id'],
                                      name: payload['name'],
                                      code: payload['code'],
                                      capacity: payload['capacity'],
                                      roomNumber: payload['room_number'],
                                      academicYear: payload['academic_year'],
                                      status: payload['status'],
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add New Section', style: TextStyle(fontSize: 12)),
                            ),
                        ],
                      ),
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final tableWidth = constraints.maxWidth < 950 ? 950.0 : constraints.maxWidth;

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: tableWidth,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                              isDark ? const Color(0xFF0F172A).withOpacity(0.5) : const Color(0xFFF8FAFC),
                            ),
                            dataRowMinHeight: 54,
                            dataRowMaxHeight: 58,
                            horizontalMargin: 20,
                            columnSpacing: 16,
                            columns: [
                              const DataColumn(label: Text('CLASS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                              const DataColumn(label: Text('SECTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                              const DataColumn(label: Text('CLASS TEACHER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                              const DataColumn(label: Text('STUDENTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                              const DataColumn(label: Text('ROOM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                              const DataColumn(label: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                              if (!isTeacher)
                                const DataColumn(label: Text('ACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                            ],
                            rows: sections.map((sec) {
                              final teacher = sec.classTeacher;

                              return DataRow(
                                cells: [
                                  // Class Name
                                  DataCell(
                                    InkWell(
                                      onTap: () {
                                        notifier.setActiveTab(0);
                                        if (sec.classId != null) {
                                          notifier.selectClassById(sec.classId!);
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(4),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Text(
                                          sec.className ?? '—',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13.5,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Section Badge (Click to Edit)
                                  DataCell(
                                    InkWell(
                                      onTap: isTeacher
                                          ? null
                                          : () {
                                              showDialog(
                                                context: context,
                                                builder: (ctx) => CreateEditSectionDialog(
                                                  sectionToEdit: sec,
                                                  availableClasses: state.classes,
                                                  onSave: (payload) => notifier.updateSection(
                                                    sec.id,
                                                    name: payload['name'],
                                                    code: payload['code'],
                                                    capacity: payload['capacity'],
                                                    roomNumber: payload['room_number'],
                                                    status: payload['status'],
                                                  ),
                                                ),
                                              );
                                            },
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          sec.name,
                                          style: const TextStyle(
                                            color: Color(0xFF059669),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Class Teacher
                                  DataCell(
                                    InkWell(
                                      onTap: isTeacher
                                          ? null
                                          : () {
                                              showDialog(
                                                context: context,
                                                builder: (ctx) => AssignClassTeacherDialog(
                                                  classId: sec.classId ?? '',
                                                  className: sec.className ?? 'Class',
                                                  sectionId: sec.id,
                                                  sectionName: sec.name,
                                                  currentlyAssigned: teacher != null ? [teacher] : [],
                                                  onSave: (teacherIds) => notifier.assignTeachers(
                                                    classId: sec.classId ?? '',
                                                    sectionId: sec.id,
                                                    teacherIds: teacherIds,
                                                  ),
                                                ),
                                              );
                                            },
                                      borderRadius: BorderRadius.circular(6),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                        child: teacher != null
                                            ? Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  CircleAvatar(
                                                    radius: 12,
                                                    backgroundColor: const Color(0xFF4F46E5).withOpacity(0.15),
                                                    backgroundImage: teacher.avatarUrl != null ? NetworkImage(teacher.avatarUrl!) : null,
                                                    child: teacher.avatarUrl == null
                                                        ? Text(
                                                            teacher.fullName.isNotEmpty ? teacher.fullName[0].toUpperCase() : 'T',
                                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                                                          )
                                                        : null,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    teacher.fullName,
                                                    style: TextStyle(
                                                      fontSize: 12.5,
                                                      fontWeight: FontWeight.w600,
                                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                  if (!isTeacher) ...[
                                                    const SizedBox(width: 4),
                                                    Icon(Icons.edit_outlined, size: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                                  ],
                                                ],
                                              )
                                            : Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.person_add_alt_1_outlined, size: 14, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Assign Teacher',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w500,
                                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ),

                                  // Students Count (Click to Assign for Admin/Staff)
                                  DataCell(
                                    InkWell(
                                      onTap: isTeacher
                                          ? null
                                          : () {
                                              showDialog(
                                                context: context,
                                                builder: (ctx) => AssignStudentsDialog(
                                                  classId: sec.classId ?? '',
                                                  className: sec.className ?? 'Class',
                                                  sectionId: sec.id,
                                                  sectionName: sec.name,
                                                  academicYear: state.academicYear,
                                                  onSave: (studentIds, confirmMove) => notifier.assignStudents(
                                                    classId: sec.classId ?? '',
                                                    sectionId: sec.id,
                                                    studentIds: studentIds,
                                                    confirmMove: confirmMove,
                                                  ),
                                                ),
                                              );
                                            },
                                      borderRadius: BorderRadius.circular(6),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '${sec.studentsCount} / ${sec.capacity}',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Icon(
                                              isTeacher ? Icons.group_outlined : Icons.group_add_outlined,
                                              size: 14,
                                              color: const Color(0xFF4F46E5).withOpacity(0.8),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Room Number
                                  DataCell(
                                    Text(
                                      sec.roomNumber != null && sec.roomNumber!.isNotEmpty ? sec.roomNumber! : '—',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),

                                  // Status
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: sec.status.toUpperCase() == 'ARCHIVED'
                                            ? const Color(0xFFF59E0B).withOpacity(0.12)
                                            : (sec.isActive
                                                ? const Color(0xFF10B981).withOpacity(0.12)
                                                : const Color(0xFFEF4444).withOpacity(0.12)),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        sec.status.toUpperCase() == 'ARCHIVED'
                                            ? 'Archived'
                                            : (sec.isActive ? 'Active' : 'Inactive'),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: sec.status.toUpperCase() == 'ARCHIVED'
                                              ? const Color(0xFFF59E0B)
                                              : (sec.isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Actions
                                  if (!isTeacher)
                                    DataCell(
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_horiz, size: 18),
                                        splashRadius: 18,
                                        onSelected: (val) {
                                          if (val == 'edit') {
                                            showDialog(
                                              context: context,
                                              builder: (ctx) => CreateEditSectionDialog(
                                                sectionToEdit: sec,
                                                availableClasses: state.classes,
                                                onSave: (payload) => notifier.updateSection(
                                                  sec.id,
                                                  name: payload['name'],
                                                  code: payload['code'],
                                                  capacity: payload['capacity'],
                                                  roomNumber: payload['room_number'],
                                                  status: payload['status'],
                                                ),
                                              ),
                                            );
                                          } else if (val == 'assign_teacher') {
                                            showDialog(
                                              context: context,
                                              builder: (ctx) => AssignClassTeacherDialog(
                                                classId: sec.classId ?? '',
                                                className: sec.className ?? 'Class',
                                                sectionId: sec.id,
                                                sectionName: sec.name,
                                                currentlyAssigned: teacher != null ? [teacher] : [],
                                                onSave: (teacherIds) => notifier.assignTeachers(
                                                  classId: sec.classId ?? '',
                                                  sectionId: sec.id,
                                                  teacherIds: teacherIds,
                                                ),
                                              ),
                                            );
                                          } else if (val == 'assign_students') {
                                            showDialog(
                                              context: context,
                                              builder: (ctx) => AssignStudentsDialog(
                                                classId: sec.classId ?? '',
                                                className: sec.className ?? 'Class',
                                                sectionId: sec.id,
                                                sectionName: sec.name,
                                                academicYear: state.academicYear,
                                                onSave: (studentIds, confirmMove) => notifier.assignStudents(
                                                  classId: sec.classId ?? '',
                                                  sectionId: sec.id,
                                                  studentIds: studentIds,
                                                  confirmMove: confirmMove,
                                                ),
                                              ),
                                            );
                                          } else if (val == 'manage_subjects') {
                                            showDialog(
                                              context: context,
                                              builder: (ctx) => ManageSubjectsDialog(
                                                classId: sec.classId ?? '',
                                                className: sec.className ?? 'Class',
                                                sectionId: sec.id,
                                                sectionName: sec.name,
                                                initialSubjectIds: sec.assignedSubjectIds,
                                                onSave: (subjectIds) => notifier.manageSubjects(
                                                  classId: sec.classId ?? '',
                                                  sectionId: sec.id,
                                                  subjectIds: subjectIds,
                                                ),
                                              ),
                                            );
                                          } else if (val == 'restore') {
                                            notifier.restoreSection(sec.id);
                                          } else if (val == 'archive') {
                                            showDialog(
                                              context: context,
                                              builder: (ctx) => ArchiveConfirmationDialog(
                                                title: 'Archive Section',
                                                itemName: '${sec.className ?? 'Class'} - Section ${sec.name}',
                                                impactDetails: {
                                                  'Assigned Students': sec.studentsCount,
                                                },
                                                onConfirm: (force) => notifier.archiveSection(sec.id, force: force),
                                              ),
                                            );
                                          }
                                        },
                                        itemBuilder: (ctx) => [
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Row(children: [Icon(Icons.edit_outlined, size: 16), SizedBox(width: 8), Text('Edit Section')]),
                                          ),
                                          const PopupMenuItem(
                                            value: 'assign_teacher',
                                            child: Row(children: [Icon(Icons.person_add_outlined, size: 16), SizedBox(width: 8), Text('Assign Class Teacher')]),
                                          ),
                                          const PopupMenuItem(
                                            value: 'assign_students',
                                            child: Row(children: [Icon(Icons.group_add_outlined, size: 16), SizedBox(width: 8), Text('Assign Students')]),
                                          ),
                                          const PopupMenuItem(
                                            value: 'manage_subjects',
                                            child: Row(children: [Icon(Icons.menu_book_outlined, size: 16), SizedBox(width: 8), Text('Manage Section Subjects')]),
                                          ),
                                          const PopupMenuDivider(),
                                          if (sec.status.toUpperCase() == 'ARCHIVED')
                                            const PopupMenuItem(
                                              value: 'restore',
                                              child: Row(children: [Icon(Icons.unarchive_outlined, size: 16, color: Color(0xFF10B981)), SizedBox(width: 8), Text('Restore Section', style: TextStyle(color: Color(0xFF10B981)))]),
                                            )
                                          else
                                            const PopupMenuItem(
                                              value: 'archive',
                                              child: Row(children: [Icon(Icons.archive_outlined, size: 16, color: Color(0xFFEF4444)), SizedBox(width: 8), Text('Archive Section', style: TextStyle(color: Color(0xFFEF4444)))]),
                                            ),
                                        ],
                                      ),
                                    ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  ),

                // Pagination Bar
                if (state.totalPages > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Showing ${(state.page - 1) * state.pageSize + 1} to ${((state.page) * state.pageSize).clamp(0, state.totalCount)} of ${state.totalCount} sections',
                          style: TextStyle(fontSize: 12.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: state.page > 1 ? () => notifier.setPage(state.page - 1) : null,
                              icon: const Icon(Icons.chevron_left, size: 20),
                              splashRadius: 18,
                            ),
                            Text('${state.page} / ${state.totalPages}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
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
        ],
      ),
    );
  }
}
