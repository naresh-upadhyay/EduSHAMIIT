import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/role_provider.dart';
import '../../../providers/auth_provider.dart';
import '../models/class_models.dart';
import '../providers/class_provider.dart';
import 'dialogs/create_edit_subject_dialog.dart';
import 'dialogs/manage_subjects_dialog.dart';
import 'dialogs/archive_confirmation_dialog.dart';

class SubjectsTableInClass extends ConsumerWidget {
  final AcademicClassModel academicClass;
  final List<AcademicSubjectModel> subjects;

  const SubjectsTableInClass({
    super.key,
    required this.academicClass,
    required this.subjects,
  });

  Color _getTypeColor(String type) {
    final t = type.toLowerCase();
    if (t.contains('core')) {
      return const Color(0xFF3B82F6);
    } else if (t.contains('elec') || t.contains('opt')) {
      return const Color(0xFFF59E0B);
    } else if (t.contains('lang')) {
      return const Color(0xFFEC4899);
    } else if (t.contains('prac') || t.contains('lab')) {
      return const Color(0xFF10B981);
    }
    return const Color(0xFF8B5CF6);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(classProvider);
    final notifier = ref.read(classProvider.notifier);
    final roleState = ref.watch(roleProvider);
    final authState = ref.watch(authProvider);
    final isTeacher = roleState.isTeacher || authState.role == UserRole.teacher;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subjects of ${academicClass.name}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${subjects.length} Subject${subjects.length == 1 ? '' : 's'} assigned for academic syllabus',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (!isTeacher) ...[
                      // + Assign Subject button
                      ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => ManageSubjectsDialog(
                              classId: academicClass.id,
                              className: academicClass.name,
                              currentlyAssigned: subjects,
                              onSave: (subjectIds) => notifier.manageSubjects(
                                classId: academicClass.id,
                                subjectIds: subjectIds,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.playlist_add, size: 16),
                        label: const Text('Assign Subject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    // View all subjects ->
                    InkWell(
                      onTap: () {
                        notifier.setActiveTab(2);
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Row(
                          children: [
                            Text(
                              'View all subjects',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4F46E5)),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward, size: 14, color: Color(0xFF4F46E5)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Table Content
          if (subjects.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.auto_stories_outlined, size: 36, color: isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1)),
                    const SizedBox(height: 8),
                    Text(
                      'No subjects assigned to this class syllabus yet.',
                      style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Click "+ Assign Subject" to add curriculum subjects from catalog.',
                      style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final tableWidth = constraints.maxWidth < 700 ? 700.0 : constraints.maxWidth;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        isDark ? const Color(0xFF0F172A).withOpacity(0.4) : const Color(0xFFF8FAFC),
                      ),
                      dataRowMinHeight: 50,
                      dataRowMaxHeight: 54,
                      horizontalMargin: 20,
                      columnSpacing: 16,
                      columns: [
                        const DataColumn(label: Text('SUBJECT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                        const DataColumn(label: Text('CODE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                        const DataColumn(label: Text('TYPE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                        const DataColumn(label: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                        const DataColumn(label: Text('SCOPE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                        if (!isTeacher)
                          const DataColumn(label: Text('ACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                      ],
                      rows: subjects.map((sub) {
                        final typeColor = _getTypeColor(sub.type);

                        return DataRow(
                          cells: [
                            // Subject Name & Colored Initial
                            DataCell(
                              InkWell(
                                onTap: isTeacher
                                    ? null
                                    : () {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => CreateEditSubjectDialog(
                                            subjectToEdit: sub,
                                            availableClasses: state.availableClasses,
                                            onSave: (payload) => notifier.updateSubject(
                                              sub.id,
                                              name: payload['name'],
                                              code: payload['code'],
                                              type: payload['type'],
                                              description: payload['description'],
                                              color: payload['color'],
                                              status: payload['status'],
                                              isOptional: payload['is_optional'],
                                            ),
                                          ),
                                        );
                                      },
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          color: sub.subjectColor.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          sub.code.isNotEmpty ? sub.code.substring(0, sub.code.length > 2 ? 2 : sub.code.length) : 'S',
                                          style: TextStyle(
                                            color: sub.subjectColor,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 10.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        sub.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Code
                            DataCell(
                              Text(
                                sub.code,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                ),
                              ),
                            ),

                            // Type
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: typeColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  sub.type,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: typeColor,
                                  ),
                                ),
                              ),
                            ),

                            // Status
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: sub.status.toUpperCase() == 'ARCHIVED'
                                      ? const Color(0xFFF59E0B).withOpacity(0.12)
                                      : (sub.isActive
                                          ? const Color(0xFF10B981).withOpacity(0.12)
                                          : const Color(0xFFEF4444).withOpacity(0.12)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  sub.status.toUpperCase() == 'ARCHIVED'
                                      ? 'Archived'
                                      : (sub.isActive ? 'Active' : 'Inactive'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: sub.status.toUpperCase() == 'ARCHIVED'
                                        ? const Color(0xFFF59E0B)
                                        : (sub.isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                                  ),
                                ),
                              ),
                            ),

                            // Scope
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (sub.sectionNames != null && sub.sectionNames != 'All Sections')
                                      ? const Color(0xFF6366F1).withOpacity(0.1)
                                      : (isDark ? const Color(0xFF334155).withOpacity(0.5) : const Color(0xFFF1F5F9)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  sub.sectionNames ?? (sub.isClassWide ? 'All Sections' : 'Section Specific'),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: (sub.sectionNames != null && sub.sectionNames != 'All Sections')
                                        ? const Color(0xFF6366F1)
                                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
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
                                        builder: (ctx) => CreateEditSubjectDialog(
                                          subjectToEdit: sub,
                                          availableClasses: state.availableClasses,
                                          onSave: (payload) => notifier.updateSubject(
                                            sub.id,
                                            name: payload['name'],
                                            code: payload['code'],
                                            type: payload['type'],
                                            description: payload['description'],
                                            color: payload['color'],
                                            status: payload['status'],
                                            isOptional: payload['is_optional'],
                                          ),
                                        ),
                                      );
                                    } else if (val == 'unassign') {
                                      // Remove this subject from class syllabus
                                      final currentIds = subjects.map((s) => s.id).toList();
                                      currentIds.remove(sub.id);
                                      notifier.manageSubjects(
                                        classId: academicClass.id,
                                        subjectIds: currentIds,
                                      );
                                    } else if (val == 'restore') {
                                      notifier.restoreSubject(sub.id);
                                    } else if (val == 'archive') {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => ArchiveConfirmationDialog(
                                          title: 'Archive Subject',
                                          itemName: sub.name,
                                          impactDetails: {
                                            'Classes Affected': sub.classesCount,
                                          },
                                          onConfirm: (force) => notifier.archiveSubject(sub.id, force: force),
                                        ),
                                      );
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(children: [Icon(Icons.edit_outlined, size: 16), SizedBox(width: 8), Text('Edit Subject')]),
                                    ),
                                    const PopupMenuItem(
                                      value: 'unassign',
                                      child: Row(children: [Icon(Icons.link_off_rounded, size: 16, color: Color(0xFFF59E0B)), SizedBox(width: 8), Text('Remove from Class', style: TextStyle(color: Color(0xFFF59E0B)))]),
                                    ),
                                    const PopupMenuDivider(),
                                    if (sub.status.toUpperCase() == 'ARCHIVED')
                                      const PopupMenuItem(
                                        value: 'restore',
                                        child: Row(children: [Icon(Icons.unarchive_outlined, size: 16, color: Color(0xFF10B981)), SizedBox(width: 8), Text('Restore Subject', style: TextStyle(color: Color(0xFF10B981)))]),
                                      )
                                    else
                                      const PopupMenuItem(
                                        value: 'archive',
                                        child: Row(children: [Icon(Icons.archive_outlined, size: 16, color: Color(0xFFEF4444)), SizedBox(width: 8), Text('Archive from Catalog', style: TextStyle(color: Color(0xFFEF4444)))]),
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
        ],
      ),
    );
  }
}
