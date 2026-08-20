import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/role_provider.dart';
import '../../../providers/auth_provider.dart';
import '../models/class_models.dart';
import '../providers/class_provider.dart';
import '../services/academic_lookup_helper.dart';
import 'dialogs/create_edit_class_dialog.dart';
import 'dialogs/create_edit_section_dialog.dart';
import 'dialogs/create_edit_subject_dialog.dart';
import 'dialogs/assign_class_teacher_dialog.dart';
import 'dialogs/assign_subject_teacher_dialog.dart';
import 'dialogs/optional_subject_enrollment_dialog.dart';
import 'dialogs/manage_subjects_dialog.dart';
import 'dialogs/archive_confirmation_dialog.dart';

class ClassesTabView extends ConsumerStatefulWidget {
  const ClassesTabView({super.key});

  @override
  ConsumerState<ClassesTabView> createState() => _ClassesTabViewState();
}

class _ClassesTabViewState extends ConsumerState<ClassesTabView> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStageFilter = 'ALL';
  String _selectedStatusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    final state = ref.read(classProvider);
    _searchController.text = state.classSearchQuery;
    _selectedStageFilter = state.classStageFilter;
    _selectedStatusFilter = state.classStatusFilter;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getClassBadgeColor(String name) {
    final clean = name.replaceAll(RegExp(r'[^0-9]'), '');
    final num = int.tryParse(clean) ?? name.hashCode.abs();

    const colors = [
      Color(0xFF8B5CF6), // 0 / default - Purple
      Color(0xFFF59E0B), // 1 - Amber
      Color(0xFF10B981), // 2 - Green
      Color(0xFF3B82F6), // 3 - Blue
      Color(0xFFEC4899), // 4 - Pink
      Color(0xFFEAB308), // 5 - Yellow
      Color(0xFF6366F1), // 6 - Indigo
      Color(0xFFF43F5E), // 7 - Rose
      Color(0xFF14B8A6), // 8 - Teal
      Color(0xFF8B5CF6), // 9 - Purple
      Color(0xFF10B981), // 10 - Emerald
      Color(0xFFF97316), // 11 - Orange
      Color(0xFF06B6D4), // 12 - Cyan
    ];
    return colors[num % colors.length];
  }

  String _getClassGradeNumber(String name) {
    final clean = name.replaceAll(RegExp(r'[^0-9]'), '').trim();
    if (clean.isNotEmpty) return clean;
    if (name.length >= 2) return name.substring(0, 2).toUpperCase();
    return name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'C';
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

    final selectedClass = state.selectedClass;
    final detail = state.selectedClassDetail;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 1050;

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildClassListSidebar(context, state, notifier, isDark),
                const SizedBox(height: 24),
                if (selectedClass != null)
                  _buildClassDetailPanel(context, state, notifier, selectedClass, detail, isTeacher, isDark)
                else
                  _buildEmptySelectionPlaceholder(isDark),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Master Class List Column (approx 32%)
              SizedBox(
                width: 330,
                child: _buildClassListSidebar(context, state, notifier, isDark),
              ),
              const SizedBox(width: 24),

              // Right Detail Column (approx 68%)
              Expanded(
                child: selectedClass != null
                    ? _buildClassDetailPanel(context, state, notifier, selectedClass, detail, isTeacher, isDark)
                    : _buildEmptySelectionPlaceholder(isDark),
              ),
            ],
          );
        },
      ),
    );
  }

  // =========================================================================
  // 1. LEFT MASTER COLUMN: CLASS LIST CARDS
  // =========================================================================
  Widget _buildClassListSidebar(
    BuildContext context,
    ClassState state,
    ClassNotifier notifier,
    bool isDark,
  ) {
    final classes = state.classes;
    final hasActiveFilter = _selectedStageFilter != 'ALL' || _selectedStatusFilter != 'ALL';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search & Filter Header
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (v) => notifier.searchClasses(v.trim()),
                    onChanged: (v) {
                      if (v.trim().isEmpty) {
                        notifier.searchClasses('');
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Search classes...',
                      hintStyle: TextStyle(
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        fontSize: 12.5,
                      ),
                      prefixIcon: const Icon(Icons.search, size: 16),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 14),
                              onPressed: () {
                                _searchController.clear();
                                notifier.searchClasses('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                    ),
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 12.5),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: 'Filter Classes',
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: hasActiveFilter
                          ? const Color(0xFF4F46E5).withOpacity(0.15)
                          : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: hasActiveFilter
                            ? const Color(0xFF4F46E5)
                            : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                    ),
                    child: Icon(
                      Icons.filter_list_rounded,
                      size: 16,
                      color: hasActiveFilter ? const Color(0xFF4F46E5) : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                    ),
                  ),
                  onSelected: (val) {
                    if (val.startsWith('status:')) {
                      final status = val.substring('status:'.length);
                      setState(() => _selectedStatusFilter = status);
                      notifier.setClassStatusFilter(status);
                    } else if (val.startsWith('stage:')) {
                      final stage = val.substring('stage:'.length);
                      setState(() => _selectedStageFilter = stage);
                      notifier.setClassStageFilter(stage);
                    }
                  },
                  itemBuilder: (ctx) {
                    final stages = AcademicLookupHelper.instance.getCachedLookup('CLASS_STAGE');
                    return [
                      const PopupMenuItem<String>(
                        enabled: false,
                        child: Text('FILTER BY STATUS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                      ),
                      PopupMenuItem<String>(
                        value: 'status:ALL',
                        child: Row(
                          children: [
                            Icon(Icons.check, size: 14, color: _selectedStatusFilter == 'ALL' ? const Color(0xFF4F46E5) : Colors.transparent),
                            const SizedBox(width: 6),
                            const Text('All Statuses', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'status:ACTIVE',
                        child: Row(
                          children: [
                            Icon(Icons.check, size: 14, color: _selectedStatusFilter == 'ACTIVE' ? const Color(0xFF4F46E5) : Colors.transparent),
                            const SizedBox(width: 6),
                            const Text('Active Only', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'status:INACTIVE',
                        child: Row(
                          children: [
                            Icon(Icons.check, size: 14, color: _selectedStatusFilter == 'INACTIVE' ? const Color(0xFF4F46E5) : Colors.transparent),
                            const SizedBox(width: 6),
                            const Text('Inactive Only', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'status:ARCHIVED',
                        child: Row(
                          children: [
                            Icon(Icons.check, size: 14, color: _selectedStatusFilter == 'ARCHIVED' ? const Color(0xFF4F46E5) : Colors.transparent),
                            const SizedBox(width: 6),
                            const Text('Archived Only', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem<String>(
                        enabled: false,
                        child: Text('FILTER BY STAGE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                      ),
                      PopupMenuItem<String>(
                        value: 'stage:ALL',
                        child: Row(
                          children: [
                            Icon(Icons.check, size: 14, color: _selectedStageFilter == 'ALL' ? const Color(0xFF4F46E5) : Colors.transparent),
                            const SizedBox(width: 6),
                            const Text('All Stages', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                      ...stages.map(
                        (s) => PopupMenuItem<String>(
                          value: 'stage:${s.label}',
                          child: Row(
                            children: [
                              Icon(Icons.check, size: 14, color: _selectedStageFilter == s.label ? const Color(0xFF4F46E5) : Colors.transparent),
                              const SizedBox(width: 6),
                              Text(s.label, style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ];
                  },
                ),
              ],
            ),
          ),
          if (_selectedStageFilter != 'ALL' || _selectedStatusFilter != 'ALL')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14).copyWith(bottom: 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (_selectedStatusFilter != 'ALL')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Status: ${_selectedStatusFilter == "ACTIVE" ? "Active" : (_selectedStatusFilter == "INACTIVE" ? "Inactive" : "Archived")}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4F46E5)),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () {
                              setState(() => _selectedStatusFilter = 'ALL');
                              notifier.setStatusFilter('ALL');
                            },
                            child: const Icon(Icons.close, size: 13, color: Color(0xFF4F46E5)),
                          ),
                        ],
                      ),
                    ),
                  if (_selectedStageFilter != 'ALL')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Stage: $_selectedStageFilter',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4F46E5)),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () {
                              setState(() => _selectedStageFilter = 'ALL');
                              notifier.setClassStageFilter('ALL');
                            },
                            child: const Icon(Icons.close, size: 13, color: Color(0xFF4F46E5)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          const Divider(height: 1),

          // Class List
          if (state.isLoading)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
          else if (classes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text('No classes found.', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: classes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final cls = classes[index];
                final isSelected = state.selectedClass?.id == cls.id;
                final badgeColor = _getClassBadgeColor(cls.name);
                final gradeNum = _getClassGradeNumber(cls.name);

                final secCount = cls.sectionsCount;
                final stuCount = cls.studentsCount;

                return InkWell(
                  onTap: () => notifier.selectClass(cls),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF4F46E5).withOpacity(0.06)
                          : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF4F46E5)
                            : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Grade Badge
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            gradeNum,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: badgeColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Class Name & Stage
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cls.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                cls.stage,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Sections, Students & Status
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$secCount Sections',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$stuCount Students',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: cls.isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

          // Bottom Pagination Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Builder(
              builder: (context) {
                final startItem = state.totalCount == 0 ? 0 : (state.page - 1) * state.pageSize + 1;
                final endItem = (state.page * state.pageSize) > state.totalCount ? state.totalCount : (state.page * state.pageSize);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        '$startItem-$endItem of ${state.totalCount}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                          splashRadius: 14,
                          tooltip: 'Previous Page',
                          onPressed: state.page > 1 ? () => notifier.setPage(state.page - 1) : null,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            '${state.page}/${state.totalPages > 0 ? state.totalPages : 1}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                          splashRadius: 14,
                          tooltip: 'Next Page',
                          onPressed: (state.totalPages > 0 && state.page < state.totalPages)
                              ? () => notifier.setPage(state.page + 1)
                              : null,
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 2. RIGHT DETAIL PANEL: HEADER CARD + STATS + SECTIONS + SUBJECTS TABLES
  // =========================================================================
  Widget _buildClassDetailPanel(
    BuildContext context,
    ClassState state,
    ClassNotifier notifier,
    AcademicClassModel cls,
    AcademicClassDetailModel? detail,
    bool isTeacher,
    bool isDark,
  ) {
    final badgeColor = _getClassBadgeColor(cls.name);
    final gradeNum = _getClassGradeNumber(cls.name);

    final secCount = detail?.totalSections ?? cls.sectionsCount;
    final stuCount = detail?.totalStudents ?? cls.studentsCount;
    final capCount = detail?.totalCapacity ?? (detail?.sections.fold<int>(0, (sum, s) => sum + s.capacity) ?? (cls.sections.fold<int>(0, (sum, s) => sum + s.capacity)));
    final coreCount = detail?.coreSubjectsCount ?? (detail?.subjects.where((s) => s.isCore).length ?? 0);
    final optCount = detail?.optionalSubjectsCount ?? (detail?.subjects.where((s) => s.isOptional).length ?? 0);
    final totalSubs = detail?.totalSubjectsCount ?? (detail?.subjects.isNotEmpty == true ? detail!.subjects.length : cls.subjectsCount);
    final capPct = capCount > 0 ? ((stuCount / capCount) * 100).clamp(0.0, 100.0) : 0.0;

    final clsStatus = (detail?.status.isNotEmpty == true ? detail!.status : cls.status).trim();
    final isClsActive = clsStatus.toUpperCase() == 'ACTIVE';
    final isClsInactive = clsStatus.toUpperCase() == 'INACTIVE';
    final isClsArchived = clsStatus.toUpperCase() == 'ARCHIVED';
    final clsStatusColor = isClsActive
        ? const Color(0xFF10B981)
        : (isClsInactive
            ? const Color(0xFFEF4444)
            : (isClsArchived ? const Color(0xFFF59E0B) : const Color(0xFF64748B)));
    final displayClsStatus = clsStatus.isNotEmpty
        ? (clsStatus[0].toUpperCase() + clsStatus.substring(1).toLowerCase())
        : 'Active';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. CLASS HEADER SUMMARY CARD
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // Big Grade Badge
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          gradeNum,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: badgeColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                cls.name,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: clsStatusColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  displayClsStatus,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: clsStatusColor),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${cls.stage}  •  Class Code: ${cls.code}  •  Academic Year: ${cls.academicYear}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Actions
                  if (!isTeacher)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _showEditClassDialog(context, cls, state, notifier),
                          icon: const Icon(Icons.edit_outlined, size: 14),
                          label: const Text('Edit Class'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 18),
                          onSelected: (val) {
                            if (val == 'archive') {
                              _showArchiveClassDialog(context, cls, notifier);
                            } else if (val == 'restore') {
                              notifier.restoreClass(cls.id);
                            }
                          },
                          itemBuilder: (ctx) => [
                            if (isClsArchived)
                              const PopupMenuItem(
                                value: 'restore',
                                child: Row(
                                  children: [
                                    Icon(Icons.restore, size: 16, color: Color(0xFF10B981)),
                                    SizedBox(width: 8),
                                    Text('Restore Class', style: TextStyle(color: Color(0xFF10B981))),
                                  ],
                                ),
                              )
                            else
                              const PopupMenuItem(
                                value: 'archive',
                                child: Row(
                                  children: [
                                    Icon(Icons.archive_outlined, size: 16, color: Color(0xFFEF4444)),
                                    SizedBox(width: 8),
                                    Text('Archive Class', style: TextStyle(color: Color(0xFFEF4444))),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 18),

              // 4 KPI SUMMARY BOXES
              LayoutBuilder(
                builder: (context, boxConstraints) {
                  final kpiCards = [
                    _buildSummaryKpiTile(
                      icon: Icons.meeting_room_outlined,
                      title: '$secCount',
                      subtitle: 'Sections',
                      color: const Color(0xFF8B5CF6),
                      isDark: isDark,
                    ),
                    _buildSummaryKpiTile(
                      icon: Icons.people_alt_outlined,
                      title: '$stuCount',
                      subtitle: 'Students',
                      color: const Color(0xFF3B82F6),
                      isDark: isDark,
                    ),
                    _buildSummaryKpiTile(
                      icon: Icons.menu_book_rounded,
                      title: '$totalSubs',
                      subtitle: 'Subjects',
                      color: const Color(0xFF8B5CF6),
                      isDark: isDark,
                    ),
                    _buildCapacityKpiTile(
                      current: stuCount,
                      total: capCount,
                      percentage: capPct,
                      isDark: isDark,
                    ),
                  ];

                  if (boxConstraints.maxWidth < 750) {
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: kpiCards.map((c) => SizedBox(width: (boxConstraints.maxWidth - 24) / 2, child: c)).toList(),
                    );
                  }

                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: kpiCards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: c))).toList(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 2. SECTIONS IN THIS CLASS TABLE
        _buildSectionsInClassCard(context, state, notifier, cls, detail, isTeacher, isDark),
        const SizedBox(height: 20),

        // 3. SUBJECTS OF THIS CLASS TABLE
        _buildSubjectsInClassCard(context, state, notifier, cls, detail, isTeacher, isDark),
      ],
    );
  }

  Widget _buildSummaryKpiTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapacityKpiTile({
    required int current,
    required int total,
    required double percentage,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: (percentage / 100).clamp(0.0, 1.0),
                  backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                  strokeWidth: 3.5,
                ),
                Center(
                  child: Text(
                    '${percentage.round()}%',
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF10B981)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$current / $total',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'Capacity',
                  style: TextStyle(
                    fontSize: 10.5,
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

  // =========================================================================
  // 3. SECTIONS IN THIS CLASS TABLE
  // =========================================================================
  Widget _buildSectionsInClassCard(
    BuildContext context,
    ClassState state,
    ClassNotifier notifier,
    AcademicClassModel cls,
    AcademicClassDetailModel? detail,
    bool isTeacher,
    bool isDark,
  ) {
    final sections = (detail != null && detail.sections.isNotEmpty)
        ? detail.sections
        : cls.sections;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sections in this Class',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Table
          LayoutBuilder(
            builder: (context, constraints) {
              final tableWidth = constraints.maxWidth < 850 ? 850.0 : constraints.maxWidth;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: tableWidth),
                  child: DataTable(
                    showCheckboxColumn: false,
                    headingRowColor: MaterialStateProperty.all(
                      isDark ? const Color(0xFF0F172A).withOpacity(0.5) : const Color(0xFFF8FAFC),
                    ),
                    headingTextStyle: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                    ),
                    dataRowMinHeight: 52,
                    dataRowMaxHeight: 56,
                    horizontalMargin: 20,
                    columnSpacing: 18,
                    columns: const [
                      DataColumn(label: Text('Section Name')),
                      DataColumn(label: Text('Section Code')),
                      DataColumn(label: Text('Students')),
                      DataColumn(label: Text('Capacity')),
                      DataColumn(label: Text('Class Teacher')),
                      DataColumn(label: Text('Status')),
                    ],
                    rows: sections.map((sec) {
                      final teacherName = sec.classTeacher?.fullName ?? 'Unassigned';
                      final teacherSub = sec.classTeacher?.department ?? 'Section Teacher';

                      return DataRow(
                        cells: [
                          // Section Name
                          DataCell(
                            Text(
                              sec.name,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ),

                          // Section Code
                          DataCell(
                            Text(
                              sec.code,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                              ),
                            ),
                          ),

                          // Students
                          DataCell(
                            Text(
                              '${sec.studentsCount}',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ),

                          // Capacity
                          DataCell(
                            Text(
                              '${sec.capacity}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                              ),
                            ),
                          ),

                          // Class Teacher with Avatar
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: const Color(0xFF4F46E5).withOpacity(0.12),
                                  child: Text(
                                    teacherName.isNotEmpty ? teacherName[0] : 'T',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 140),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        teacherName,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        teacherSub,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Status Pill
                          DataCell(
                            Builder(
                              builder: (context) {
                                final isClassInactive = (detail?.status.isNotEmpty == true ? detail!.status : cls.status).trim().toUpperCase() == 'INACTIVE';
                                final isSecActive = !isClassInactive && sec.status.toUpperCase() == 'ACTIVE';
                                final isSecInactive = isClassInactive || sec.status.toUpperCase() == 'INACTIVE';
                                final statusColor = isSecActive
                                    ? const Color(0xFF10B981)
                                    : (isSecInactive ? const Color(0xFFEF4444) : const Color(0xFFF59E0B));
                                final statusText = isSecActive ? 'Active' : (isSecInactive ? 'Inactive' : sec.status);

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: statusColor,
                                    ),
                                  ),
                                );
                              },
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

          // Footer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: InkWell(
              onTap: () => notifier.setActiveTab(1),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View all sections',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF4F46E5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 4. SUBJECTS OF THIS CLASS TABLE
  // =========================================================================
  Widget _buildSubjectsInClassCard(
    BuildContext context,
    ClassState state,
    ClassNotifier notifier,
    AcademicClassModel cls,
    AcademicClassDetailModel? detail,
    bool isTeacher,
    bool isDark,
  ) {
    final subjects = (detail != null && detail.subjects.isNotEmpty)
        ? detail.subjects
        : const <ClassSubjectDetailModel>[];

    final coreCount = detail?.coreSubjectsCount ?? subjects.where((s) => s.isCore).length;
    final optCount = detail?.optionalSubjectsCount ?? subjects.where((s) => s.isOptional).length;
    final totalCount = detail?.totalSubjectsCount ?? subjects.length;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Text(
                  'Subjects of ${cls.name}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 14),
                _buildLegendDot('Core: $coreCount', const Color(0xFF10B981), isDark),
                const SizedBox(width: 10),
                _buildLegendDot('Optional: $optCount', const Color(0xFFF59E0B), isDark),
                const SizedBox(width: 10),
                _buildLegendDot('Total: $totalCount', const Color(0xFF4F46E5), isDark),
              ],
            ),
          ),
          const Divider(height: 1),

          // Table
          if (subjects.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.auto_stories_outlined, size: 36, color: isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1)),
                    const SizedBox(height: 8),
                    Text(
                      'No subjects assigned to ${cls.name} yet.',
                      style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final tableWidth = constraints.maxWidth < 750 ? 750.0 : constraints.maxWidth;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: tableWidth),
                    child: DataTable(
                      showCheckboxColumn: false,
                      headingRowColor: WidgetStateProperty.all(
                        isDark ? const Color(0xFF0F172A).withOpacity(0.5) : const Color(0xFFF8FAFC),
                      ),
                      headingTextStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                      ),
                      dataRowMinHeight: 52,
                      dataRowMaxHeight: 56,
                      horizontalMargin: 20,
                      columnSpacing: 18,
                      columns: const [
                        DataColumn(label: Text('Subject Name')),
                        DataColumn(label: Text('Subject Code')),
                        DataColumn(label: Text('Type')),
                        DataColumn(label: Text('Offered As')),
                        DataColumn(label: Text('Assigned Teachers by Section ⓘ')),
                        DataColumn(label: Text('Status')),
                      ],
                      rows: subjects.map((sub) {
                        final isCore = sub.isCore;
                        final typeColor = isCore ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

                        return DataRow(
                          cells: [
                            // Subject Name
                            DataCell(
                              Text(
                                sub.name,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ),

                            // Subject Code
                            DataCell(
                              Text(
                                sub.code,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                ),
                              ),
                            ),

                            // Type Pill
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: typeColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  sub.type,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: typeColor,
                                  ),
                                ),
                              ),
                            ),

                            // Offered As
                            DataCell(
                              Text(
                                sub.offeredAs,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                ),
                              ),
                            ),

                            // Assigned Teachers by Section (Avatar Stack with Live Data & Popup)
                            DataCell(
                              Builder(
                                builder: (context) {
                                  final teachers = sub.assignedTeachers;
                                  final assignedSecCount = sub.assignedSectionsCount > 0 ? sub.assignedSectionsCount : teachers.length;

                                  if (teachers.isEmpty) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                      ),
                                      child: Text(
                                        'Unassigned',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    );
                                  }

                                  return PopupMenuButton<void>(
                                    tooltip: 'View Assigned Teachers',
                                    padding: EdgeInsets.zero,
                                    itemBuilder: (ctx) => [
                                      PopupMenuItem<void>(
                                        enabled: false,
                                        child: Text(
                                          'Teachers for ${sub.name}:',
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                                        ),
                                      ),
                                      const PopupMenuDivider(),
                                      ...teachers.map(
                                        (t) => PopupMenuItem<void>(
                                          enabled: false,
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 12,
                                                backgroundColor: const Color(0xFF4F46E5).withOpacity(0.15),
                                                backgroundImage: (t.avatarUrl != null && t.avatarUrl!.isNotEmpty)
                                                    ? NetworkImage(t.avatarUrl!)
                                                    : null,
                                                child: (t.avatarUrl == null || t.avatarUrl!.isEmpty)
                                                    ? Text(
                                                        t.fullName.isNotEmpty ? t.fullName.substring(0, 1).toUpperCase() : 'T',
                                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
                                                      )
                                                    : null,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(t.fullName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                                    Text(
                                                      'Section: ${t.sectionName ?? "All Sections"}',
                                                      style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: teachers.length > 1 ? 42 : 24,
                                          height: 24,
                                          child: Stack(
                                            children: [
                                              Positioned(
                                                left: 0,
                                                child: CircleAvatar(
                                                  radius: 11,
                                                  backgroundColor: const Color(0xFF4F46E5).withOpacity(0.2),
                                                  backgroundImage: (teachers.first.avatarUrl != null && teachers.first.avatarUrl!.isNotEmpty)
                                                      ? NetworkImage(teachers.first.avatarUrl!)
                                                      : null,
                                                  child: (teachers.first.avatarUrl == null || teachers.first.avatarUrl!.isEmpty)
                                                      ? Text(
                                                          teachers.first.fullName.isNotEmpty ? teachers.first.fullName.substring(0, 1).toUpperCase() : 'T',
                                                          style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
                                                        )
                                                      : null,
                                                ),
                                              ),
                                              if (teachers.length > 1)
                                                Positioned(
                                                  left: 14,
                                                  child: CircleAvatar(
                                                    radius: 11,
                                                    backgroundColor: const Color(0xFF10B981).withOpacity(0.2),
                                                    backgroundImage: (teachers[1].avatarUrl != null && teachers[1].avatarUrl!.isNotEmpty)
                                                        ? NetworkImage(teachers[1].avatarUrl!)
                                                        : null,
                                                    child: (teachers[1].avatarUrl == null || teachers[1].avatarUrl!.isEmpty)
                                                        ? Text(
                                                            teachers[1].fullName.isNotEmpty ? teachers[1].fullName.substring(0, 1).toUpperCase() : 'T',
                                                            style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
                                                          )
                                                        : null,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '$assignedSecCount ${assignedSecCount == 1 ? "Section" : "Sections"}',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                                                ),
                                              ),
                                              const Icon(Icons.arrow_drop_down, size: 14),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),

                            // Status Pill
                            DataCell(
                              Builder(
                                builder: (context) {
                                  final isClassInactive = (detail?.status.isNotEmpty == true ? detail!.status : cls.status).trim().toUpperCase() == 'INACTIVE';
                                  final isSubActive = !isClassInactive && sub.status.toUpperCase() == 'ACTIVE';
                                  final isSubInactive = isClassInactive || sub.status.toUpperCase() == 'INACTIVE';
                                  final statusColor = isSubActive
                                      ? const Color(0xFF10B981)
                                      : (isSubInactive ? const Color(0xFFEF4444) : const Color(0xFFF59E0B));
                                  final statusText = isSubActive ? 'Active' : (isSubInactive ? 'Inactive' : sub.status);

                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      statusText,
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                                    ),
                                  );
                                },
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

          // Footer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: InkWell(
              onTap: () => notifier.setActiveTab(2),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View all subjects',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF4F46E5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(String label, Color color, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildEmptySelectionPlaceholder(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.class_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              'Select a class from the list to view its details, sections, and subjects.',
              style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 5. DIALOG LAUNCHERS
  // =========================================================================
  void _showEditClassDialog(BuildContext context, AcademicClassModel cls, ClassState state, ClassNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => CreateEditClassDialog(
        classToEdit: cls,
        onSave: (payload) => notifier.updateClass(
          cls.id,
          name: payload['name'],
          code: payload['code'],
          stage: payload['stage'],
          academicYear: payload['academic_year'],
          status: payload['status'],
        ),
      ),
    );
  }

  void _showArchiveClassDialog(BuildContext context, AcademicClassModel cls, ClassNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => ArchiveConfirmationDialog(
        title: 'Archive Class',
        itemName: '${cls.name} (${cls.code})',
        impactDetails: {
          'Sections Linked': cls.sectionsCount,
          'Students Linked': cls.studentsCount,
        },
        onConfirm: (force) => notifier.archiveClass(cls.id, force: force),
      ),
    );
  }
}
