import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/role_provider.dart';
import '../../../providers/auth_provider.dart';
import '../models/class_models.dart';
import '../providers/class_provider.dart';
import '../services/academic_lookup_helper.dart';
import 'dialogs/create_edit_subject_dialog.dart';
import 'dialogs/archive_confirmation_dialog.dart';
import 'dialogs/assign_subject_teacher_dialog.dart';
import 'dialogs/optional_subject_enrollment_dialog.dart';
import 'dialogs/assign_subject_to_section_dialog.dart';
import 'dialogs/csv_import_export_dialog.dart';

class SubjectsTabView extends ConsumerStatefulWidget {
  const SubjectsTabView({super.key});

  @override
  ConsumerState<SubjectsTabView> createState() => _SubjectsTabViewState();
}

class _SubjectsTabViewState extends ConsumerState<SubjectsTabView> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedClassFilter = 'ALL';
  String _selectedTypeFilter = 'ALL';
  String _selectedStatusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    final state = ref.read(classProvider);
    _searchController.text = state.subjectSearchQuery;
    _selectedTypeFilter = state.subjectTypeFilter;
    _selectedClassFilter = state.subjectClassIdFilter ?? 'ALL';
    _selectedStatusFilter = state.subjectStatusFilter;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = ref.read(classProvider);
      if (s.allClasses.isEmpty) {
        ref.read(classProvider.notifier).fetchAllClasses();
      }
      if (s.subjects.isNotEmpty && s.selectedSubject == null) {
        ref.read(classProvider.notifier).selectSubject(s.subjects.first);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getTypeColor(String type) {
    final t = type.toLowerCase();
    if (t.contains('core')) {
      return const Color(0xFF10B981); // Emerald Green
    } else if (t.contains('elec') || t.contains('opt')) {
      return const Color(0xFFF59E0B); // Amber / Orange
    } else if (t.contains('prac') || t.contains('lab')) {
      return const Color(0xFF06B6D4); // Cyan
    } else if (t.contains('lang')) {
      return const Color(0xFF3B82F6); // Blue
    } else if (t.contains('act') || t.contains('sport') || t.contains('art')) {
      return const Color(0xFFEC4899); // Pink
    }
    return const Color(0xFF8B5CF6); // Purple
  }

  IconData _getTypeIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('core')) {
      return Icons.auto_stories_rounded;
    } else if (t.contains('elec') || t.contains('opt')) {
      return Icons.palette_rounded;
    } else if (t.contains('prac') || t.contains('lab')) {
      return Icons.science_rounded;
    } else if (t.contains('lang')) {
      return Icons.translate_rounded;
    } else if (t.contains('act') || t.contains('sport') || t.contains('art')) {
      return Icons.sports_tennis_rounded;
    }
    return Icons.menu_book_rounded;
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. TOP KPI STATS DASHBOARD (5 Cards)
          _buildKpiStatsRow(context, state, isDark),
          const SizedBox(height: 20),

          // 2. MULTI-FILTER TOOLBAR
          _buildFilterToolbar(context, state, notifier, isDark),
          const SizedBox(height: 20),

          // 3. MAIN SPLIT BODY (Left: Subjects List + Bottom Offerings Grid, Right: Analytics & Quick Actions)
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 1180;

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSubjectsListCard(context, state, notifier, isTeacher, isDark),
                    const SizedBox(height: 24),
                    _buildSubjectSectionMappingCard(context, state, notifier, isTeacher, isDark),
                    const SizedBox(height: 24),
                    _buildAnalyticsAndActionsColumn(context, state, notifier, isDark),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Primary Column (72%)
                  Expanded(
                    flex: 72,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSubjectsListCard(context, state, notifier, isTeacher, isDark),
                        const SizedBox(height: 24),
                        _buildSubjectSectionMappingCard(context, state, notifier, isTeacher, isDark),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),

                  // Right Analytics & Actions Column (28%)
                  Expanded(
                    flex: 28,
                    child: _buildAnalyticsAndActionsColumn(context, state, notifier, isDark),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 1. KPI STATS ROW (5 CARDS)
  // =========================================================================
  Widget _buildKpiStatsRow(BuildContext context, ClassState state, bool isDark) {
    final stats = state.stats;
    final allSubjects = state.subjects;
    final totalCount = stats.totalSubjects > 0
        ? stats.totalSubjects
        : (state.totalCount > 0 ? state.totalCount : allSubjects.length);

    int coreCount = stats.coreSubjects;
    int electiveCount = stats.electiveSubjects;
    int practicalCount = stats.practicalSubjects;
    int inactiveCount = stats.inactiveSubjects;

    // Fallbacks if stats not loaded yet
    if (coreCount == 0 && electiveCount == 0 && practicalCount == 0 && allSubjects.isNotEmpty) {
      coreCount = allSubjects.where((s) => s.isCore).length;
      electiveCount = allSubjects.where((s) => s.isElective).length;
      practicalCount = allSubjects.where((s) => s.isPractical).length;
      inactiveCount = allSubjects.where((s) => !s.isActive).length;

      if (totalCount > allSubjects.length && allSubjects.isNotEmpty) {
        final ratio = totalCount / allSubjects.length;
        coreCount = (coreCount * ratio).round();
        electiveCount = (electiveCount * ratio).round();
        practicalCount = (practicalCount * ratio).round();
        inactiveCount = (inactiveCount * ratio).round();
      }
    }

    final corePct = totalCount > 0 ? ((coreCount / totalCount) * 100).toStringAsFixed(1) : '0.0';
    final electivePct = totalCount > 0 ? ((electiveCount / totalCount) * 100).toStringAsFixed(1) : '0.0';
    final practicalPct = totalCount > 0 ? ((practicalCount / totalCount) * 100).toStringAsFixed(1) : '0.0';
    final inactivePct = totalCount > 0 ? ((inactiveCount / totalCount) * 100).toStringAsFixed(1) : '0.0';

    final cards = [
      _buildKpiCard(
        title: 'Total Subjects',
        value: '$totalCount',
        subtitle: 'All subjects in school',
        icon: Icons.menu_book_rounded,
        color: const Color(0xFF4F46E5),
        isDark: isDark,
      ),
      _buildKpiCard(
        title: 'Core Subjects',
        value: '$coreCount',
        subtitle: '$corePct% of total',
        icon: Icons.auto_stories_rounded,
        color: const Color(0xFF10B981),
        isDark: isDark,
      ),
      _buildKpiCard(
        title: 'Elective Subjects',
        value: '$electiveCount',
        subtitle: '$electivePct% of total',
        icon: Icons.palette_rounded,
        color: const Color(0xFFF59E0B),
        isDark: isDark,
      ),
      _buildKpiCard(
        title: 'Practical Subjects',
        value: '$practicalCount',
        subtitle: '$practicalPct% of total',
        icon: Icons.science_rounded,
        color: const Color(0xFF06B6D4),
        isDark: isDark,
      ),
      _buildKpiCard(
        title: 'Inactive Subjects',
        value: '$inactiveCount',
        subtitle: '$inactivePct% of total',
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFEF4444),
        isDark: isDark,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 750) {
          return Column(
            children: [
              Row(children: [Expanded(child: cards[0]), const SizedBox(width: 12), Expanded(child: cards[1])]),
              const SizedBox(height: 12),
              Row(children: [Expanded(child: cards[2]), const SizedBox(width: 12), Expanded(child: cards[3])]),
              const SizedBox(height: 12),
              cards[4],
            ],
          );
        }
        if (constraints.maxWidth < 1100) {
          return Column(
            children: [
              Row(children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 12),
                Expanded(child: cards[1]),
                const SizedBox(width: 12),
                Expanded(child: cards[2]),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: cards[3]),
                const SizedBox(width: 12),
                Expanded(child: cards[4]),
              ]),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 14),
            Expanded(child: cards[1]),
            const SizedBox(width: 14),
            Expanded(child: cards[2]),
            const SizedBox(width: 14),
            Expanded(child: cards[3]),
            const SizedBox(width: 14),
            Expanded(child: cards[4]),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
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
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 2. MULTI-FILTER TOOLBAR
  // =========================================================================
  Widget _buildFilterToolbar(BuildContext context, ClassState state, ClassNotifier notifier, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 900;

          final searchInput = TextField(
            controller: _searchController,
            onSubmitted: (v) => notifier.applySubjectFilters(
              search: v.trim(),
              type: _selectedTypeFilter,
              status: _selectedStatusFilter,
              classId: _selectedClassFilter == 'ALL' ? null : _selectedClassFilter,
            ),
            decoration: InputDecoration(
              hintText: 'Search subjects by name or code...',
              hintStyle: TextStyle(
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                fontSize: 13,
              ),
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        notifier.applySubjectFilters(
                          search: '',
                          type: _selectedTypeFilter,
                          status: _selectedStatusFilter,
                          classId: _selectedClassFilter == 'ALL' ? null : _selectedClassFilter,
                        );
                      },
                    )
                  : null,
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              ),
            ),
            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
          );

          final activeTypes = AcademicLookupHelper.instance.getCachedLookup('SUBJECT_TYPE');
          final activeStatuses = AcademicLookupHelper.instance.getCachedLookup('ACADEMIC_STATUS');
          final typeItems = ['ALL', ...activeTypes.map((t) => t.label)];
          final statusItems = ['ALL', ...activeStatuses.map((s) => s.code)];

          final typeDropdown = Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: typeItems.contains(_selectedTypeFilter) ? _selectedTypeFilter : 'ALL',
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                items: [
                  const DropdownMenuItem(value: 'ALL', child: Text('Subject Type: All Types')),
                  ...activeTypes.map((t) => DropdownMenuItem(value: t.label, child: Text(t.label))),
                ],
                onChanged: (v) => setState(() => _selectedTypeFilter = v ?? 'ALL'),
              ),
            ),
          );

          final classDropdown = Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: (_selectedClassFilter == 'ALL' || state.availableClasses.any((c) => c.id == _selectedClassFilter))
                    ? _selectedClassFilter
                    : 'ALL',
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                items: [
                  const DropdownMenuItem(value: 'ALL', child: Text('Class: All Classes')),
                  ...state.availableClasses.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                ],
                onChanged: (v) => setState(() => _selectedClassFilter = v ?? 'ALL'),
              ),
            ),
          );

          final statusDropdown = Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: statusItems.contains(_selectedStatusFilter) ? _selectedStatusFilter : 'ALL',
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                items: [
                  const DropdownMenuItem(value: 'ALL', child: Text('Status: All Status')),
                  ...activeStatuses.map((s) => DropdownMenuItem(value: s.code, child: Text(s.label))),
                ],
                onChanged: (v) => setState(() => _selectedStatusFilter = v ?? 'ALL'),
              ),
            ),
          );

          final actionButtons = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _selectedTypeFilter = 'ALL';
                    _selectedClassFilter = 'ALL';
                    _selectedStatusFilter = 'ALL';
                  });
                  notifier.clearSubjectFilters();
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Clear', style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF475569))),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () {
                  notifier.applySubjectFilters(
                    search: _searchController.text.trim(),
                    type: _selectedTypeFilter,
                    status: _selectedStatusFilter,
                    classId: _selectedClassFilter == 'ALL' ? null : _selectedClassFilter,
                  );
                },
                icon: const Icon(Icons.filter_alt_rounded, size: 16),
                label: const Text('Apply Filters'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchInput,
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    typeDropdown,
                    classDropdown,
                    statusDropdown,
                    actionButtons,
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 3, child: searchInput),
              const SizedBox(width: 12),
              typeDropdown,
              const SizedBox(width: 12),
              classDropdown,
              const SizedBox(width: 12),
              statusDropdown,
              const SizedBox(width: 12),
              actionButtons,
            ],
          );
        },
      ),
    );
  }

  // =========================================================================
  // 3. TOP CARD: SUBJECTS LIST TABLE
  // =========================================================================
  Widget _buildSubjectsListCard(
    BuildContext context,
    ClassState state,
    ClassNotifier notifier,
    bool isTeacher,
    bool isDark,
  ) {
    final subjects = state.subjects;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
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
                Row(
                  children: [
                    Text(
                      'Subjects List',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Click any row to view and manage class & section offerings in the bottom panel.',
                      child: Icon(Icons.info_outline, size: 16, color: isDark ? Colors.white54 : Colors.black45),
                    ),
                  ],
                ),
                if (!isTeacher)
                  ElevatedButton.icon(
                    onPressed: () => _showCreateEditSubjectDialog(context, null, state, notifier),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add Subject'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Data Grid
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
                      'No subjects found matching the filter criteria.',
                      style: TextStyle(fontSize: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final tableWidth = constraints.maxWidth < 1050 ? 1050.0 : constraints.maxWidth;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: tableWidth),
                    child: DataTable(
                      showCheckboxColumn: false,
                      headingRowColor: MaterialStateProperty.all(
                        isDark ? const Color(0xFF0F172A).withOpacity(0.6) : const Color(0xFFF8FAFC),
                      ),
                      headingTextStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                      ),
                      dataRowMinHeight: 56,
                      dataRowMaxHeight: 62,
                      horizontalMargin: 20,
                      columnSpacing: 18,
                      columns: [
                        const DataColumn(label: Text('SUBJECT NAME')),
                        const DataColumn(label: Text('SUBJECT CODE')),
                        const DataColumn(label: Text('TYPE')),
                        const DataColumn(label: Text('CLASSES')),
                        const DataColumn(label: Text('ASSIGNED SECTIONS')),
                        const DataColumn(label: Text('TEACHERS')),
                        const DataColumn(label: Text('REQUIREMENT')),
                        const DataColumn(label: Text('STATUS')),
                        const DataColumn(label: Text('LAST UPDATED')),
                        if (!isTeacher) const DataColumn(label: Text('ACTIONS')),
                      ],
                      rows: subjects.map((sub) {
                        final isSelected = state.selectedSubject?.id == sub.id;

                        final typeColor = _getTypeColor(sub.type);
                        final isActive = sub.status.toUpperCase() == 'ACTIVE';

                        final classesText = sub.classesCount > 0 ? '${sub.classesCount} Classes' : '0 Classes';
                        final sectionsText = sub.sectionsCount > 0 ? '${sub.sectionsCount} Sections' : '0 Sections';
                        final teachersText = '${sub.teachersCount} Teachers';

                        final updatedDateStr = sub.updatedAt != null
                            ? '${sub.updatedAt!.day} ${_getMonthName(sub.updatedAt!.month)} ${sub.updatedAt!.year}'
                            : '16 Aug 2026';

                        final isOpt = sub.isElectiveOrOptional;

                        return DataRow(
                          selected: isSelected,
                          onSelectChanged: (_) => notifier.selectSubject(sub),
                          color: MaterialStateProperty.resolveWith((states) {
                            if (isSelected) {
                              return const Color(0xFF4F46E5).withOpacity(0.08);
                            }
                            return null;
                          }),
                          cells: [
                            // Subject Name with Icon
                            DataCell(
                              Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: sub.subjectColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(_getTypeIcon(sub.type), color: sub.subjectColor, size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    sub.name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Code
                            DataCell(
                              Text(
                                sub.code,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                ),
                              ),
                            ),

                            // Type Pill
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: typeColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: typeColor.withOpacity(0.3)),
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

                            // Classes
                            DataCell(
                              Text(
                                classesText,
                                style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                              ),
                            ),

                            // Assigned Sections
                            DataCell(
                              Text(
                                sectionsText,
                                style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                              ),
                            ),

                            // Teachers
                            DataCell(
                              Text(
                                teachersText,
                                style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                              ),
                            ),

                            // Requirement (Mandatory / Optional)
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isOpt
                                      ? const Color(0xFFF59E0B).withOpacity(0.12)
                                      : const Color(0xFF10B981).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isOpt
                                        ? const Color(0xFFF59E0B).withOpacity(0.3)
                                        : const Color(0xFF10B981).withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isOpt ? Icons.tune_rounded : Icons.check_circle_rounded,
                                      size: 11,
                                      color: isOpt ? const Color(0xFFD97706) : const Color(0xFF059669),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isOpt ? 'Optional' : 'Mandatory',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isOpt ? const Color(0xFFD97706) : const Color(0xFF059669),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Status Pill
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isActive ? Icons.check_rounded : Icons.close_rounded,
                                      size: 12,
                                      color: isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isActive ? 'Active' : 'Inactive',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Last Updated
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    updatedDateStr,
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                  ),
                                  Text(
                                    'by Administrator',
                                    style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),

                            // Actions
                            if (!isTeacher)
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 16),
                                      tooltip: 'Edit Subject',
                                      onPressed: () => _showCreateEditSubjectDialog(context, sub, state, notifier),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                    ),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert, size: 16),
                                      tooltip: 'More actions',
                                      onSelected: (val) {
                                        if (val == 'edit') {
                                          _showCreateEditSubjectDialog(context, sub, state, notifier);
                                        } else if (val == 'assign_section') {
                                          _showAssignSubjectToSectionDialog(context, sub, state, notifier);
                                        } else if (val == 'assign_teacher') {
                                          _showAssignTeacherDialog(context, sub, state, notifier);
                                        } else if (val == 'archive') {
                                          _showArchiveDialog(context, sub, notifier);
                                        } else if (val == 'restore') {
                                          notifier.restoreSubject(sub.id);
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(children: [Icon(Icons.edit_outlined, size: 16), SizedBox(width: 8), Text('Edit Subject')]),
                                        ),
                                        const PopupMenuItem(
                                          value: 'assign_section',
                                          child: Row(children: [Icon(Icons.add_task_rounded, size: 16, color: Color(0xFF4F46E5)), SizedBox(width: 8), Text('Assign to Class/Section')]),
                                        ),
                                        const PopupMenuItem(
                                          value: 'assign_teacher',
                                          child: Row(children: [Icon(Icons.person_add_alt_1_outlined, size: 16, color: Color(0xFF4F46E5)), SizedBox(width: 8), Text('Assign Faculty')]),
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
          _buildPaginationBar(context, state, notifier, isDark),
        ],
      ),
    );
  }

  // =========================================================================
  // 4. BOTTOM CARD: SUBJECT-CLASS-SECTION MAPPING GRID
  // =========================================================================
  Widget _buildSubjectSectionMappingCard(
    BuildContext context,
    ClassState state,
    ClassNotifier notifier,
    bool isTeacher,
    bool isDark,
  ) {
    final selectedSub = state.selectedSubject;
    final mappings = state.subjectMappings;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Title + Assign Button + Subject Switcher
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              selectedSub != null
                                  ? 'Class & Section Offerings • ${selectedSub.name}'
                                  : 'Subject–Class–Section Offerings',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          if (selectedSub != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: selectedSub.isElectiveOrOptional
                                    ? const Color(0xFFF59E0B).withOpacity(0.15)
                                    : const Color(0xFF10B981).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                selectedSub.isElectiveOrOptional ? 'Optional' : 'Mandatory',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: selectedSub.isElectiveOrOptional ? const Color(0xFFD97706) : const Color(0xFF059669),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Showing sections offering this subject with faculty assignments and student enrollments.',
                        style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Right Actions: "+ Assign to Section" button & Subject Selector Dropdown
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isTeacher && selectedSub != null) ...[
                      ElevatedButton.icon(
                        onPressed: () => _showAssignSubjectToSectionDialog(context, selectedSub, state, notifier),
                        icon: const Icon(Icons.add_task_rounded, size: 15),
                        label: const Text('Assign to Section'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (state.subjects.isNotEmpty) ...[
                      Text(
                        'Subject:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedSub != null && state.subjects.any((s) => s.id == selectedSub.id)
                                ? selectedSub.id
                                : state.subjects.first.id,
                            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                            items: state.subjects.map((s) {
                              return DropdownMenuItem(
                                value: s.id,
                                child: Text('${s.name} (${s.code})'),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) notifier.selectSubjectById(v);
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content / Offerings Table
          if (selectedSub == null)
            Padding(
              padding: const EdgeInsets.all(36),
              child: Center(
                child: Text('Select a subject from the list above to view section offerings.', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
              ),
            )
          else if (mappings.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.assignment_add, size: 32, color: Color(0xFF4F46E5)),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No sections currently assigned to ${selectedSub.name}.',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Assign this subject to class sections to configure faculty and student enrollments.',
                      style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),
                    if (!isTeacher)
                      ElevatedButton.icon(
                        onPressed: () => _showAssignSubjectToSectionDialog(context, selectedSub, state, notifier),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: Text('Assign ${selectedSub.name} to Class / Section'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final tableWidth = constraints.maxWidth < 1000 ? 1000.0 : constraints.maxWidth;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: tableWidth),
                    child: DataTable(
                      showCheckboxColumn: false,
                      headingRowColor: MaterialStateProperty.all(
                        isDark ? const Color(0xFF0F172A).withOpacity(0.6) : const Color(0xFFF8FAFC),
                      ),
                      headingTextStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                      ),
                      dataRowMinHeight: 58,
                      dataRowMaxHeight: 64,
                      horizontalMargin: 20,
                      columnSpacing: 18,
                      columns: [
                        const DataColumn(label: Text('CLASS')),
                        const DataColumn(label: Text('SECTION')),
                        const DataColumn(label: Text('ENROLLMENT MODE')),
                        const DataColumn(label: Text('STUDENTS ENROLLED')),
                        const DataColumn(label: Text('ASSIGNED TEACHER')),
                        const DataColumn(label: Text('STATUS')),
                        if (!isTeacher) const DataColumn(label: Text('ACTIONS')),
                      ],
                      rows: mappings.map((m) {
                        final teacher = m.assignedTeacher;
                        final isMandatory = !selectedSub.isElectiveOrOptional && !m.isOfferedAsOptional;
                        final enrolledCount = isMandatory ? m.totalCapacity : m.enrolledStudentsCount;
                        final capacity = m.totalCapacity > 0 ? m.totalCapacity : 0;
                        final isOffered = m.status.toUpperCase() == 'ACTIVE';

                        return DataRow(
                          cells: [
                            // Class Name
                            DataCell(
                              Text(
                                m.className,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ),

                            // Section Name
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4F46E5).withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  m.sectionName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF4F46E5),
                                  ),
                                ),
                              ),
                            ),

                            // Enrollment Mode Pill
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isMandatory
                                      ? const Color(0xFF10B981).withOpacity(0.12)
                                      : const Color(0xFFF59E0B).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isMandatory
                                        ? const Color(0xFF10B981).withOpacity(0.3)
                                        : const Color(0xFFF59E0B).withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  isMandatory ? 'Mandatory (Auto)' : 'Optional (Selective)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isMandatory ? const Color(0xFF059669) : const Color(0xFFD97706),
                                  ),
                                ),
                              ),
                            ),

                            // Students Enrolled Cell
                            DataCell(
                              isMandatory
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withOpacity(0.10),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.people_alt_rounded, size: 14, color: Color(0xFF059669)),
                                          const SizedBox(width: 6),
                                          Text(
                                            'All $capacity Students (Mandatory)',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                                          ),
                                        ],
                                      ),
                                    )
                                  : InkWell(
                                      onTap: () => _showStudentEnrollmentDialog(context, selectedSub, m, state),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF59E0B).withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.people_alt_rounded, size: 14, color: Color(0xFFD97706)),
                                            const SizedBox(width: 6),
                                            Text(
                                              '$enrolledCount / $capacity Enrolled',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFD97706)),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(Icons.edit_outlined, size: 12, color: Color(0xFFD97706)),
                                          ],
                                        ),
                                      ),
                                    ),
                            ),

                            // Assigned Teacher Cell
                            DataCell(
                              teacher != null
                                  ? InkWell(
                                      onTap: () => _showAssignTeacherForMappingDialog(context, selectedSub, m, state, notifier),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircleAvatar(
                                              radius: 14,
                                              backgroundColor: const Color(0xFF4F46E5).withOpacity(0.15),
                                              backgroundImage: teacher.avatarUrl != null ? NetworkImage(teacher.avatarUrl!) : null,
                                              child: teacher.avatarUrl == null
                                                  ? Text(
                                                      teacher.fullName.isNotEmpty ? teacher.fullName[0].toUpperCase() : 'T',
                                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
                                                    )
                                                  : null,
                                            ),
                                            const SizedBox(width: 8),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  teacher.fullName,
                                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                                ),
                                                Text(
                                                  teacher.department ?? 'Faculty',
                                                  style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(width: 6),
                                            Icon(Icons.edit_outlined, size: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                          ],
                                        ),
                                      ),
                                    )
                                  : OutlinedButton.icon(
                                      onPressed: () => _showAssignTeacherForMappingDialog(context, selectedSub, m, state, notifier),
                                      icon: const Icon(Icons.person_add_alt_1_outlined, size: 14),
                                      label: const Text('Assign Teacher', style: TextStyle(fontSize: 11.5)),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        minimumSize: Size.zero,
                                        side: const BorderSide(color: Color(0xFF4F46E5)),
                                        foregroundColor: const Color(0xFF4F46E5),
                                      ),
                                    ),
                            ),

                            // Status Pill
                            DataCell(
                              InkWell(
                                onTap: !isTeacher
                                    ? () => _handleToggleSubjectOfferingStatus(context, m, selectedSub, notifier)
                                    : null,
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (isOffered ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: (isOffered ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.25),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: isOffered ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        isOffered ? 'Active' : 'Inactive',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isOffered ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Actions
                            if (!isTeacher)
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Make Active / Inactive Action Button
                                    IconButton(
                                      icon: Icon(
                                        isOffered ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                                        size: 26,
                                        color: isOffered ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                                      ),
                                      tooltip: isOffered ? 'Mark as Inactive' : 'Mark as Active',
                                      onPressed: () => _handleToggleSubjectOfferingStatus(context, m, selectedSub, notifier),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                    ),
                                    if (!isMandatory) ...[
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(Icons.group_outlined, size: 16),
                                        tooltip: 'Manage Enrolled Students',
                                        onPressed: () => _showStudentEnrollmentDialog(context, selectedSub, m, state),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                      ),
                                    ],
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.link_off_rounded, size: 16, color: Color(0xFFEF4444)),
                                      tooltip: 'Unassign from Section',
                                      onPressed: () => _confirmUnassignSubjectFromSection(context, selectedSub, m, notifier),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
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

  // =========================================================================
  // 5. RIGHT COLUMN: ANALYTICS & QUICK ACTIONS
  // =========================================================================
  Widget _buildAnalyticsAndActionsColumn(
    BuildContext context,
    ClassState state,
    ClassNotifier notifier,
    bool isDark,
  ) {
    return Column(
      children: [
        // Card 1: Subject Types (Donut Chart)
        _buildSubjectTypesDonutChartCard(state, isDark),
        const SizedBox(height: 20),

        // Card 2: Subjects by Class (Bar Chart)
        _buildSubjectsByClassBarChartCard(state, isDark),
        const SizedBox(height: 20),

        // Card 3: About Optional Subjects (Info Box)
        _buildAboutOptionalSubjectsCard(isDark),
      ],
    );
  }

  Widget _buildSubjectTypesDonutChartCard(ClassState state, bool isDark) {
    final stats = state.stats;
    final total = stats.totalSubjects > 0
        ? stats.totalSubjects
        : (state.totalCount > 0 ? state.totalCount : state.subjects.length);

    int core = stats.coreSubjects;
    int elective = stats.electiveSubjects;
    int practical = stats.practicalSubjects;
    int language = stats.languageSubjects;

    // Fallback if stats are not loaded yet
    if (core == 0 && elective == 0 && practical == 0 && language == 0 && state.subjects.isNotEmpty) {
      core = state.subjects.where((s) => s.isCore).length;
      elective = state.subjects.where((s) => s.isElective).length;
      practical = state.subjects.where((s) => s.isPractical).length;
      language = state.subjects.where((s) => s.isLanguage).length;
    }

    final corePct = total > 0 ? ((core / total) * 100).toStringAsFixed(2) : '0.00';
    final electivePct = total > 0 ? ((elective / total) * 100).toStringAsFixed(2) : '0.00';
    final practicalPct = total > 0 ? ((practical / total) * 100).toStringAsFixed(2) : '0.00';
    final languagePct = total > 0 ? ((language / total) * 100).toStringAsFixed(2) : '0.00';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Subject Types',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              // Custom Donut Chart
              SizedBox(
                width: 100,
                height: 100,
                child: CustomPaint(
                  painter: _DonutChartPainter(
                    slices: [
                      _ChartSlice(value: core.toDouble(), color: const Color(0xFF4F46E5)),
                      _ChartSlice(value: elective.toDouble(), color: const Color(0xFF10B981)),
                      _ChartSlice(value: practical.toDouble(), color: const Color(0xFF06B6D4)),
                      _ChartSlice(value: language.toDouble(), color: const Color(0xFFF59E0B)),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$total',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                        Text(
                          'Total',
                          style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),

              // Legend
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendRow('Core', '$core ($corePct%)', const Color(0xFF4F46E5), isDark),
                    const SizedBox(height: 6),
                    _buildLegendRow('Elective', '$elective ($electivePct%)', const Color(0xFF10B981), isDark),
                    const SizedBox(height: 6),
                    _buildLegendRow('Practical', '$practical ($practicalPct%)', const Color(0xFF06B6D4), isDark),
                    const SizedBox(height: 6),
                    _buildLegendRow('Language', '$language ($languagePct%)', const Color(0xFFF59E0B), isDark),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendRow(String label, String value, Color color, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569))),
          ],
        ),
        Text(value, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
      ],
    );
  }

  Widget _buildSubjectsByClassBarChartCard(ClassState state, bool isDark) {
    final stats = state.stats;
    List<Map<String, dynamic>> classItems = [];

    if (stats.subjectsByClass.isNotEmpty) {
      final withSubs = stats.subjectsByClass.where((c) => ((c['subjects_count'] as num?)?.toInt() ?? 0) > 0).toList();
      if (withSubs.length >= 4) {
        classItems = withSubs.take(6).toList();
      } else {
        classItems = stats.subjectsByClass.take(6).toList();
      }
    } else if (state.classes.isNotEmpty) {
      classItems = state.classes.take(6).map((c) => {
        'class_name': c.name,
        'subjects_count': c.subjectsCount,
      }).toList();
    }

    int maxVal = 1;
    for (final item in classItems) {
      final cnt = (item['subjects_count'] as num?)?.toInt() ?? 0;
      if (cnt > maxVal) maxVal = cnt;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Subjects by Class',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 18),
          if (classItems.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No classes configured',
                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                ),
              ),
            )
          else
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: classItems.map((c) {
                  final count = (c['subjects_count'] as num?)?.toInt() ?? 0;
                  final rawName = c['class_name']?.toString() ?? '';
                  final label = rawName.replaceAll('Class ', '').replaceAll('Grade-', 'G').replaceAll('Grade ', 'G').trim();
                  return _buildBarItem(label.length > 7 ? '${label.substring(0, 6)}…' : label, count, maxVal, isDark);
                }).toList(),
              ),
            ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Classes',
              style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarItem(String label, int value, int maxVal, bool isDark) {
    final heightRatio = maxVal > 0 ? (value / maxVal).clamp(0.05, 1.0) : 0.05;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '$value',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : const Color(0xFF475569)),
        ),
        const SizedBox(height: 4),
        Container(
          width: 18,
          height: (75 * heightRatio).clamp(4.0, 75.0),
          decoration: BoxDecoration(
            color: const Color(0xFF4F46E5),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
        ),
      ],
    );
  }



  Widget _buildAboutOptionalSubjectsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEEF2FF).withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_rounded, color: Color(0xFF4F46E5), size: 18),
              const SizedBox(width: 8),
              Text(
                'About Optional Subjects',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildBulletItem('Optional subjects are offered to students based on school rules.', isDark),
          _buildBulletItem('Students can enroll in one or more optional subjects (as applicable).', isDark),
          _buildBulletItem('Different sections of the same class may offer different optional subjects.', isDark),
          _buildBulletItem('Each subject can have different teachers for different sections.', isDark),
          const SizedBox(height: 10),
          InkWell(
            onTap: () {},
            child: const Text(
              'View Help',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF4F46E5),
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletItem(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_rounded, color: Color(0xFF4F46E5), size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 6. PAGINATION FOOTER
  // =========================================================================
  Widget _buildPaginationBar(BuildContext context, ClassState state, ClassNotifier notifier, bool isDark) {
    final startItem = state.totalCount == 0 ? 0 : (state.page - 1) * state.pageSize + 1;
    final endItem = (state.page * state.pageSize) > state.totalCount ? state.totalCount : (state.page * state.pageSize);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 650;

          final recordsInfo = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Showing $startItem - $endItem of ${state.totalCount} subjects',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Per page:',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: [10, 25, 50, 100].contains(state.pageSize) ? state.pageSize : 10,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        items: const [
                          DropdownMenuItem(value: 10, child: Text('10')),
                          DropdownMenuItem(value: 25, child: Text('25')),
                          DropdownMenuItem(value: 50, child: Text('50')),
                          DropdownMenuItem(value: 100, child: Text('100')),
                        ],
                        onChanged: (v) {
                          if (v != null) notifier.setPageSize(v);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );

          final pageNav = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: state.page > 1 ? () => notifier.setPage(1) : null,
                icon: const Icon(Icons.first_page, size: 18),
                tooltip: 'First Page',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                splashRadius: 16,
              ),
              IconButton(
                onPressed: state.page > 1 ? () => notifier.setPage(state.page - 1) : null,
                icon: const Icon(Icons.chevron_left, size: 20),
                tooltip: 'Previous Page',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                splashRadius: 16,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Page ${state.page} of ${state.totalPages > 0 ? state.totalPages : 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              IconButton(
                onPressed: state.page < state.totalPages ? () => notifier.setPage(state.page + 1) : null,
                icon: const Icon(Icons.chevron_right, size: 20),
                tooltip: 'Next Page',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                splashRadius: 16,
              ),
              IconButton(
                onPressed: state.page < state.totalPages ? () => notifier.setPage(state.totalPages) : null,
                icon: const Icon(Icons.last_page, size: 18),
                tooltip: 'Last Page',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                splashRadius: 16,
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                recordsInfo,
                const SizedBox(height: 8),
                pageNav,
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              recordsInfo,
              pageNav,
            ],
          );
        },
      ),
    );
  }

  // =========================================================================
  // 7. DIALOG LAUNCHERS
  // =========================================================================
  void _showCreateEditSubjectDialog(
    BuildContext context,
    AcademicSubjectModel? subject,
    ClassState state,
    ClassNotifier notifier,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => CreateEditSubjectDialog(
        subjectToEdit: subject,
        availableClasses: state.availableClasses,
        onSave: (payload) {
          if (subject == null) {
            return notifier.createSubject(
              name: payload['name'],
              code: payload['code'],
              type: payload['type'],
              description: payload['description'],
              color: payload['color'],
              status: payload['status'],
              isOptional: payload['is_optional'] ?? false,
              classIds: const [],
            );
          } else {
            return notifier.updateSubject(
              subject.id,
              name: payload['name'],
              code: payload['code'],
              type: payload['type'],
              description: payload['description'],
              color: payload['color'],
              status: payload['status'],
              isOptional: payload['is_optional'],
            );
          }
        },
      ),
    );
  }

  void _showAssignSubjectToSectionDialog(
    BuildContext context,
    AcademicSubjectModel subject,
    ClassState state,
    ClassNotifier notifier,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AssignSubjectToSectionDialog(
        subject: subject,
        availableClasses: state.availableClasses,
        availableSections: state.sections,
        onSave: ({required classId, required sectionIds, teacherId}) {
          return notifier.assignSubjectToSections(
            classId: classId,
            sectionIds: sectionIds,
            subjectId: subject.id,
            teacherId: teacherId,
          );
        },
      ),
    );
  }

  void _showAssignTeacherDialog(
    BuildContext context,
    AcademicSubjectModel subject,
    ClassState state,
    ClassNotifier notifier,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AssignSubjectTeacherDialog(
        defaultSubject: subject,
        availableClasses: state.availableClasses,
      ),
    );
  }

  void _showAssignTeacherForMappingDialog(
    BuildContext context,
    AcademicSubjectModel subject,
    SubjectSectionMappingModel mapping,
    ClassState state,
    ClassNotifier notifier,
  ) {
    final matchedClass = state.availableClasses.where((c) => c.id == mapping.classId).firstOrNull;
    final matchedSection = state.sections.where((s) => s.id == mapping.sectionId).firstOrNull;

    showDialog(
      context: context,
      builder: (ctx) => AssignSubjectTeacherDialog(
        defaultSubject: subject,
        defaultClass: matchedClass,
        defaultSection: matchedSection,
        defaultClassId: mapping.classId,
        defaultClassName: mapping.className,
        defaultSectionId: mapping.sectionId,
        defaultSectionName: mapping.sectionName,
        defaultTeacher: mapping.assignedTeacher,
        availableClasses: state.availableClasses,
      ),
    );
  }

  void _confirmUnassignSubjectFromSection(
    BuildContext context,
    AcademicSubjectModel subject,
    SubjectSectionMappingModel mapping,
    ClassNotifier notifier,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 22),
            SizedBox(width: 8),
            Text('Unassign Subject', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          mapping.isClassWide || mapping.sectionId.isEmpty
              ? 'Are you sure you want to unassign "${subject.name}" from ${mapping.className}?\n\nThis will remove class faculty mapping and student enrollments for this class.'
              : 'Are you sure you want to unassign "${subject.name}" from ${mapping.className} - Section ${mapping.sectionName}?\n\nThis will remove faculty assignment and active student enrollments for this section.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final ok = await notifier.unassignSubjectFromSection(
                classId: mapping.classId,
                sectionId: mapping.sectionId.isNotEmpty ? mapping.sectionId : null,
                subjectId: subject.id,
              );
              if (ok && context.mounted) {
                final targetLabel = mapping.isClassWide || mapping.sectionId.isEmpty
                    ? mapping.className
                    : '${mapping.className} - Section ${mapping.sectionName}';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Unassigned "${subject.name}" from $targetLabel'),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Unassign'),
          ),
        ],
      ),
    );
  }

  void _showStudentEnrollmentDialog(
    BuildContext context,
    AcademicSubjectModel subject,
    SubjectSectionMappingModel mapping,
    ClassState state,
  ) {
    final matchedClass = state.availableClasses.where((c) => c.id == mapping.classId).firstOrNull ??
        AcademicClassModel(id: mapping.classId, name: mapping.className, code: mapping.className);

    final matchedSection = state.sections.where((s) => s.id == mapping.sectionId).firstOrNull ??
        AcademicSectionModel(
          id: mapping.sectionId,
          classId: mapping.classId,
          name: mapping.sectionName,
          code: mapping.sectionName,
        );

    showDialog(
      context: context,
      builder: (ctx) => OptionalSubjectEnrollmentDialog(
        subject: subject,
        academicClass: matchedClass,
        section: matchedSection,
        academicYear: state.academicYear,
      ),
    );
  }

  void _showArchiveDialog(
    BuildContext context,
    AcademicSubjectModel subject,
    ClassNotifier notifier,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => ArchiveConfirmationDialog(
        title: 'Archive Subject',
        itemName: '${subject.name} (${subject.code})',
        impactDetails: {
          'Classes Linked': subject.classesCount,
          'Sections Linked': subject.sectionsCount,
        },
        onConfirm: (force) => notifier.archiveSubject(subject.id, force: force),
      ),
    );
  }

  void _handleToggleSubjectOfferingStatus(
    BuildContext context,
    SubjectSectionMappingModel m,
    AcademicSubjectModel selectedSub,
    ClassNotifier notifier,
  ) async {
    final isCurrentlyActive = m.status.toUpperCase() == 'ACTIVE';
    final targetStatus = isCurrentlyActive ? 'INACTIVE' : 'ACTIVE';

    if (targetStatus == 'ACTIVE') {
      if (m.classStatus.toUpperCase() != 'ACTIVE') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Cannot activate Subject offering. The Class "${m.className}" is currently Inactive. Please activate the Class first.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

      if (m.sectionStatus.toUpperCase() != 'ACTIVE') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Cannot activate Subject offering. The Section "${m.sectionName}" is currently Inactive. Please activate the Section first.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
    }

    final ok = await notifier.toggleClassSubjectStatus(
      classId: m.classId,
      sectionId: m.sectionId.isNotEmpty ? m.sectionId : null,
      subjectId: selectedSub.id,
      status: targetStatus,
    );

    if (!ok && context.mounted) {
      final err = notifier.state.errorMessage ?? 'Failed to update status';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(err, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '';
  }
}



class _ChartSlice {
  final double value;
  final Color color;
  _ChartSlice({required this.value, required this.color});
}

class _DonutChartPainter extends CustomPainter {
  final List<_ChartSlice> slices;

  _DonutChartPainter({required this.slices});

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<double>(0, (sum, s) => sum + s.value);
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 14.0;

    double startAngle = -math.pi / 2;

    for (var slice in slices) {
      final sweepAngle = (slice.value / total) * 2 * math.pi;
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
