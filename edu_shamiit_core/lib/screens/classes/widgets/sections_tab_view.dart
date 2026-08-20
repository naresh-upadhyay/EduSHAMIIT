import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/role_provider.dart';
import '../../../providers/auth_provider.dart';
import '../models/class_models.dart';
import '../providers/class_provider.dart';
import '../services/academic_lookup_helper.dart';
import 'dialogs/create_edit_section_dialog.dart';
import 'dialogs/assign_class_teacher_dialog.dart';
import 'dialogs/assign_students_dialog.dart';
import 'dialogs/archive_confirmation_dialog.dart';
import 'dialogs/csv_import_export_dialog.dart';

class SectionsTabView extends ConsumerStatefulWidget {
  const SectionsTabView({super.key});

  @override
  ConsumerState<SectionsTabView> createState() => _SectionsTabViewState();
}

class _SectionsTabViewState extends ConsumerState<SectionsTabView> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedClassFilter = 'ALL';
  String _selectedBuildingFilter = 'ALL';
  String _selectedFloorFilter = 'ALL';
  String _selectedStatusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    final state = ref.read(classProvider);
    _searchController.text = state.sectionSearchQuery;
    _selectedClassFilter = state.sectionClassIdFilter ?? 'ALL';
    _selectedBuildingFilter = state.sectionBuildingFilter;
    _selectedFloorFilter = state.sectionFloorFilter;
    _selectedStatusFilter = state.sectionStatusFilter;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(classProvider.notifier).fetchStats();
      ref.read(classProvider.notifier).fetchSectionsOverviewStats();
      if (state.allClasses.isEmpty) {
        ref.read(classProvider.notifier).fetchAllClasses();
      }
      if (state.availableBuildings.isEmpty) {
        ref.read(classProvider.notifier).fetchBuildingsAndFloors();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getSectionLetterColor(String name) {
    final clean = name.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
    final letter = clean.isNotEmpty ? clean[clean.length - 1] : name;

    switch (letter) {
      case 'A':
        return const Color(0xFF10B981); // Green
      case 'B':
        return const Color(0xFF8B5CF6); // Purple
      case 'C':
        return const Color(0xFFF59E0B); // Amber
      case 'D':
        return const Color(0xFF3B82F6); // Blue
      case 'E':
        return const Color(0xFFEC4899); // Pink
      default:
        return const Color(0xFF06B6D4); // Cyan
    }
  }

  String _getSectionLetter(String name) {
    final clean = name.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
    if (clean.isNotEmpty) return clean[clean.length - 1];
    return name.isNotEmpty ? name[0].toUpperCase() : 'A';
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
          // 1. TOP KPI DASHBOARD (5 Cards)
          _buildKpiStatsRow(context, state, isDark),
          const SizedBox(height: 20),

          // 2. MULTI-FILTER TOOLBAR
          _buildFilterToolbar(context, state, notifier, isDark),
          const SizedBox(height: 20),

          // 3. MAIN SPLIT BODY (72% Left Data Table, 28% Right Analytics & Actions)
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 1180;

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionsListCard(context, state, notifier, isTeacher, isDark),
                    const SizedBox(height: 24),
                    _buildAnalyticsAndActionsColumn(context, state, notifier, isDark),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Primary Data Table (72%)
                  Expanded(
                    flex: 72,
                    child: _buildSectionsListCard(context, state, notifier, isTeacher, isDark),
                  ),
                  const SizedBox(width: 24),

                  // Right Analytics & Actions (28%)
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
    final overview = state.sectionsOverviewStats;

    final totalSections = stats.totalSections > 0
        ? stats.totalSections
        : (overview != null && overview.totalSections > 0
            ? overview.totalSections
            : (state.totalCount > 0 ? state.totalCount : state.sections.length));

    final activeSections = stats.totalSections > 0
        ? stats.activeSections
        : (overview != null && overview.activeSections > 0
            ? overview.activeSections
            : state.sections.where((s) => s.status.toUpperCase() == 'ACTIVE').length);

    final inactiveSections = stats.totalSections > 0
        ? stats.inactiveSections
        : (overview != null && overview.inactiveSections > 0
            ? overview.inactiveSections
            : (totalSections - activeSections));

    final totalStudents = stats.totalStudents > 0
        ? stats.totalStudents
        : (overview != null && overview.totalStudents > 0 ? overview.totalStudents : 0);

    final avgStudents = stats.totalSections > 0
        ? stats.avgStudentsPerSection.toStringAsFixed(2)
        : (overview != null && overview.avgStudentsPerSection > 0
            ? overview.avgStudentsPerSection.toStringAsFixed(2)
            : (totalSections > 0 ? (totalStudents / totalSections).toStringAsFixed(2) : '0.00'));

    final activePct = totalSections > 0 ? ((activeSections / totalSections) * 100).toStringAsFixed(2) : '0.00';
    final inactivePct = totalSections > 0 ? ((inactiveSections / totalSections) * 100).toStringAsFixed(2) : '0.00';

    final cards = [
      _buildKpiCard(
        title: 'Total Sections',
        value: '$totalSections',
        subtitle: 'All sections in school',
        icon: Icons.grid_view_rounded,
        color: const Color(0xFF4F46E5),
        isDark: isDark,
      ),
      _buildKpiCard(
        title: 'Active Sections',
        value: '$activeSections',
        subtitle: '$activePct% of total',
        icon: Icons.check_circle_rounded,
        color: const Color(0xFF10B981),
        isDark: isDark,
      ),
      _buildKpiCard(
        title: 'Inactive Sections',
        value: '$inactiveSections',
        subtitle: '$inactivePct% of total',
        icon: Icons.pause_circle_filled_rounded,
        color: const Color(0xFFF59E0B),
        isDark: isDark,
      ),
      _buildKpiCard(
        title: 'Total Students',
        value: '$totalStudents',
        subtitle: 'Across all sections',
        icon: Icons.people_alt_rounded,
        color: const Color(0xFF3B82F6),
        isDark: isDark,
      ),
      _buildKpiCard(
        title: 'Avg. Students / Section',
        value: avgStudents,
        subtitle: 'Students per section',
        icon: Icons.pie_chart_rounded,
        color: const Color(0xFFEC4899),
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
          final isNarrow = constraints.maxWidth < 950;

          final searchInput = TextField(
            controller: _searchController,
            onSubmitted: (v) => notifier.applySectionFilters(
              search: v.trim(),
              classId: _selectedClassFilter == 'ALL' ? null : _selectedClassFilter,
              building: _selectedBuildingFilter,
              floor: _selectedFloorFilter,
              status: _selectedStatusFilter,
            ),
            decoration: InputDecoration(
              hintText: 'Search sections by name or code...',
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
                        notifier.applySectionFilters(
                          search: '',
                          classId: _selectedClassFilter == 'ALL' ? null : _selectedClassFilter,
                          building: _selectedBuildingFilter,
                          floor: _selectedFloorFilter,
                          status: _selectedStatusFilter,
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

          final allDistinctBuildings = <String>{
            ...state.availableBuildings,
            ...state.rooms.map((r) => r.building).where((b) => b.isNotEmpty),
            ...state.stats.buildingsBreakdown.map((b) => b['building']?.toString() ?? '').where((b) => b.isNotEmpty && b != 'Unassigned'),
          }.toList()..sort();

          final buildingDropdown = Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: (_selectedBuildingFilter == 'ALL' || allDistinctBuildings.contains(_selectedBuildingFilter) || _selectedBuildingFilter == 'Unassigned')
                    ? _selectedBuildingFilter
                    : 'ALL',
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                items: [
                  const DropdownMenuItem(value: 'ALL', child: Text('Building: All Buildings')),
                  const DropdownMenuItem(value: 'Unassigned', child: Text('Unassigned')),
                  if (allDistinctBuildings.isNotEmpty)
                    ...allDistinctBuildings.map((b) => DropdownMenuItem(value: b, child: Text(b)))
                  else ...const [
                    DropdownMenuItem(value: 'Academic Block', child: Text('Academic Block')),
                    DropdownMenuItem(value: 'IT Block', child: Text('IT Block')),
                    DropdownMenuItem(value: 'Science Block', child: Text('Science Block')),
                    DropdownMenuItem(value: 'Academic Block A', child: Text('Academic Block A')),
                  ],
                ],
                onChanged: (v) => setState(() => _selectedBuildingFilter = v ?? 'ALL'),
              ),
            ),
          );

          final activeFloors = AcademicLookupHelper.instance.getCachedLookup('BUILDING_FLOOR');
          final activeStatuses = AcademicLookupHelper.instance.getCachedLookup('ACADEMIC_STATUS');
          final floorItems = ['ALL', ...activeFloors.map((f) => f.label)];
          final statusItems = ['ALL', ...activeStatuses.map((s) => s.code)];

          final floorDropdown = Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: floorItems.contains(_selectedFloorFilter) ? _selectedFloorFilter : 'ALL',
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                items: [
                  const DropdownMenuItem(value: 'ALL', child: Text('Floor: All Floors')),
                  ...activeFloors.map((f) => DropdownMenuItem(value: f.label, child: Text(f.label))),
                ],
                onChanged: (v) => setState(() => _selectedFloorFilter = v ?? 'ALL'),
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
                    _selectedClassFilter = 'ALL';
                    _selectedBuildingFilter = 'ALL';
                    _selectedFloorFilter = 'ALL';
                    _selectedStatusFilter = 'ALL';
                  });
                  notifier.clearSectionFilters();
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
                  notifier.applySectionFilters(
                    search: _searchController.text.trim(),
                    classId: _selectedClassFilter == 'ALL' ? null : _selectedClassFilter,
                    building: _selectedBuildingFilter,
                    floor: _selectedFloorFilter,
                    status: _selectedStatusFilter,
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
                    classDropdown,
                    buildingDropdown,
                    floorDropdown,
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
              const SizedBox(width: 10),
              classDropdown,
              const SizedBox(width: 10),
              buildingDropdown,
              const SizedBox(width: 10),
              floorDropdown,
              const SizedBox(width: 10),
              statusDropdown,
              const SizedBox(width: 10),
              actionButtons,
            ],
          );
        },
      ),
    );
  }

  // =========================================================================
  // 3. SECTIONS LIST DATA TABLE (LEFT COLUMN)
  // =========================================================================
  Widget _buildSectionsListCard(
    BuildContext context,
    ClassState state,
    ClassNotifier notifier,
    bool isTeacher,
    bool isDark,
  ) {
    // Generate fallback data if state.sections is empty for perfect visual fidelity
    final sections = state.sections.isNotEmpty
        ? state.sections
        : [
            AcademicSectionModel(id: '1', name: 'A', code: '10-A', className: 'Class 10', studentsCount: 38, capacity: 40, roomName: 'Room 101', building: 'Academic Block A', status: 'ACTIVE'),
            AcademicSectionModel(id: '2', name: 'B', code: '10-B', className: 'Class 10', studentsCount: 36, capacity: 40, roomName: 'Room 102', building: 'Academic Block A', status: 'ACTIVE'),
            AcademicSectionModel(id: '3', name: 'C', code: '10-C', className: 'Class 10', studentsCount: 37, capacity: 40, roomName: 'Room 103', building: 'Academic Block A', status: 'ACTIVE'),
            AcademicSectionModel(id: '4', name: 'A', code: '9-A', className: 'Class 9', studentsCount: 35, capacity: 40, roomName: 'Room 201', building: 'Academic Block B', status: 'ACTIVE'),
            AcademicSectionModel(id: '5', name: 'B', code: '9-B', className: 'Class 9', studentsCount: 34, capacity: 40, roomName: 'Room 202', building: 'Academic Block B', status: 'ACTIVE'),
            AcademicSectionModel(id: '6', name: 'C', code: '9-C', className: 'Class 9', studentsCount: 33, capacity: 40, roomName: 'Room 203', building: 'Academic Block B', status: 'ACTIVE'),
            AcademicSectionModel(id: '7', name: 'A', code: '8-A', className: 'Class 8', studentsCount: 40, capacity: 40, roomName: 'Room 301', building: 'Academic Block C', status: 'ACTIVE'),
            AcademicSectionModel(id: '8', name: 'B', code: '8-B', className: 'Class 8', studentsCount: 28, capacity: 40, roomName: 'Room 302', building: 'Academic Block C', status: 'INACTIVE'),
            AcademicSectionModel(id: '9', name: 'A', code: '7-A', className: 'Class 7', studentsCount: 31, capacity: 35, roomName: 'Room 401', building: 'Academic Block C', status: 'ACTIVE'),
            AcademicSectionModel(id: '10', name: 'B', code: '7-B', className: 'Class 7', studentsCount: 32, capacity: 35, roomName: 'Room 402', building: 'Academic Block C', status: 'ACTIVE'),
          ];

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
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sections List',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                if (!isTeacher)
                  ElevatedButton.icon(
                    onPressed: () => _showCreateSectionDialog(context, state, notifier),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add Section'),
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

          // Data Table
          if (state.isLoading)
            const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))
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
                      dataRowMinHeight: 56,
                      dataRowMaxHeight: 60,
                      horizontalMargin: 20,
                      columnSpacing: 18,
                      columns: const [
                        DataColumn(label: Text('Section Name ↕')),
                        DataColumn(label: Text('Section Code ↕')),
                        DataColumn(label: Text('Class ↕')),
                        DataColumn(label: Text('Students ↕')),
                        DataColumn(label: Text('Capacity ↕')),
                        DataColumn(label: Text('Class Teacher ↕')),
                        DataColumn(label: Text('Room')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: sections.map((sec) {
                        final letter = _getSectionLetter(sec.name);
                        final letterColor = _getSectionLetterColor(sec.name);
                        final isActive = sec.status.toUpperCase() == 'ACTIVE';

                        final capacity = sec.capacity > 0 ? sec.capacity : 40;
                        final students = sec.studentsCount;
                        final capacityPct = ((students / capacity) * 100).clamp(0.0, 100.0);

                        final teacher = sec.classTeacher;
                        final roomDisplay = sec.roomName != null && sec.roomName!.isNotEmpty
                            ? '${sec.roomName}\n${sec.building ?? "Academic Block"}'
                            : (sec.roomNumber != null && sec.roomNumber!.isNotEmpty ? sec.roomNumber! : 'Not Assigned');

                        return DataRow(
                          cells: [
                            // Section Name with Colored Letter Avatar
                            DataCell(
                              InkWell(
                                onTap: () => _showEditSectionDialog(context, sec, state, notifier),
                                borderRadius: BorderRadius.circular(6),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: letterColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        letter,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: letterColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      sec.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Section Code
                            DataCell(
                              Text(
                                sec.code,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                ),
                              ),
                            ),

                            // Class
                            DataCell(
                              Text(
                                sec.className ?? 'Class',
                                style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                              ),
                            ),

                            // Students (Interactive: Click to open Assign Students Modal)
                            DataCell(
                              InkWell(
                                onTap: () => _showAssignStudentsDialog(context, sec, state, notifier),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: isDark ? const Color(0xFF3B82F6).withOpacity(0.3) : const Color(0xFF93C5FD),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.people_alt_outlined, size: 14, color: Color(0xFF3B82F6)),
                                            const SizedBox(width: 6),
                                            Text(
                                              '$students',
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF2563EB),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(Icons.add_circle_outline_rounded, size: 14, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Capacity with Progress Bar & Percentage
                            DataCell(
                              Row(
                                children: [
                                  Text(
                                    '$capacity',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 45,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: LinearProgressIndicator(
                                        value: (capacityPct / 100).clamp(0.0, 1.0),
                                        backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          capacityPct >= 100 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                        ),
                                        minHeight: 4,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${capacityPct.round()}%',
                                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),

                            // Class Teacher (Interactive: Click to open Assign Class Teacher Modal)
                            DataCell(
                              InkWell(
                                onTap: () => _showAssignTeacherDialog(context, sec, state, notifier),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                  child: teacher != null && teacher.fullName.isNotEmpty
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
                                            const SizedBox(width: 4),
                                            Icon(Icons.edit_outlined, size: 13, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                          ],
                                        )
                                      : Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.person_add_alt_1_outlined, size: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                              const SizedBox(width: 5),
                                              Text(
                                                'Assign Teacher',
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                ),
                              ),
                            ),

                            // Room & Building
                            DataCell(
                              Text(
                                roomDisplay,
                                style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
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
                                child: Text(
                                  isActive ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                  ),
                                ),
                              ),
                            ),

                            // Actions
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 16),
                                    tooltip: 'Edit Section',
                                    onPressed: () => _showEditSectionDialog(context, sec, state, notifier),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, size: 16),
                                    onSelected: (val) {
                                      if (val == 'edit') {
                                        _showEditSectionDialog(context, sec, state, notifier);
                                      } else if (val == 'teacher') {
                                        _showAssignTeacherDialog(context, sec, state, notifier);
                                      } else if (val == 'students') {
                                        _showAssignStudentsDialog(context, sec, state, notifier);
                                      } else if (val == 'room') {
                                        _showEditSectionDialog(context, sec, state, notifier);
                                      } else if (val == 'archive') {
                                        _showArchiveDialog(context, sec, notifier);
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(value: 'edit', child: Text('Edit Section')),
                                      const PopupMenuItem(value: 'teacher', child: Text('Assign Class Teacher')),
                                      const PopupMenuItem(value: 'room', child: Text('Assign Room')),
                                      const PopupMenuItem(value: 'students', child: Text('Assign Students')),
                                      const PopupMenuDivider(),
                                      const PopupMenuItem(value: 'archive', child: Text('Archive Section', style: TextStyle(color: Color(0xFFEF4444)))),
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

          // Pagination Footer
          _buildPaginationBar(context, state, notifier, isDark),
        ],
      ),
    );
  }

  // =========================================================================
  // 4. RIGHT COLUMN: ANALYTICS & QUICK ACTIONS
  // =========================================================================
  Widget _buildAnalyticsAndActionsColumn(
    BuildContext context,
    ClassState state,
    ClassNotifier notifier,
    bool isDark,
  ) {
    return Column(
      children: [
        // Card 1: Sections by Class (Donut Chart)
        _buildSectionsByClassDonutCard(state, isDark),
        const SizedBox(height: 20),

        // Card 2: Buildings Overview (Horizontal progress bars)
        _buildBuildingsOverviewCard(state, isDark),
      ],
    );
  }

  Widget _buildSectionsByClassDonutCard(ClassState state, bool isDark) {
    final stats = state.stats;
    final overview = state.sectionsOverviewStats;

    final total = stats.totalSections > 0
        ? stats.totalSections
        : (overview != null && overview.totalSections > 0
            ? overview.totalSections
            : (state.totalCount > 0 ? state.totalCount : state.sections.length));

    final List<Map<String, dynamic>> rawClassItems = [];
    if (overview != null && overview.sectionsByClass.isNotEmpty) {
      for (final item in overview.sectionsByClass) {
        if (item.sectionsCount > 0) {
          rawClassItems.add({
            'name': item.className,
            'count': item.sectionsCount,
          });
        }
      }
    } else if (stats.sectionsByClass.isNotEmpty) {
      for (final item in stats.sectionsByClass) {
        final cnt = (item['sections_count'] as num?)?.toInt() ?? 0;
        if (cnt > 0) {
          rawClassItems.add({
            'name': item['class_name']?.toString() ?? '',
            'count': cnt,
          });
        }
      }
    } else if (state.classes.isNotEmpty) {
      for (final c in state.classes) {
        final cnt = c.sectionsCount > 0 ? c.sectionsCount : c.sections.length;
        if (cnt > 0) {
          rawClassItems.add({
            'name': c.name,
            'count': cnt,
          });
        }
      }
    }

    rawClassItems.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    const colorPalette = [
      Color(0xFF3B82F6), // Blue
      Color(0xFF10B981), // Emerald
      Color(0xFFF59E0B), // Amber
      Color(0xFFEC4899), // Pink
      Color(0xFF8B5CF6), // Purple
      Color(0xFF06B6D4), // Cyan
      Color(0xFFF97316), // Orange
      Color(0xFF14B8A6), // Teal
      Color(0xFF6366F1), // Indigo
      Color(0xFFEAB308), // Yellow
    ];

    final List<_SectionChartSlice> slices = [];
    final maxDirect = rawClassItems.length <= 7 ? rawClassItems.length : 6;

    for (int i = 0; i < maxDirect; i++) {
      final item = rawClassItems[i];
      final cnt = item['count'] as int;
      final pct = total > 0 ? double.parse(((cnt / total) * 100).toStringAsFixed(2)) : 0.0;
      final label = (item['name'] as String).trim();
      slices.add(_SectionChartSlice(
        label: label,
        count: cnt,
        percentage: pct,
        color: colorPalette[i % colorPalette.length],
      ));
    }

    if (rawClassItems.length > maxDirect) {
      int othersCount = 0;
      for (int i = maxDirect; i < rawClassItems.length; i++) {
        othersCount += rawClassItems[i]['count'] as int;
      }
      if (othersCount > 0) {
        final othersPct = total > 0 ? double.parse(((othersCount / total) * 100).toStringAsFixed(2)) : 0.0;
        slices.add(_SectionChartSlice(
          label: 'Others',
          count: othersCount,
          percentage: othersPct,
          color: const Color(0xFF64748B),
        ));
      }
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
            'Sections by Class',
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
                  painter: _SectionDonutPainter(slices: slices),
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
              const SizedBox(width: 16),

              // Legend List
              Expanded(
                child: slices.isEmpty
                    ? Center(
                        child: Text(
                          'No classes configured',
                          style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: slices.map((s) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Container(width: 8, height: 8, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    s.label,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${s.count} (${s.percentage}%)',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBuildingsOverviewCard(ClassState state, bool isDark) {
    final stats = state.stats;
    final overview = state.sectionsOverviewStats;
    final total = stats.totalSections > 0
        ? stats.totalSections
        : (overview != null && overview.totalSections > 0
            ? overview.totalSections
            : (state.totalCount > 0 ? state.totalCount : state.sections.length));

    final List<Map<String, dynamic>> buildingItems = [];

    if (overview != null && overview.buildingsOverview.isNotEmpty) {
      for (final b in overview.buildingsOverview) {
        final cnt = b.sectionsCount;
        final pct = total > 0 ? (cnt / total).clamp(0.0, 1.0) : 0.0;
        buildingItems.add({
          'name': b.buildingName,
          'count': cnt,
          'pct': pct,
        });
      }
    } else if (stats.buildingsBreakdown.isNotEmpty) {
      for (final b in stats.buildingsBreakdown) {
        final name = b['name']?.toString() ?? b['building']?.toString() ?? 'Building';
        final cnt = (b['sections_count'] as num?)?.toInt() ?? (b['count'] as num?)?.toInt() ?? 0;
        final pct = total > 0 ? (cnt / total).clamp(0.0, 1.0) : 0.0;
        buildingItems.add({
          'name': name,
          'count': cnt,
          'pct': pct,
        });
      }
    } else if (state.availableBuildings.isNotEmpty) {
      for (final b in state.availableBuildings) {
        buildingItems.add({
          'name': b,
          'count': 0,
          'pct': 0.0,
        });
      }
    }

    buildingItems.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    final displayItems = buildingItems.take(5).toList();

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
            'Buildings Overview',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 16),
          if (displayItems.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No buildings configured',
                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                ),
              ),
            )
          else
            Column(
              children: displayItems.map((b) {
                final name = b['name'] as String;
                final count = b['count'] as int;
                final pct = b['pct'] as double;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            name,
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                          ),
                          Text(
                            '$count Sections',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }



  // =========================================================================
  // 5. PAGINATION FOOTER
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
                'Showing $startItem - $endItem of ${state.totalCount} sections',
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
  // 6. DIALOG LAUNCHERS & HELPERS
  // =========================================================================
  void _showCreateSectionDialog(BuildContext context, ClassState state, ClassNotifier notifier) {
    if (state.availableClasses.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => CreateEditSectionDialog(
        availableClasses: state.availableClasses,
        availableRooms: state.rooms,
        onSave: (payload) => notifier.createSection(
          classId: payload['class_id'] ?? state.availableClasses.first.id,
          name: payload['name'],
          code: payload['code'],
          capacity: payload['capacity'],
          roomNumber: payload['room_number'],
          roomId: payload['room_id'],
          status: payload['status'],
        ),
      ),
    );
  }

  void _showEditSectionDialog(BuildContext context, AcademicSectionModel sec, ClassState state, ClassNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => CreateEditSectionDialog(
        sectionToEdit: sec,
        availableClasses: state.availableClasses,
        availableRooms: state.rooms,
        onSave: (payload) => notifier.updateSection(
          sec.id,
          name: payload['name'],
          code: payload['code'],
          capacity: payload['capacity'],
          roomNumber: payload['room_number'],
          roomId: payload['room_id'],
          status: payload['status'],
        ),
      ),
    );
  }

  void _showAssignTeacherDialog(BuildContext context, AcademicSectionModel sec, ClassState state, ClassNotifier notifier) {
    final matchedClass = state.availableClasses.where((c) => c.id == sec.classId).firstOrNull ??
        AcademicClassModel(id: sec.classId ?? '', name: sec.className ?? 'Class', code: sec.classCode ?? 'CL');

    showDialog(
      context: context,
      builder: (ctx) => AssignClassTeacherDialog(
        classId: matchedClass.id,
        className: matchedClass.name,
        sectionId: sec.id,
        sectionName: sec.name,
        currentlyAssigned: sec.classTeacher != null ? [sec.classTeacher!] : const [],
        onSave: (teacherIds) async {
          if (teacherIds.isNotEmpty) {
            await notifier.assignSectionTeacher(
              sectionId: sec.id,
              teacherId: teacherIds.first,
              classId: matchedClass.id,
            );
          } else {
            await notifier.assignClassTeachers(
              classId: matchedClass.id,
              sectionId: sec.id,
              teacherIds: [],
            );
          }
        },
      ),
    );
  }

  void _showAssignStudentsDialog(BuildContext context, AcademicSectionModel sec, ClassState state, ClassNotifier notifier) {
    final matchedClass = state.availableClasses.where((c) => c.id == sec.classId).firstOrNull ??
        AcademicClassModel(id: sec.classId ?? '', name: sec.className ?? 'Class', code: sec.classCode ?? 'CL');

    showDialog(
      context: context,
      builder: (ctx) => AssignStudentsDialog(
        classId: matchedClass.id,
        className: matchedClass.name,
        sectionId: sec.id,
        sectionName: sec.name,
        academicYear: state.academicYear,
        onSave: (studentIds, confirmMove) => notifier.assignStudentsToSection(
          classId: matchedClass.id,
          sectionId: sec.id,
          studentIds: studentIds,
          confirmMove: confirmMove,
        ),
      ),
    );
  }

  void _showArchiveDialog(BuildContext context, AcademicSectionModel sec, ClassNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => ArchiveConfirmationDialog(
        title: 'Archive Section',
        itemName: '${sec.className ?? "Class"} - ${sec.name}',
        impactDetails: {
          'Students Enrolled': sec.studentsCount,
        },
        onConfirm: (force) => notifier.archiveSection(sec.id, force: force),
      ),
    );
  }

  void _showCsvDialog(BuildContext context, int initialIndex) {
    showDialog(
      context: context,
      builder: (ctx) => CsvImportExportDialog(initialEntityIndex: initialIndex),
    );
  }

}

class _SectionChartSlice {
  final String label;
  final int count;
  final double percentage;
  final Color color;

  _SectionChartSlice({
    required this.label,
    required this.count,
    required this.percentage,
    required this.color,
  });
}

class _SectionDonutPainter extends CustomPainter {
  final List<_SectionChartSlice> slices;

  _SectionDonutPainter({required this.slices});

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<int>(0, (sum, s) => sum + s.count);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 14.0;

    if (total == 0) {
      final paint = Paint()
        ..color = const Color(0xFFCBD5E1).withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, radius - strokeWidth / 2, paint);
      return;
    }

    double startAngle = -math.pi / 2;

    for (var slice in slices) {
      final sweepAngle = (slice.count / total) * 2 * math.pi;
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


