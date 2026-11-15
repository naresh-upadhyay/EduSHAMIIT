import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/work_models.dart';
import '../../providers/work_management_provider.dart';

class CreateEditWorkItemDialog extends ConsumerStatefulWidget {
  final String? initialWorkType;
  final String? boardId;
  final String? sprintId;
  final String? parentId;
  final WorkItemModel? existingItem;

  const CreateEditWorkItemDialog({
    super.key,
    this.initialWorkType,
    this.boardId,
    this.sprintId,
    this.parentId,
    this.existingItem,
  });

  @override
  ConsumerState<CreateEditWorkItemDialog> createState() => _CreateEditWorkItemDialogState();
}

class _CreateEditWorkItemDialogState extends ConsumerState<CreateEditWorkItemDialog> {
  final _formKey = GlobalKey<FormState>();

  late String _workType;
  late String _priority;
  late String _category;
  String _assignmentMode = 'INDIVIDUAL'; // 'INDIVIDUAL', 'ROLE', 'CLASS_SECTION'

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _estimateController = TextEditingController();
  final TextEditingController _pointsController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _searchUserController = TextEditingController();

  // Academic specific fields
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _maxMarksController = TextEditingController();

  DateTime? _dueDate;
  DateTime? _startDate;

  // Assignment states
  List<WorkAssigneeModel> _allUsers = [];
  List<WorkAssigneeModel> _displayedUsers = [];
  final Set<String> _selectedUserIds = {};
  final Map<String, WorkAssigneeModel> _selectedUsersMap = {};

  // Role Assignment Mode
  String _selectedRole = 'teacher';
  String _selectedRoleDept = 'All';

  // Academic Class Assignment Mode
  List<WorkAcademicClassModel> _classesList = [];
  String? _selectedClassId;
  String? _selectedClassName;
  String? _selectedSectionId;
  String? _selectedSectionName;
  String _targetClassRole = 'student';

  // Filters for Individual mode
  String _userRoleFilter = 'All';
  String _userDeptFilter = 'All';

  bool _isLoadingUsers = true;
  bool _isLoadingClasses = true;
  bool _isSubmitting = false;
  Timer? _searchDebounce;

  final List<String> _types = [
    'TASK',
    'STORY',
    'BUG',
    'EPIC',
    'HOMEWORK',
    'ASSIGNMENT',
    'IMPROVEMENT',
    'ISSUE',
  ];

  final List<String> _priorities = ['LOW', 'MEDIUM', 'HIGH', 'URGENT', 'CRITICAL'];

  final List<String> _categories = [
    'Academic',
    'IT Services',
    'Administration',
    'Department',
    'Student Activity',
    'Examination',
    'Facilities',
    'Other',
  ];

  final List<String> _rolesList = [
    'teacher',
    'student',
    'admin',
    'staff',
    'hostel',
    'security',
    'super_admin',
  ];

  @override
  void initState() {
    super.initState();
    _workType = (widget.initialWorkType ?? widget.existingItem?.workType ?? 'TASK').toUpperCase();
    _priority = (widget.existingItem?.priority ?? 'MEDIUM').toUpperCase();
    _category = widget.existingItem?.category ?? (_workType == 'HOMEWORK' || _workType == 'ASSIGNMENT' ? 'Academic' : 'General');

    if (widget.existingItem != null) {
      final item = widget.existingItem!;
      _titleController.text = item.title;
      _descController.text = item.description;
      if (item.estimatedHours > 0) _estimateController.text = '${item.estimatedHours}';
      if (item.storyPoints > 0) _pointsController.text = '${item.storyPoints}';
      if (item.dueDate != null) _dueDate = DateTime.tryParse(item.dueDate!);
      if (item.startDate != null) _startDate = DateTime.tryParse(item.startDate!);
      for (final a in item.assignees) {
        _selectedUserIds.add(a.userId.isNotEmpty ? a.userId : a.id);
        _selectedUsersMap[a.userId.isNotEmpty ? a.userId : a.id] = a;
      }
    }

    _loadInitialData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _titleController.dispose();
    _descController.dispose();
    _estimateController.dispose();
    _pointsController.dispose();
    _tagsController.dispose();
    _searchUserController.dispose();
    _subjectController.dispose();
    _maxMarksController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final api = ref.read(workApiServiceProvider);
    try {
      final usersFuture = api.getAssignableUsers(limit: 200);
      final classesFuture = api.getAcademicClasses();

      final results = await Future.wait([usersFuture, classesFuture]);
      final users = results[0] as List<WorkAssigneeModel>;
      final classes = results[1] as List<WorkAcademicClassModel>;

      if (mounted) {
        setState(() {
          _allUsers = users;
          _displayedUsers = users;
          _isLoadingUsers = false;

          _classesList = classes;
          _isLoadingClasses = false;
          if (classes.isNotEmpty) {
            _selectedClassId = classes.first.id;
            _selectedClassName = classes.first.name;
            if (classes.first.sections.isNotEmpty) {
              _selectedSectionId = classes.first.sections.first.id;
              _selectedSectionName = classes.first.sections.first.name;
            }
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingUsers = false;
          _isLoadingClasses = false;
        });
      }
    }
  }

  void _onSearchUserChanged(String val) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _filterUsers();
    });
  }

  void _filterUsers() {
    final query = _searchUserController.text.trim().toLowerCase();
    setState(() {
      _displayedUsers = _allUsers.where((u) {
        final matchesRole = _userRoleFilter == 'All' || u.role.toLowerCase() == _userRoleFilter.toLowerCase();
        final matchesDept = _userDeptFilter == 'All' || (u.department != null && u.department!.toLowerCase().contains(_userDeptFilter.toLowerCase()));
        final matchesQuery = query.isEmpty ||
            u.fullName.toLowerCase().contains(query) ||
            (u.email != null && u.email!.toLowerCase().contains(query)) ||
            (u.rollNumber != null && u.rollNumber!.contains(query)) ||
            (u.className != null && u.className!.toLowerCase().contains(query));
        return matchesRole && matchesDept && matchesQuery;
      }).toList();
    });
  }

  Future<void> _refreshPreview() async {
    setState(() => _isLoadingUsers = true);
    final api = ref.read(workApiServiceProvider);
    try {
      List<WorkAssigneeModel> res = [];
      if (_assignmentMode == 'ROLE') {
        res = await api.previewAssignees(
          assignmentMode: 'ROLE',
          targetRole: _selectedRole,
          department: _selectedRoleDept != 'All' ? _selectedRoleDept : null,
          q: _searchUserController.text.trim(),
        );
      } else if (_assignmentMode == 'CLASS_SECTION') {
        res = await api.previewAssignees(
          assignmentMode: 'CLASS_SECTION',
          targetRole: _targetClassRole,
          classId: _selectedClassId,
          className: _selectedClassName,
          sectionId: _selectedSectionId,
          sectionName: _selectedSectionName,
          q: _searchUserController.text.trim(),
        );
      } else {
        res = await api.getAssignableUsers(
          q: _searchUserController.text.trim(),
          role: _userRoleFilter != 'All' ? _userRoleFilter : null,
          department: _userDeptFilter != 'All' ? _userDeptFilter : null,
          limit: 150,
        );
      }

      if (mounted) {
        setState(() {
          _displayedUsers = res;
          _isLoadingUsers = false;
          // In Class/Section and Role modes, by default select all previewed users
          if (_assignmentMode == 'CLASS_SECTION' || _assignmentMode == 'ROLE') {
            for (final u in res) {
              final uid = u.userId.isNotEmpty ? u.userId : u.id;
              _selectedUserIds.add(uid);
              _selectedUsersMap[uid] = u;
            }
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingUsers = false);
    }
  }

  void _toggleUserSelection(WorkAssigneeModel user) {
    final uid = user.userId.isNotEmpty ? user.userId : user.id;
    setState(() {
      if (_selectedUserIds.contains(uid)) {
        _selectedUserIds.remove(uid);
        _selectedUsersMap.remove(uid);
      } else {
        _selectedUserIds.add(uid);
        _selectedUsersMap[uid] = user;
      }
    });
  }

  void _selectAllDisplayedUsers() {
    setState(() {
      for (final u in _displayedUsers) {
        final uid = u.userId.isNotEmpty ? u.userId : u.id;
        _selectedUserIds.add(uid);
        _selectedUsersMap[uid] = u;
      }
    });
  }

  void _clearSelectedUsers() {
    setState(() {
      _selectedUserIds.clear();
      _selectedUsersMap.clear();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final api = ref.read(workApiServiceProvider);

    final payload = {
      'title': _titleController.text.trim(),
      'description': _descController.text.trim(),
      'work_type': _workType,
      'priority': _priority,
      'category': _category,
      'board_id': widget.boardId,
      'sprint_id': widget.sprintId,
      'parent_id': widget.parentId,
      'estimated_hours': double.tryParse(_estimateController.text.trim()) ?? 0.0,
      'story_points': double.tryParse(_pointsController.text.trim()) ?? 0.0,
      'start_date': _startDate?.toIso8601String().substring(0, 10),
      'due_date': _dueDate?.toIso8601String().substring(0, 10),
      'assignee_ids': _selectedUserIds.toList(),
      'assignment_mode': _assignmentMode,
      'target_role': _assignmentMode == 'ROLE' ? _selectedRole : (_assignmentMode == 'CLASS_SECTION' ? _targetClassRole : null),
      'class_id': _assignmentMode == 'CLASS_SECTION' ? _selectedClassId : null,
      'class_name': _assignmentMode == 'CLASS_SECTION' ? _selectedClassName : null,
      'section_id': _assignmentMode == 'CLASS_SECTION' ? _selectedSectionId : null,
      'section_name': _assignmentMode == 'CLASS_SECTION' ? _selectedSectionName : null,
      'is_class_wide': _assignmentMode == 'CLASS_SECTION',
      'labels': _tagsController.text.isNotEmpty
          ? _tagsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
          : [],
      // Academic
      'subject_name': _subjectController.text.trim().isNotEmpty ? _subjectController.text.trim() : null,
      'max_marks': double.tryParse(_maxMarksController.text.trim()),
    };

    final result = await api.createWorkItem(payload);
    if (result.isNotEmpty && result['success'] == true) {
      ref.read(workBoardProvider.notifier).loadBoard();
      ref.read(workListProvider.notifier).loadPagedItems();
      ref.read(workBacklogProvider.notifier).loadBacklog();
      ref.read(workSprintDashboardProvider.notifier).loadSprintDashboard();
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Created ${result['item_number'] ?? 'Work Item'} successfully assigned to ${_selectedUserIds.length} member(s)!',
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save work item. Please verify fields and try again.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
      case 'super_admin':
        return const Color(0xFF8B5CF6); // Purple
      case 'teacher':
        return const Color(0xFF10B981); // Emerald
      case 'student':
        return const Color(0xFF3B82F6); // Blue
      case 'staff':
      case 'support':
        return const Color(0xFFF59E0B); // Amber
      case 'hostel':
        return const Color(0xFF14B8A6); // Teal
      case 'security':
        return const Color(0xFFF97316); // Orange
      default:
        return const Color(0xFF64748B); // Slate
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toUpperCase()) {
      case 'TASK':
        return const Color(0xFF2563EB);
      case 'STORY':
        return const Color(0xFF059669);
      case 'BUG':
        return const Color(0xFFE11D48);
      case 'EPIC':
        return const Color(0xFF7C3AED);
      case 'HOMEWORK':
        return const Color(0xFF4F46E5);
      case 'ASSIGNMENT':
        return const Color(0xFF6366F1);
      default:
        return const Color(0xFF0284C7);
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toUpperCase()) {
      case 'TASK':
        return Icons.check_circle_outline_rounded;
      case 'STORY':
        return Icons.bookmark_border_rounded;
      case 'BUG':
        return Icons.bug_report_outlined;
      case 'EPIC':
        return Icons.stars_rounded;
      case 'HOMEWORK':
        return Icons.menu_book_rounded;
      case 'ASSIGNMENT':
        return Icons.assignment_outlined;
      default:
        return Icons.work_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 820;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 980,
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // 1. Top Header Bar
              _buildTopHeader(isDark),

              // 2. Type Selector Pills Bar
              _buildTypeSelectorBar(isDark),

              const Divider(height: 1, color: Color(0xFF334155)),

              // 3. Main Content: 2-Column Split
              Expanded(
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column: Work Specifications (54%)
                          Expanded(
                            flex: 54,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(22),
                              child: _buildSpecificationsColumn(isDark),
                            ),
                          ),
                          VerticalDivider(
                            width: 1,
                            thickness: 1,
                            color: isDark ? const Color(0xFF13182C) : const Color(0xFFE2E8F0),
                          ),
                          // Right Column: Smart Assignment Engine (46%)
                          Expanded(
                            flex: 46,
                            child: Padding(
                              padding: const EdgeInsets.all(22),
                              child: _buildAssignmentEngineColumn(isDark),
                            ),
                          ),
                        ],
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            _buildSpecificationsColumn(isDark),
                            const SizedBox(height: 24),
                            const Divider(),
                            _buildAssignmentEngineColumn(isDark),
                          ],
                        ),
                      ),
              ),

              const Divider(height: 1, color: Color(0xFF334155)),

              // 4. Footer Summary & Action Buttons
              _buildFooter(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 16, 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13182C) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: _getTypeColor(_workType).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_getTypeIcon(_workType), color: _getTypeColor(_workType), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.existingItem != null ? 'Edit Work Item' : 'Create New Work Item',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getTypeColor(_workType).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _getTypeColor(_workType).withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _workType,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _getTypeColor(_workType),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Enterprise Work Management • Define specifications, effort & dispatch to audience',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelectorBar(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: isDark ? const Color(0xFF131D31) : const Color(0xFFF1F5F9),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text(
              'Work Type',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 12),
            ..._types.map((type) {
            final isSelected = _workType == type;
            final color = _getTypeColor(type);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () => setState(() {
                  _workType = type;
                  if (type == 'HOMEWORK' || type == 'ASSIGNMENT') {
                    _category = 'Academic';
                    _assignmentMode = 'CLASS_SECTION';
                    _refreshPreview();
                  }
                }),
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? color : (isDark ? const Color(0xFF13182C) : Colors.white),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? color : (isDark ? const Color(0xFF1F293D) : const Color(0xFFCBD5E1)),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getTypeIcon(type),
                        size: 15,
                        color: isSelected ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        type,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecificationsColumn(bool isDark) {
    final isAcademic = _workType == 'HOMEWORK' || _workType == 'ASSIGNMENT' || _category == 'Academic';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Work Item Specifications', Icons.tune_rounded, isDark),
        const SizedBox(height: 14),

        // Title
        _buildLabel('Title *', isDark),
        const SizedBox(height: 6),
        TextFormField(
          controller: _titleController,
          validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black),
          decoration: _inputDecoration(
            'e.g., Prepare and submit Unit-3 Mathematics Assignment',
            isDark,
            prefixIcon: Icons.title_rounded,
          ),
        ),
        const SizedBox(height: 16),

        // Description
        Row(
          children: [
            Expanded(child: _buildLabel('Description', isDark)),
            _buildTemplateSnippet('Acceptance Criteria', isDark),
            const SizedBox(width: 6),
            _buildTemplateSnippet('Steps', isDark),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _descController,
          maxLines: 4,
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black),
          decoration: _inputDecoration(
            'Detailed instructions, deliverables, requirements or acceptance criteria...',
            isDark,
          ),
        ),
        const SizedBox(height: 18),

        // Priority & Category Row
        Row(
          children: [
            Expanded(
              child: _buildPriorityDropdown(isDark),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildDropdown(
                label: 'Category',
                value: _categories.contains(_category) ? _category : _categories.first,
                items: _categories,
                onChanged: (v) => setState(() => _category = v!),
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Effort & Story Points
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Story Points', isDark),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _pointsController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black),
                    decoration: _inputDecoration('e.g., 5', isDark, prefixIcon: Icons.star_border_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Estimated Hours', isDark),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _estimateController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black),
                    decoration: _inputDecoration('e.g., 16', isDark, prefixIcon: Icons.schedule_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Start Date & Due Date Row
        Row(
          children: [
            Expanded(
              child: _buildDatePicker(
                label: 'Start Date',
                selectedDate: _startDate,
                onSelect: (d) => setState(() => _startDate = d),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildDatePicker(
                label: 'Due Date',
                selectedDate: _dueDate,
                onSelect: (d) => setState(() => _dueDate = d),
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Academic Extra Fields
        if (isAcademic) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF13182C).withValues(alpha: 0.6) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.school_rounded, color: Color(0xFF3B82F6), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Academic Evaluation Specifications',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Subject', isDark),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _subjectController,
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black),
                            decoration: _inputDecoration('e.g. Mathematics', isDark),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Max Marks', isDark),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _maxMarksController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black),
                            decoration: _inputDecoration('e.g. 50', isDark),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Tags / Labels
        _buildLabel('Tags / Labels (comma separated)', isDark),
        const SizedBox(height: 6),
        TextFormField(
          controller: _tagsController,
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black),
          decoration: _inputDecoration('e.g., Mathematics, Homework, Term-1', isDark, prefixIcon: Icons.local_offer_outlined),
        ),
      ],
    );
  }

  Widget _buildAssignmentEngineColumn(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Smart Assignment Engine', Icons.group_add_rounded, isDark),
        const SizedBox(height: 12),

        // Assignment Mode Segmented Control
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF13182C) : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              _buildModeSegment('INDIVIDUAL', 'Individual Users', Icons.person_rounded, isDark),
              _buildModeSegment('ROLE', 'By Role / Group', Icons.badge_rounded, isDark),
              _buildModeSegment('CLASS_SECTION', 'Class & Section', Icons.school_rounded, isDark),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Mode-specific configuration view
        if (_assignmentMode == 'INDIVIDUAL') _buildIndividualAssignmentControls(isDark),
        if (_assignmentMode == 'ROLE') _buildRoleAssignmentControls(isDark),
        if (_assignmentMode == 'CLASS_SECTION') _buildClassSectionAssignmentControls(isDark),

        const SizedBox(height: 12),

        // Roster / User List Header
        Row(
          children: [
            Expanded(
              child: Text(
                '${_assignmentMode == 'CLASS_SECTION' ? 'Student Roster' : (_assignmentMode == 'ROLE' ? 'Role Members' : 'Assignable Users')} (${_displayedUsers.length})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: _selectAllDisplayedUsers,
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2)),
              child: const Text('Select All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ),
            TextButton(
              onPressed: _clearSelectedUsers,
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2)),
              child: const Text('Clear', style: TextStyle(fontSize: 11, color: Color(0xFFEF4444))),
            ),
          ],
        ),

        // User Selection List
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF13182C).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFCBD5E1)),
            ),
            child: _isLoadingUsers
                ? const Center(child: CircularProgressIndicator())
                : _displayedUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded, size: 36, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                            const SizedBox(height: 8),
                            Text(
                              'No matching users found',
                              style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _displayedUsers.length,
                        itemBuilder: (context, index) {
                          final user = _displayedUsers[index];
                          final uid = user.userId.isNotEmpty ? user.userId : user.id;
                          final isSelected = _selectedUserIds.contains(uid);
                          final roleColor = _getRoleColor(user.role);

                          return InkWell(
                            onTap: () => _toggleUserSelection(user),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isDark ? const Color(0xFF2563EB).withValues(alpha: 0.15) : const Color(0xFFEFF6FF))
                                    : Colors.transparent,
                                border: Border(
                                  bottom: BorderSide(
                                    color: isDark ? const Color(0xFF1F293D).withValues(alpha: 0.5) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: isSelected,
                                    onChanged: (_) => _toggleUserSelection(user),
                                    activeColor: const Color(0xFF2563EB),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  ),
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: roleColor.withValues(alpha: 0.2),
                                    backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                                    child: user.avatarUrl == null
                                        ? Text(
                                            user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: roleColor),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.fullName,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Row(
                                          children: [
                                            if (user.email != null)
                                              Expanded(
                                                child: Text(
                                                  user.email!,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            if (user.className != null)
                                              Text(
                                                'Class: ${user.className}',
                                                style: const TextStyle(fontSize: 10, color: Color(0xFF3B82F6), fontWeight: FontWeight.w600),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: roleColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: roleColor.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      user.role.toUpperCase(),
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: roleColor),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ),

        // Selected Chips Summary
        if (_selectedUserIds.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Selected (${_selectedUserIds.length} assignees):',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _selectedUsersMap.values.map((u) {
                final roleColor = _getRoleColor(u.role);
                return Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: roleColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        u.fullName,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: roleColor),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => _toggleUserSelection(u),
                        child: Icon(Icons.close_rounded, size: 14, color: roleColor),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildModeSegment(String mode, String label, IconData icon, bool isDark) {
    final isSelected = _assignmentMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _assignmentMode = mode);
          _refreshPreview();
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? (isDark ? const Color(0xFF2563EB) : Colors.white) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected && !isDark ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))] : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIndividualAssignmentControls(bool isDark) {
    return Column(
      children: [
        // Search bar
        TextField(
          controller: _searchUserController,
          onChanged: _onSearchUserChanged,
          style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black),
          decoration: _inputDecoration(
            'Search any user by name, email, roll number...',
            isDark,
            prefixIcon: Icons.search_rounded,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildFilterDropdown(
                label: 'Role',
                value: _userRoleFilter,
                items: ['All', ..._rolesList],
                onChanged: (v) {
                  setState(() => _userRoleFilter = v!);
                  _filterUsers();
                },
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildFilterDropdown(
                label: 'Department',
                value: _userDeptFilter,
                items: ['All', 'Academics', 'IT Services', 'Administration', 'Facilities'],
                onChanged: (v) {
                  setState(() => _userDeptFilter = v!);
                  _filterUsers();
                },
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoleAssignmentControls(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flash_on_rounded, color: Color(0xFF8B5CF6), size: 16),
              const SizedBox(width: 8),
              Text(
                'Bulk Role Assignment Engine',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Assign this work item to all institutional members holding the selected role.',
            style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  label: 'Target Role',
                  value: _selectedRole,
                  items: _rolesList,
                  onChanged: (v) {
                    setState(() => _selectedRole = v!);
                    _refreshPreview();
                  },
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFilterDropdown(
                  label: 'Department (Optional)',
                  value: _selectedRoleDept,
                  items: ['All', 'Academics', 'IT Services', 'Administration', 'Facilities'],
                  onChanged: (v) {
                    setState(() => _selectedRoleDept = v!);
                    _refreshPreview();
                  },
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClassSectionAssignmentControls(bool isDark) {
    // Current class sections
    final currentClass = _classesList.firstWhere(
      (c) => c.id == _selectedClassId,
      orElse: () => _classesList.isNotEmpty
          ? _classesList.first
          : const WorkAcademicClassModel(id: '', name: 'Class 10', sections: []),
    );
    final sections = currentClass.sections;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school_rounded, color: Color(0xFF3B82F6), size: 16),
              const SizedBox(width: 8),
              Text(
                'Academic Class & Section Assignment',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'All enrolled students in the selected class and section will automatically receive this work.',
            style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Class dropdown
              Expanded(
                child: _isLoadingClasses
                    ? const LinearProgressIndicator()
                    : _buildClassDropdown(isDark),
              ),
              const SizedBox(width: 8),
              // Section dropdown
              Expanded(
                child: _buildSectionDropdown(sections, isDark),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Target Role within Class
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  label: 'Target Audience in Class',
                  value: _targetClassRole,
                  items: ['student', 'teacher'],
                  onChanged: (v) {
                    setState(() => _targetClassRole = v!);
                    _refreshPreview();
                  },
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClassDropdown(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Class', isDark),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _classesList.any((c) => c.id == _selectedClassId) ? _selectedClassId : (_classesList.isNotEmpty ? _classesList.first.id : null),
              isExpanded: true,
              dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
              icon: const Icon(Icons.arrow_drop_down_rounded),
              items: _classesList.map((c) {
                return DropdownMenuItem<String>(
                  value: c.id,
                  child: Text(
                    c.name,
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val == null) return;
                final cls = _classesList.firstWhere((c) => c.id == val);
                setState(() {
                  _selectedClassId = cls.id;
                  _selectedClassName = cls.name;
                  if (cls.sections.isNotEmpty) {
                    _selectedSectionId = cls.sections.first.id;
                    _selectedSectionName = cls.sections.first.name;
                  } else {
                    _selectedSectionId = null;
                    _selectedSectionName = null;
                  }
                });
                _refreshPreview();
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionDropdown(List<WorkAcademicSectionModel> sections, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Section', isDark),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: sections.any((s) => s.id == _selectedSectionId)
                  ? _selectedSectionId
                  : (sections.isNotEmpty ? sections.first.id : null),
              isExpanded: true,
              dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
              icon: const Icon(Icons.arrow_drop_down_rounded),
              items: sections.map((s) {
                return DropdownMenuItem<String>(
                  value: s.id,
                  child: Text(
                    s.name,
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val == null) return;
                final sec = sections.firstWhere((s) => s.id == val);
                setState(() {
                  _selectedSectionId = sec.id;
                  _selectedSectionName = sec.name;
                });
                _refreshPreview();
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13182C) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        children: [
          // Dynamic Summary Badge
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _assignmentMode == 'CLASS_SECTION' ? Icons.school_rounded : Icons.people_alt_rounded,
                  size: 14,
                  color: const Color(0xFF3B82F6),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Assigning to ${_selectedUserIds.length} member(s)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 2,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.existingItem != null ? Icons.save_rounded : Icons.add_task_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        widget.existingItem != null ? 'Update Work Item' : 'Create Work Item',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // --- Reusable UI Helpers ---

  Widget _buildSectionTitle(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF2563EB)),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
      ),
    );
  }

  Widget _buildTemplateSnippet(String label, bool isDark) {
    return InkWell(
      onTap: () {
        if (label == 'Acceptance Criteria') {
          _descController.text += '\n\nAcceptance Criteria:\n- [ ] Deliverable verified\n- [ ] Quality criteria satisfied';
        } else if (label == 'Steps to Reproduce') {
          _descController.text += '\n\nSteps to Reproduce:\n1. Navigate to module\n2. Perform action\n3. Observed behavior';
        }
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF13182C) : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '+ $label',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityDropdown(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Priority', isDark),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _priorities.contains(_priority) ? _priority : 'MEDIUM',
              isExpanded: true,
              dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
              items: _priorities.map((p) {
                Color pColor;
                switch (p) {
                  case 'CRITICAL':
                    pColor = const Color(0xFFEF4444);
                    break;
                  case 'URGENT':
                    pColor = const Color(0xFFF97316);
                    break;
                  case 'HIGH':
                    pColor = const Color(0xFFF59E0B);
                    break;
                  case 'LOW':
                    pColor = const Color(0xFF64748B);
                    break;
                  default:
                    pColor = const Color(0xFF3B82F6);
                }
                return DropdownMenuItem<String>(
                  value: p,
                  child: Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: pColor, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(p, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: pColor)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (v) => setState(() => _priority = v!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label, isDark),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : items.first,
              isExpanded: true,
              dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
              items: items.map((e) {
                return DropdownMenuItem<String>(
                  value: e,
                  child: Text(e, style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black)),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label, isDark),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : items.first,
              isExpanded: true,
              dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
              items: items.map((e) {
                return DropdownMenuItem<String>(
                  value: e,
                  child: Text(
                    e.toUpperCase(),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime? selectedDate,
    required ValueChanged<DateTime> onSelect,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label, isDark),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (picked != null) onSelect(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFCBD5E1)),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                const SizedBox(width: 8),
                Text(
                  selectedDate != null
                      ? '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}'
                      : 'Select Date',
                  style: TextStyle(
                    fontSize: 12,
                    color: selectedDate != null ? (isDark ? Colors.white : Colors.black) : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint, bool isDark, {IconData? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 16, color: const Color(0xFF94A3B8)) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      filled: true,
      fillColor: isDark ? const Color(0xFF13182C) : const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
    );
  }
}
