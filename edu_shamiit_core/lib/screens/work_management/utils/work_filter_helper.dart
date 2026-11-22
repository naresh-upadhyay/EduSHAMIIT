import 'package:flutter/material.dart';
import '../models/work_models.dart';
import '../services/work_api_service.dart';

class WorkFilterMetadata {
  final List<WorkAssigneeModel> assignees;
  final List<WorkAcademicClassModel> classes;
  final List<String> teams;

  const WorkFilterMetadata({
    this.assignees = const [],
    this.classes = const [],
    this.teams = const [],
  });
}

/// Helper utility for Enterprise Advance Filters across Work Management screens.
/// Supports cascading Role -> (if Student) -> Class -> (if Class selected) -> Section
/// with dynamic data loading from DB tables.
class WorkFilterHelper {
  static WorkFilterMetadata? _cachedMetadata;
  static Future<WorkFilterMetadata>? _inFlightMetadataFuture;
  static List<String>? _cachedTeams;
  static List<WorkAcademicClassModel>? _cachedClasses;

  /// Clears in-memory caches to force live re-fetch from database
  static void clearCache() {
    _cachedMetadata = null;
    _inFlightMetadataFuture = null;
    _cachedTeams = null;
    _cachedClasses = null;
  }

  /// Loads and caches assignable users, classes, and teams in a single deduped batch.
  static Future<WorkFilterMetadata> loadMetadata(WorkApiService api, {bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedMetadata != null) {
      return _cachedMetadata!;
    }
    if (!forceRefresh && _inFlightMetadataFuture != null) {
      return _inFlightMetadataFuture!;
    }

    _inFlightMetadataFuture = _fetchMetadataInternal(api, forceRefresh: forceRefresh);
    final result = await _inFlightMetadataFuture!;
    _cachedMetadata = result;
    _inFlightMetadataFuture = null;
    return result;
  }

  static Future<WorkFilterMetadata> _fetchMetadataInternal(WorkApiService api, {bool forceRefresh = false}) async {
    try {
      final usersFuture = api.getAssignableUsers(limit: 100);
      final classesFuture = fetchAcademicClasses(api, forceRefresh: forceRefresh);
      final teamsFuture = fetchTeamNames(api, forceRefresh: forceRefresh);
      final results = await Future.wait([usersFuture, classesFuture, teamsFuture]);
      return WorkFilterMetadata(
        assignees: results[0] as List<WorkAssigneeModel>,
        classes: results[1] as List<WorkAcademicClassModel>,
        teams: results[2] as List<String>,
      );
    } catch (_) {
      return const WorkFilterMetadata(
        assignees: [],
        classes: [],
        teams: defaultTeams,
      );
    }
  }

  /// Canonical work boards matching Azure DevOps Boards.
  static const List<String> boardOptions = [
    'Institute Work Board',
    'Academic Board',
    'IT & Infra Board',
  ];

  static const Map<String, String> boardIdMap = {
    'Institute Work Board': '31dacd93-15ee-4eed-8994-56973fd81245',
    'Academic Board': 'a1111111-2222-3333-4444-555555555551',
    'IT & Infra Board': 'a1111111-2222-3333-4444-555555555552',
  };

  static String? resolveBoardId(String? boardName) {
    if (boardName == null || boardName.isEmpty || boardName.toLowerCase() == 'all') return null;
    return boardIdMap[boardName] ?? boardName;
  }

  /// Canonical roles matching the school ERP architecture.
  static const List<String> roleOptions = [
    'All',
    'Teacher',
    'Staff',
    'Student',
    'Admin',
    'Security',
    'Hostel',
    'Super Admin',
  ];

  /// Canonical institute departments.
  static const List<String> defaultDepartments = [
    'All',
    'Academic',
    'IT Services',
    'Administration',
    'Facilities',
    'Examination',
    'Security',
    'Finance',
    'Student Activity',
    'Hostel',
    'Library',
  ];

  /// Canonical institute teams matching Azure DevOps Sprint Teams from DB.
  static const List<String> defaultTeams = [
    'All',
    'Academic Systems Team',
    'Digital Campus Team',
    'Examination Team',
    'Infrastructure & Maintenance Team',
    'IT Operations Team',
    'Library Systems Team',
  ];

  /// Loads teams dynamically from the backend API/DB with in-memory caching.
  static Future<List<String>> fetchTeamNames(WorkApiService api, {bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedTeams != null && _cachedTeams!.isNotEmpty) {
      return _cachedTeams!;
    }
    try {
      final resp = await api.getTeamsDirectory(limit: 50);
      if (resp != null && resp.teams.isNotEmpty) {
        final names = resp.teams.map((t) => t.name).toList();
        final combined = <String>{'All', ...names, ...defaultTeams}.toList();
        _cachedTeams = combined;
        return combined;
      }
    } catch (_) {}
    _cachedTeams = defaultTeams;
    return defaultTeams;
  }

  /// Loads academic classes and nested sections directly from the backend API/DB with in-memory caching.
  static Future<List<WorkAcademicClassModel>> fetchAcademicClasses(WorkApiService api, {bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedClasses != null && _cachedClasses!.isNotEmpty) {
      return _cachedClasses!;
    }
    try {
      final classes = await api.getAcademicClasses();
      if (classes.isNotEmpty) {
        _cachedClasses = classes;
        return classes;
      }
    } catch (_) {}

    // Fallback classes matching school database schema
    _cachedClasses = const [
      WorkAcademicClassModel(
        id: 'cls-5',
        name: 'Class 5',
        sections: [
          WorkAcademicSectionModel(id: 'sec-5-1', name: 'NEWSUB2'),
          WorkAcademicSectionModel(id: 'sec-5-2', name: 'Section A'),
          WorkAcademicSectionModel(id: 'sec-5-3', name: 'Section B'),
        ],
      ),
      WorkAcademicClassModel(
        id: 'cls-6',
        name: 'Class 6',
        sections: [
          WorkAcademicSectionModel(id: 'sec-6-1', name: 'Section A'),
          WorkAcademicSectionModel(id: 'sec-6-2', name: 'Section B'),
        ],
      ),
      WorkAcademicClassModel(
        id: 'cls-7',
        name: 'Class 7',
        sections: [
          WorkAcademicSectionModel(id: 'sec-7-1', name: 'Section A'),
          WorkAcademicSectionModel(id: 'sec-7-2', name: 'Section B'),
        ],
      ),
      WorkAcademicClassModel(
        id: 'cls-8',
        name: 'Class 8',
        sections: [
          WorkAcademicSectionModel(id: 'sec-8-1', name: 'Section A'),
          WorkAcademicSectionModel(id: 'sec-8-2', name: 'Section B'),
        ],
      ),
      WorkAcademicClassModel(
        id: 'cls-9',
        name: 'Class 9',
        sections: [
          WorkAcademicSectionModel(id: 'sec-9-1', name: 'Section A'),
          WorkAcademicSectionModel(id: 'sec-9-2', name: 'Section B'),
        ],
      ),
      WorkAcademicClassModel(
        id: 'cls-10',
        name: 'Class 10',
        sections: [
          WorkAcademicSectionModel(id: 'sec-10-1', name: '10A'),
          WorkAcademicSectionModel(id: 'sec-10-2', name: '10B'),
          WorkAcademicSectionModel(id: 'sec-10-3', name: '10C'),
        ],
      ),
    ];
    return _cachedClasses!;
  }

  /// Extracts sections for a selected class name.
  static List<String> getSectionsForClass(List<WorkAcademicClassModel> classes, String className) {
    if (className == 'All' || className.isEmpty) return const ['All'];
    final cls = classes.firstWhere(
      (c) => c.name.toLowerCase() == className.toLowerCase(),
      orElse: () => const WorkAcademicClassModel(id: '', name: '', sections: []),
    );
    final secNames = cls.sections.map((s) => s.name).where((n) => n.isNotEmpty).toList();
    return ['All', ...secNames];
  }

  /// Evaluates whether an item matches the active advanced audience filters.
  static bool matchesAdvancedFilters({
    required WorkItemModel item,
    required String roleFilter,
    required String departmentFilter,
    required String classFilter,
    required String sectionFilter,
    String teamFilter = 'All',
    String? boardFilter,
  }) {
    // 0. Board Filter
    if (boardFilter != null && boardFilter.isNotEmpty && boardFilter != 'All' && boardFilter != 'All Boards') {
      final bf = boardFilter.trim().toLowerCase();
      final expectedUuid = boardIdMap[boardFilter]?.toLowerCase();
      final itemBoard = (item.boardName ?? '').trim().toLowerCase();
      final itemBoardId = (item.boardId ?? '').trim().toLowerCase();

      bool boardMatches(String bName, String bId) {
        if (expectedUuid != null && bId == expectedUuid) return true;
        if (bName == bf || bName.contains(bf) || bf.contains(bName)) return true;
        if (bf.contains('institute') && bName.contains('institute')) return true;
        if (bf.contains('academic') && bName.contains('academic')) return true;
        if (bf.contains('infra') && (bName.contains('infra') || bName.contains('it'))) return true;
        return false;
      }

      final hasDirectBoard = boardMatches(itemBoard, itemBoardId);
      final hasChildBoard = item.children.any((c) =>
          boardMatches((c.boardName ?? '').trim().toLowerCase(), (c.boardId ?? '').trim().toLowerCase()));

      if (!hasDirectBoard && !hasChildBoard && (itemBoard.isNotEmpty || itemBoardId.isNotEmpty)) {
        return false;
      }
    }

    // 1. Role Filter
    if (roleFilter != 'All') {
      final rf = roleFilter.toLowerCase();
      final hasRoleAssignee = item.assignees.any((a) =>
          a.role.toLowerCase() == rf ||
          a.role.toLowerCase().contains(rf) ||
          (rf == 'student' && a.className != null));
      final hasChildRoleAssignee = item.children.any((c) =>
          c.assignees.any((a) =>
              a.role.toLowerCase() == rf ||
              a.role.toLowerCase().contains(rf) ||
              (rf == 'student' && a.className != null)));
      final isItemRoleTarget = (item.targetRole ?? '').toLowerCase() == rf;
      final isStudentTarget = rf == 'student' &&
          (item.workType.toUpperCase() == 'HOMEWORK' ||
              item.workType.toUpperCase() == 'ASSIGNMENT' ||
              item.category.toLowerCase().contains('student') ||
              item.className != null ||
              item.classId != null);

      if (!hasRoleAssignee && !hasChildRoleAssignee && !isItemRoleTarget && !isStudentTarget) {
        return false;
      }
    }

    // 2. Department Filter
    if (departmentFilter != 'All') {
      final df = departmentFilter.toLowerCase();
      final hasDeptAssignee = item.assignees.any((a) => (a.department ?? '').toLowerCase().contains(df));
      final hasChildDept = item.children.any((c) => c.assignees.any((a) => (a.department ?? '').toLowerCase().contains(df)));
      final hasCategoryDept = item.category.toLowerCase().contains(df);
      if (!hasDeptAssignee && !hasChildDept && !hasCategoryDept) {
        return false;
      }
    }

    // 3. Class Filter (Applicable when Role == 'Student' or Class is explicitly chosen)
    if (classFilter != 'All') {
      final cf = classFilter.toLowerCase();
      bool classMatches(String? cls) {
        if (cls == null || cls.trim().isEmpty) return false;
        final c1 = cls.trim().toLowerCase();
        final c2 = cf.trim().toLowerCase();
        if (c1 == c2) return true;
        if (c1.contains(c2) || c2.contains(c1)) return true;
        final num1 = RegExp(r'\d+').firstMatch(c1)?.group(0);
        final num2 = RegExp(r'\d+').firstMatch(c2)?.group(0);
        if (num1 != null && num2 != null && num1 == num2) return true;
        return false;
      }

      final itemDirectClassMatch = classMatches(item.className) || item.classId == classFilter;
      final hasClassAssignee = item.assignees.any((a) => classMatches(a.className));
      final hasChildClass = item.children.any((c) =>
          classMatches(c.className) ||
          c.assignees.any((a) => classMatches(a.className)));
      final textMatches = item.title.toLowerCase().contains(cf) || item.description.toLowerCase().contains(cf);

      if (!itemDirectClassMatch && !hasClassAssignee && !hasChildClass && !textMatches) {
        return false;
      }
    }

    // 4. Section Filter (Applicable when Class != 'All' and Section != 'All')
    if (sectionFilter != 'All') {
      final sf = sectionFilter.trim().toLowerCase();
      bool sectionMatches(String? sec) {
        if (sec == null || sec.trim().isEmpty) return false;
        final s1 = sec.trim().toLowerCase().replaceAll('section', '').replaceAll('sec', '').replaceAll('-', '').trim();
        final s2 = sf.trim().toLowerCase().replaceAll('section', '').replaceAll('sec', '').replaceAll('-', '').trim();
        if (s1 == s2) return true;
        final clean = sec.trim().toLowerCase();
        return clean == sf || clean.contains(sf) || sf.contains(clean);
      }

      final itemDirectSectionMatch = sectionMatches(item.sectionName) || item.sectionId == sectionFilter;
      final hasSectionAssignee = item.assignees.any((a) => sectionMatches(a.sectionName));
      final hasChildSection = item.children.any((c) =>
          sectionMatches(c.sectionName) ||
          c.assignees.any((a) => sectionMatches(a.sectionName)));
      final textMatches = item.title.toLowerCase().contains('section $sf') ||
          item.title.toLowerCase().contains('sec $sf') ||
          item.title.toLowerCase().contains('sec-$sf') ||
          item.title.toLowerCase().contains('section-$sf') ||
          item.description.toLowerCase().contains('section $sf') ||
          item.description.toLowerCase().contains('sec $sf');

      if (!itemDirectSectionMatch && !hasSectionAssignee && !hasChildSection && !textMatches) {
        return false;
      }
    }

    // 5. Team Filter
    if (teamFilter.isNotEmpty &&
        teamFilter != 'All' &&
        teamFilter != 'All Teams' &&
        teamFilter.toLowerCase() != 'all' &&
        teamFilter.toLowerCase() != 'all teams') {
      final tf = teamFilter.trim().toLowerCase();
      final itemTeam = (item.teamName ?? '').trim().toLowerCase();
      final hasMatchingTeam = itemTeam == tf || itemTeam.contains(tf) || item.teamId == teamFilter;
      final hasChildTeam = item.children.any((c) {
        final ct = (c.teamName ?? '').trim().toLowerCase();
        return ct == tf || ct.contains(tf) || c.teamId == teamFilter;
      });
      if (!hasMatchingTeam && !hasChildTeam) {
        return false;
      }
    }

    return true;
  }

  /// Builds a reusable modern dropdown for the Azure DevOps filter bar.
  static Widget buildFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
    IconData? prefixIcon,
    Color? accentColor,
  }) {
    final borderColor = isDark ? const Color(0xFF1F293D) : const Color(0xFFCBD5E1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColor ?? borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (prefixIcon != null) ...[
            Icon(prefixIcon, size: 14, color: accentColor ?? const Color(0xFF3B82F6)),
            const SizedBox(width: 5),
          ],
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : items.first,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
              isDense: true,
              dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              items: items.map((item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  /// Displays an enterprise modal dialog to tag multiple work items to a team.
  static Future<void> openBulkTagTeamDialog({
    required BuildContext context,
    required List<String> itemIds,
    required bool isDark,
    required Future<bool> Function({required List<String> itemIds, String? teamName}) onApply,
    VoidCallback? onSuccess,
  }) async {
    if (itemIds.isEmpty) return;

    final teamsList = defaultTeams.where((t) => t != 'All').toList();
    String selectedTeam = teamsList.isNotEmpty ? teamsList.first : 'Academic Systems Team';
    bool isUnassign = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.groups_rounded, color: Color(0xFF6366F1), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tag ${itemIds.length} Work Items to Team',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select the team responsible for delivering these items across sprints and boards.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Target Team',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFCBD5E1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: isUnassign ? null : selectedTeam,
                          isExpanded: true,
                          hint: const Text('None (Unassigned)'),
                          dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                selectedTeam = val;
                                isUnassign = false;
                              });
                            }
                          },
                          items: teamsList.map((t) {
                            return DropdownMenuItem<String>(
                              value: t,
                              child: Row(
                                children: [
                                  const Icon(Icons.people_alt_outlined, size: 16, color: Color(0xFF6366F1)),
                                  const SizedBox(width: 8),
                                  Text(t),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Checkbox(
                          value: isUnassign,
                          activeColor: const Color(0xFFEF4444),
                          onChanged: (val) {
                            setDialogState(() {
                              isUnassign = val ?? false;
                            });
                          },
                        ),
                        GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              isUnassign = !isUnassign;
                            });
                          },
                          child: Text(
                            'Remove from any team (Unassign)',
                            style: TextStyle(
                              fontSize: 12,
                              color: isUnassign ? const Color(0xFFEF4444) : (isDark ? Colors.white70 : const Color(0xFF475569)),
                              fontWeight: isUnassign ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final targetTeam = isUnassign ? 'UNASSIGN' : selectedTeam;
                    final ok = await onApply(itemIds: itemIds, teamName: targetTeam);
                    if (!context.mounted) return;
                    if (ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isUnassign
                                ? 'Unassigned ${itemIds.length} items from teams.'
                                : 'Successfully tagged ${itemIds.length} items to $selectedTeam.',
                          ),
                          backgroundColor: isUnassign ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                        ),
                      );
                      onSuccess?.call();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to update team tagging. Please try again.'),
                          backgroundColor: Color(0xFFEF4444),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isUnassign ? const Color(0xFFEF4444) : const Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    isUnassign ? 'Unassign Team' : 'Tag to Team',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
