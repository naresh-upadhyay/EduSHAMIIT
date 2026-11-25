import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import '../models/work_models.dart';
import '../services/work_api_service.dart';
import '../widgets/work_searchable_dropdown.dart';

class WorkFilterMetadata {
  final List<WorkAssigneeModel> assignees;
  final List<WorkAcademicClassModel> classes;
  final List<String> teams;
  final List<String> roles;
  final List<Map<String, dynamic>> rolesData;

  const WorkFilterMetadata({
    this.assignees = const [],
    this.classes = const [],
    this.teams = const [],
    this.roles = const [],
    this.rolesData = const [],
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
  static List<String>? _cachedRoles;
  static List<Map<String, dynamic>>? _cachedRolesData;

  /// Clears in-memory caches to force live re-fetch from database
  static void clearCache() {
    _cachedMetadata = null;
    _inFlightMetadataFuture = null;
    _cachedTeams = null;
    _cachedClasses = null;
    _cachedRoles = null;
    _cachedRolesData = null;
  }

  /// Loads and caches assignable users, classes, teams, and roles in a single deduped batch.
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
      final rolesFuture = fetchRoles(api, forceRefresh: forceRefresh);
      final results = await Future.wait([usersFuture, classesFuture, teamsFuture, rolesFuture]);
      return WorkFilterMetadata(
        assignees: results[0] as List<WorkAssigneeModel>,
        classes: results[1] as List<WorkAcademicClassModel>,
        teams: results[2] as List<String>,
        roles: results[3] as List<String>,
        rolesData: _cachedRolesData ?? const [],
      );
    } catch (_) {
      return const WorkFilterMetadata(
        assignees: [],
        classes: [],
        teams: defaultTeams,
        roles: defaultRoles,
        rolesData: [],
      );
    }
  }

  /// Canonical work boards matching SHAMIIT Boards.
  static const List<String> boardOptions = [
    'All Boards',
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
    if (boardName == null || boardName.isEmpty || boardName.toLowerCase() == 'all' || boardName.toLowerCase() == 'all boards') return null;
    return boardIdMap[boardName] ?? boardName;
  }

  /// Default full set of 27 roles matching DB/school ERP architecture, sorted alphabetically with 'All' first.
  static const List<String> defaultRoles = [
    'All',
    'Academic Admin',
    'Accountant',
    'Auditor',
    'Campus Administrator',
    'Campus Security',
    'Department Head',
    'Device Administrator',
    'Director',
    'Driver',
    'Examination Controller',
    'Facility Manager',
    'Front Office',
    'Hostel Warden',
    'HR Manager',
    'Institution Admin',
    'IoT Operator',
    'IT/IoT Administrator',
    'Librarian',
    'Maintenance Staff',
    'Sports Coach',
    'Staff Member',
    'Student',
    'Student (Parent)',
    'Super Admin',
    'Teacher',
    'Transport Manager',
    'View Only',
  ];

  /// Canonical roles accessor - provides dynamic cached roles or full default 27 roles list.
  static List<String> get roleOptions => _cachedRoles ?? defaultRoles;

  /// Loads all 27 roles dynamically from the backend API/DB with in-memory caching and alphabetical sorting.
  static Future<List<String>> fetchRoles(WorkApiService api, {bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedRoles != null && _cachedRoles!.isNotEmpty) {
      return _cachedRoles!;
    }
    try {
      final rawRoles = await api.getWorkRoles();
      if (rawRoles.isNotEmpty) {
        _cachedRolesData = rawRoles;
        final labels = <String>{};
        for (final r in rawRoles) {
          final label = (r['label'] ?? r['name'] ?? r['code'] ?? '').toString().trim();
          if (label.isNotEmpty && label.toLowerCase() != 'all') {
            labels.add(label);
          }
        }
        final sortedList = labels.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        final result = ['All', ...sortedList];
        _cachedRoles = result;
        return result;
      }
    } catch (_) {}
    _cachedRoles = defaultRoles;
    return defaultRoles;
  }

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

  /// Canonical institute teams matching SHAMIIT Sprint Teams from DB.
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
      final resp = await api.getTeamsDirectory(limit: 100, forceRefresh: forceRefresh);
      if (resp != null && resp.teams.isNotEmpty) {
        final names = resp.teams
            .where((t) => t.status.toUpperCase() != 'ARCHIVED' && t.isActive)
            .map((t) => t.name)
            .toList();
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
      final rf = roleFilter.toLowerCase().trim();
      final validTokens = <String>{rf};

      // Extract matching aliases from cached roles data (code, name, label)
      for (final rd in _cachedRolesData ?? const <Map<String, dynamic>>[]) {
        final l = (rd['label'] ?? '').toString().toLowerCase().trim();
        final n = (rd['name'] ?? '').toString().toLowerCase().trim();
        final c = (rd['code'] ?? '').toString().toLowerCase().trim();
        if (l == rf || n == rf || c == rf || (l.isNotEmpty && rf.contains(l)) || (rf.isNotEmpty && l.contains(rf))) {
          if (l.isNotEmpty) validTokens.add(l);
          if (n.isNotEmpty) validTokens.add(n);
          if (c.isNotEmpty) validTokens.add(c);
        }
      }

      // Canonical role aliases
      if (rf == 'staff' || rf == 'staff member') {
        validTokens.addAll(['staff', 'staff member', 'staff_member']);
      }
      if (rf == 'admin' || rf == 'institution admin') {
        validTokens.addAll(['admin', 'institution admin', 'institution_admin', 'institution_administrator']);
      }
      if (rf == 'super admin') {
        validTokens.addAll(['super admin', 'super_admin', 'superadmin']);
      }
      if (rf == 'security' || rf == 'campus security') {
        validTokens.addAll(['security', 'campus security', 'campus_security']);
      }
      if (rf == 'hostel' || rf == 'hostel warden') {
        validTokens.addAll(['hostel', 'hostel warden', 'hostel_warden']);
      }
      if (rf == 'teacher' || rf == 'faculty') {
        validTokens.addAll(['teacher', 'faculty']);
      }
      if (rf == 'academic admin' || rf == 'principal') {
        validTokens.addAll(['academic admin', 'principal', 'academic_admin']);
      }

      bool assigneeMatchesRole(WorkAssigneeModel a) {
        final aRole = a.role.toLowerCase().trim();
        if (validTokens.contains(aRole)) return true;
        for (final token in validTokens) {
          if (aRole.contains(token) || token.contains(aRole)) return true;
        }
        if (validTokens.contains('student') && a.className != null) return true;
        return false;
      }

      final hasRoleAssignee = item.assignees.any(assigneeMatchesRole);
      final hasChildRoleAssignee = item.children.any((c) => c.assignees.any(assigneeMatchesRole));

      final itemTargetRole = (item.targetRole ?? '').toLowerCase().trim();
      final isItemRoleTarget = itemTargetRole.isNotEmpty && (
        validTokens.contains(itemTargetRole) ||
        validTokens.any((t) => itemTargetRole.contains(t) || t.contains(itemTargetRole))
      );

      final isStudentTarget = validTokens.contains('student') &&
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

  /// Builds a reusable modern searchable dropdown for the SHAMIIT filter bar.
  static Widget buildFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
    IconData? prefixIcon,
    Color? accentColor,
    double? width,
  }) {
    return WorkSearchableDropdown(
      label: label,
      value: value,
      items: items,
      icon: prefixIcon,
      width: width,
      compact: true,
      onChanged: (v) => onChanged(v),
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

    final teamsList = (_cachedTeams ?? defaultTeams).where((t) => t != 'All' && t != 'All Teams').toList();
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
                        child: AppSearchableDropdown<String>.fromMenuItems(
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

  /// Unified "Manage Assignees" dialog for single and bulk work item assignment.
  /// Features search, role filters, user list with avatars/departments/emails, and multiselect.
  static Future<void> openManageAssigneesDialog({
    required BuildContext context,
    required List<String> itemIds,
    List<WorkAssigneeModel>? availableUsers,
    WorkApiService? api,
    Set<String>? initialSelectedUserIds,
    required Future<bool> Function({
      required List<String> itemIds,
      required List<String> selectedUserIds,
      required List<WorkAssigneeModel> selectedUsers,
    }) onApply,
    VoidCallback? onSuccess,
  }) async {
    List<WorkAssigneeModel> users = List<WorkAssigneeModel>.from(availableUsers ?? []);
    if (users.isEmpty && api != null) {
      final meta = await loadMetadata(api);
      users = meta.assignees;
    }
    if (!context.mounted) return;

    final selectedIds = Set<String>.from(initialSelectedUserIds ?? {});
    final searchCtrl = TextEditingController();
    String roleFilter = 'All';
    bool isSaving = false;

    await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            final q = searchCtrl.text.trim().toLowerCase();
            final filteredUsers = users.where((u) {
              if (roleFilter != 'All' && u.role.toLowerCase() != roleFilter.toLowerCase()) {
                return false;
              }
              if (q.isNotEmpty) {
                final mName = u.fullName.toLowerCase().contains(q);
                final mEmail = (u.email ?? '').toLowerCase().contains(q);
                final mRole = u.role.toLowerCase().contains(q);
                final mDept = (u.department ?? '').toLowerCase().contains(q);
                if (!mName && !mEmail && !mRole && !mDept) return false;
              }
              return true;
            }).toList();

            final screenWidth = MediaQuery.of(ctx).size.width;
            final dialogWidth = screenWidth > 560 ? 480.0 : (screenWidth - 32).clamp(280.0, 480.0);

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
              ),
              title: Row(
                children: [
                  const Icon(Icons.group_add_rounded, color: Color(0xFF2563EB), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Manage Assignees (${selectedIds.length} selected)',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  if (selectedIds.isNotEmpty)
                    TextButton(
                      onPressed: () => setDlgState(() => selectedIds.clear()),
                      child: const Text('Clear all', style: TextStyle(fontSize: 12, color: Color(0xFFEF4444))),
                    ),
                ],
              ),
              content: SizedBox(
                width: dialogWidth,
                height: 440,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: searchCtrl,
                      onChanged: (_) => setDlgState(() {}),
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        hintText: 'Search teachers, students, staff by name, role, email...',
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF3B82F6)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['All', 'teacher', 'student', 'admin', 'staff', 'super_admin'].map((r) {
                          final active = roleFilter == r;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(
                                r == 'All' ? 'All Roles' : r.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: active ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                ),
                              ),
                              selected: active,
                              selectedColor: const Color(0xFF2563EB),
                              backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF1F5F9),
                              onSelected: (_) => setDlgState(() => roleFilter = r),
                              visualDensity: VisualDensity.compact,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filteredUsers.isEmpty
                          ? const Center(
                              child: Text('No matching users found.', style: TextStyle(color: Color(0xFF94A3B8))),
                            )
                          : ListView.separated(
                              itemCount: filteredUsers.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                color: isDark ? const Color(0xFF1F293D) : const Color(0xFFF1F5F9),
                              ),
                              itemBuilder: (context, idx) {
                                final u = filteredUsers[idx];
                                final uid = u.userId.isNotEmpty ? u.userId : u.id;
                                final isChecked = selectedIds.contains(uid);
                                return CheckboxListTile(
                                  value: isChecked,
                                  dense: true,
                                  activeColor: const Color(0xFF2563EB),
                                  controlAffinity: ListTileControlAffinity.leading,
                                  title: Text(
                                    u.fullName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${u.role.toUpperCase()}${u.department != null && u.department!.isNotEmpty ? ' • ${u.department}' : ''}${u.email != null && u.email!.isNotEmpty ? ' • ${u.email}' : ''}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  secondary: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                    backgroundImage: (u.avatarUrl != null && u.avatarUrl!.isNotEmpty)
                                        ? NetworkImage(u.avatarUrl!)
                                        : null,
                                    child: (u.avatarUrl == null || u.avatarUrl!.isEmpty)
                                        ? Text(
                                            u.fullName.isNotEmpty ? u.fullName[0].toUpperCase() : 'U',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF2563EB),
                                            ),
                                          )
                                        : null,
                                  ),
                                  onChanged: (val) {
                                    setDlgState(() {
                                      if (val == true) {
                                        selectedIds.add(uid);
                                      } else {
                                        selectedIds.remove(uid);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDlgState(() => isSaving = true);
                          final selUsers = users.where((u) {
                            final uid = u.userId.isNotEmpty ? u.userId : u.id;
                            return selectedIds.contains(uid);
                          }).toList();
                          final ok = await onApply(
                            itemIds: itemIds,
                            selectedUserIds: selectedIds.toList(),
                            selectedUsers: selUsers,
                          );
                          if (!context.mounted) return;
                          Navigator.pop(ctx, true);
                          if (ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  selectedIds.isEmpty
                                      ? 'Unassigned assignees from ${itemIds.length} items.'
                                      : 'Updated assignees for ${itemIds.length} items (${selectedIds.length} assigned).',
                                ),
                                backgroundColor: const Color(0xFF10B981),
                              ),
                            );
                            onSuccess?.call();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to update assignees. Please try again.'),
                                backgroundColor: Color(0xFFEF4444),
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                  label: Text('Save (${selectedIds.length})', style: const TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
