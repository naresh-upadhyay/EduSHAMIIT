import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/role_provider.dart';
import '../../../providers/auth_provider.dart';
import '../providers/class_provider.dart';
import 'dialogs/create_edit_subject_dialog.dart';
import 'dialogs/archive_confirmation_dialog.dart';

class SubjectsTabView extends ConsumerStatefulWidget {
  const SubjectsTabView({super.key});

  @override
  ConsumerState<SubjectsTabView> createState() => _SubjectsTabViewState();
}

class _SubjectsTabViewState extends ConsumerState<SubjectsTabView> {
  final TextEditingController _searchController = TextEditingController();

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'core':
        return const Color(0xFF3B82F6);
      case 'elective':
        return const Color(0xFFF59E0B);
      case 'language':
        return const Color(0xFFEC4899);
      case 'practical':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF8B5CF6);
    }
  }

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

    final subjects = state.subjects;

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
                    hintText: 'Search subjects by title or code...',
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

                final typeFilterDropdown = Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: state.subjectTypeFilter,
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('All Subject Types')),
                        DropdownMenuItem(value: 'Core', child: Text('Core Subjects')),
                        DropdownMenuItem(value: 'Elective', child: Text('Electives')),
                        DropdownMenuItem(value: 'Language', child: Text('Languages')),
                        DropdownMenuItem(value: 'Practical', child: Text('Practicals')),
                        DropdownMenuItem(value: 'Activity', child: Text('Activities')),
                      ],
                      onChanged: (v) => notifier.setSubjectTypeFilter(v ?? 'ALL'),
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
                          Expanded(child: typeFilterDropdown),
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
                    typeFilterDropdown,
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
                else if (subjects.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(48),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.menu_book_rounded, size: 40, color: isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1)),
                          const SizedBox(height: 12),
                          Text(
                            'No subjects found in catalog.',
                            style: TextStyle(fontSize: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 8),
                          if (!isTeacher)
                            ElevatedButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => CreateEditSubjectDialog(
                                    availableClasses: state.classes,
                                    onSave: (payload) => notifier.createSubject(
                                      name: payload['name'],
                                      code: payload['code'],
                                      type: payload['type'],
                                      description: payload['description'],
                                      periodsPerWeek: payload['periods_per_week'],
                                      color: payload['color'],
                                      status: payload['status'],
                                      classIds: List<String>.from(payload['class_ids'] ?? []),
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add New Subject', style: TextStyle(fontSize: 12)),
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
                              const DataColumn(label: Text('SUBJECT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                              const DataColumn(label: Text('CODE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                              const DataColumn(label: Text('TYPE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                              const DataColumn(label: Text('PERIODS/WK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                              const DataColumn(label: Text('CLASSES ASSIGNED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                              const DataColumn(label: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                              if (!isTeacher)
                                const DataColumn(label: Text('ACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                            ],
                            rows: subjects.map((sub) {
                              final typeColor = _getTypeColor(sub.type);

                              return DataRow(
                                cells: [
                                  // Subject Name & Colored Square Avatar (Click to edit)
                                  DataCell(
                                    InkWell(
                                      onTap: isTeacher
                                          ? null
                                          : () {
                                              showDialog(
                                                context: context,
                                                builder: (ctx) => CreateEditSubjectDialog(
                                                  subjectToEdit: sub,
                                                  availableClasses: state.classes,
                                                  onSave: (payload) => notifier.updateSubject(
                                                    sub.id,
                                                    name: payload['name'],
                                                    code: payload['code'],
                                                    type: payload['type'],
                                                    description: payload['description'],
                                                    periodsPerWeek: payload['periods_per_week'],
                                                    color: payload['color'],
                                                    status: payload['status'],
                                                    classIds: List<String>.from(payload['class_ids'] ?? []),
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
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: sub.subjectColor.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                sub.code.isNotEmpty ? sub.code.substring(0, sub.code.length > 2 ? 2 : sub.code.length) : 'S',
                                                style: TextStyle(
                                                  color: sub.subjectColor,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  sub.name,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 13.5,
                                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                  ),
                                                ),
                                                if (sub.description != null && sub.description!.isNotEmpty)
                                                  Text(
                                                    sub.description!,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                              ],
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
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                      ),
                                    ),
                                  ),

                                  // Type
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: typeColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        sub.type,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: typeColor,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Periods/Week
                                  DataCell(
                                    Text(
                                      '${sub.periodsPerWeek} / week',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                      ),
                                    ),
                                  ),

                                  // Classes Count (Click to open edit / assign)
                                  DataCell(
                                    InkWell(
                                      onTap: () {
                                        notifier.setActiveTab(0);
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4F46E5).withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '${sub.classesCount} Classes',
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF4F46E5),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(Icons.arrow_drop_down, size: 14, color: Color(0xFF4F46E5)),
                                          ],
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
                                            ? const Color(0xFFF59E0B).withOpacity(0.15)
                                            : (sub.isActive
                                                ? const Color(0xFF10B981).withOpacity(0.15)
                                                : const Color(0xFFEF4444).withOpacity(0.15)),
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
                                                availableClasses: state.classes,
                                                onSave: (payload) => notifier.updateSubject(
                                                  sub.id,
                                                  name: payload['name'],
                                                  code: payload['code'],
                                                  type: payload['type'],
                                                  description: payload['description'],
                                                  periodsPerWeek: payload['periods_per_week'],
                                                  color: payload['color'],
                                                  status: payload['status'],
                                                  classIds: List<String>.from(payload['class_ids'] ?? []),
                                                ),
                                              ),
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
                                          const PopupMenuDivider(),
                                          if (sub.status.toUpperCase() == 'ARCHIVED')
                                            const PopupMenuItem(
                                              value: 'restore',
                                              child: Row(children: [Icon(Icons.unarchive_outlined, size: 16, color: Color(0xFF10B981)), SizedBox(width: 8), Text('Restore Subject', style: TextStyle(color: Color(0xFF10B981)))]),
                                            )
                                          else
                                            const PopupMenuItem(
                                              value: 'archive',
                                              child: Row(children: [Icon(Icons.archive_outlined, size: 16, color: Color(0xFFEF4444)), SizedBox(width: 8), Text('Archive Subject', style: TextStyle(color: Color(0xFFEF4444)))]),
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

                // Pagination
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
                          'Showing ${(state.page - 1) * state.pageSize + 1} to ${((state.page) * state.pageSize).clamp(0, state.totalCount)} of ${state.totalCount} subjects',
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
