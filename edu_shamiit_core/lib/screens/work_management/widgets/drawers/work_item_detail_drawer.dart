import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../config/app_config.dart';
import '../../../../utils/download_helper.dart';
import '../../models/work_models.dart';
import '../../providers/work_management_provider.dart';
import '../../utils/work_filter_helper.dart';

class WorkItemDetailDrawer extends ConsumerStatefulWidget {
  final WorkItemModel? item;
  final VoidCallback onClose;
  final Function(WorkItemModel updatedItem)? onUpdated;

  const WorkItemDetailDrawer({
    super.key,
    required this.item,
    required this.onClose,
    this.onUpdated,
  });

  @override
  ConsumerState<WorkItemDetailDrawer> createState() => _WorkItemDetailDrawerState();
}

class _WorkItemDetailDrawerState extends ConsumerState<WorkItemDetailDrawer>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _newChecklistController = TextEditingController();
  final TextEditingController _newLabelController = TextEditingController();

  // Effort controllers
  late TextEditingController _storyPointsController;
  late TextEditingController _estimatedHoursController;
  late TextEditingController _remainingHoursController;
  late TextEditingController _actualHoursController;

  Map<String, dynamic>? _fullDetail;
  bool _isLoading = false;
  bool _isSavingEffort = false;
  bool _isAddingComment = false;
  bool _isCopying = false;
  bool _isDeleting = false;
  bool _showAddChecklistInput = false;
  bool _isAddingChecklist = false;
  bool _showAddLabelInput = false;

  List<WorkBoardModel> _boards = [];
  List<WorkSprintModel> _sprints = [];
  List<WorkAssigneeModel> _assignableUsers = [];
  List<String> _teamsList = WorkFilterHelper.defaultTeams;

  String? _selectedBoardId;
  String? _selectedSprintId;
  String? _selectedTeamName;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initEffortControllers(widget.item);
    if (widget.item != null) {
      _loadDetail(widget.item!.id);
      _loadContextData();
    }
  }

  void _initEffortControllers(WorkItemModel? item) {
    _storyPointsController = TextEditingController(text: item?.storyPoints.toString() ?? '0');
    _estimatedHoursController = TextEditingController(text: item?.estimatedHours.toString() ?? '0');
    _remainingHoursController = TextEditingController(text: item?.remainingHours.toString() ?? '0');
    _actualHoursController = TextEditingController(text: item?.actualHours.toString() ?? '0');
  }

  @override
  void didUpdateWidget(covariant WorkItemDetailDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item?.id != oldWidget.item?.id && widget.item != null) {
      _fullDetail = null;
      _showAddChecklistInput = false;
      _showAddLabelInput = false;
      _selectedTeamName = widget.item?.teamName;
      _initEffortControllers(widget.item);
      _loadDetail(widget.item!.id);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _commentController.dispose();
    _newChecklistController.dispose();
    _newLabelController.dispose();
    _storyPointsController.dispose();
    _estimatedHoursController.dispose();
    _remainingHoursController.dispose();
    _actualHoursController.dispose();
    super.dispose();
  }

  WorkItemModel? get _effectiveItem {
    if (_fullDetail != null && _fullDetail!.isNotEmpty) {
      try {
        return WorkItemModel.fromJson(_fullDetail!);
      } catch (_) {}
    }
    return widget.item;
  }

  Future<void> _loadContextData() async {
    final api = ref.read(workApiServiceProvider);
    try {
      final teams = await WorkFilterHelper.fetchTeamNames(api);
      if (mounted && teams.isNotEmpty) {
        setState(() => _teamsList = teams);
      }
    } catch (_) {}
    try {
      final boards = await api.getBoards();
      if (mounted) setState(() => _boards = boards);
    } catch (_) {}
    try {
      final sprints = await api.getSprints();
      if (mounted) setState(() => _sprints = sprints);
    } catch (_) {}
    try {
      final users = await api.getAssignableUsers(limit: 200);
      if (mounted) setState(() => _assignableUsers = users);
    } catch (_) {}
  }

  Future<void> _loadDetail(String itemId, {bool notifyParent = false}) async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(workApiServiceProvider);
      final detail = await api.getWorkItemDetail(itemId);
      if (mounted) {
        setState(() {
          _fullDetail = detail;
          _isLoading = false;

          if (detail.isNotEmpty) {
            final sp = (detail['story_points'] as num?)?.toDouble() ?? 0.0;
            final est = (detail['estimated_hours'] as num?)?.toDouble() ?? 0.0;
            final rem = (detail['remaining_hours'] as num?)?.toDouble() ?? 0.0;
            final act = (detail['actual_hours'] as num?)?.toDouble() ?? 0.0;

            _storyPointsController.text = sp > 0 ? sp.toString() : '0';
            _estimatedHoursController.text = est.toString();
            _remainingHoursController.text = rem.toString();
            _actualHoursController.text = act.toString();

            _selectedBoardId = detail['board_id']?.toString();
            _selectedSprintId = detail['sprint_id']?.toString();
            final teamFromDetail = detail['team_name']?.toString() ?? detail['team']?.toString();
            if (teamFromDetail != null && teamFromDetail.isNotEmpty && teamFromDetail.toLowerCase() != 'null') {
              _selectedTeamName = teamFromDetail;
              if (!_teamsList.contains(teamFromDetail)) {
                _teamsList = [..._teamsList, teamFromDetail];
              }
            } else if (detail.containsKey('team_name') && detail['team_name'] == null) {
              _selectedTeamName = null;
            }
          }
        });
        if (notifyParent && detail.isNotEmpty && widget.onUpdated != null) {
          widget.onUpdated!(WorkItemModel.fromJson(detail));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _refreshAllProviders() {
    ref.read(workBoardProvider.notifier).loadBoard(forceRefresh: true);
    ref.read(workListProvider.notifier).loadPagedItems(forceRefresh: true);
    ref.read(workBacklogProvider.notifier).loadBacklog(forceRefresh: true);
    ref.read(workSprintDashboardProvider.notifier).loadSprintDashboard(forceRefresh: true);
    ref.read(allSprintsProvider.notifier).loadSprints(forceRefresh: true);
    ref.read(workOverviewProvider.notifier).loadOverview();
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F172A),
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 12.5)),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toUpperCase()) {
      case 'STORY':
        return const Color(0xFF8B5CF6);
      case 'BUG':
        return const Color(0xFFEF4444);
      case 'EPIC':
        return const Color(0xFF2563EB);
      case 'HOMEWORK':
      case 'ASSIGNMENT':
        return const Color(0xFF10B981);
      case 'TASK':
      default:
        return const Color(0xFF3B82F6);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return const Color(0xFF8B5CF6);
      case 'RESOLVED':
        return const Color(0xFF10B981);
      case 'ACTIVE':
      case 'IN PROGRESS':
        return const Color(0xFF3B82F6);
      case 'NEW':
      default:
        return const Color(0xFF64748B);
    }
  }

  int _calculateEffortProgress(double actual, double remaining) {
    if (actual + remaining <= 0) return 0;
    final progress = ((actual / (actual + remaining)) * 100).round();
    return progress.clamp(0, 100);
  }

  Future<void> _updateFields(Map<String, dynamic> payload, {String? successMessage}) async {
    final item = _effectiveItem;
    if (item == null) return;
    final api = ref.read(workApiServiceProvider);

    if (payload.containsKey('team_name')) {
      final t = payload['team_name']?.toString();
      _selectedTeamName = (t == null || t == 'UNASSIGN' || t == 'Unassigned') ? null : t;
    }

    final ok = await api.updateItem(item.id, payload);
    if (ok) {
      await _loadDetail(item.id, notifyParent: true);
      _refreshAllProviders();
      if (successMessage != null) {
        _showSnack(successMessage);
      }
    } else {
      _showSnack('Failed to update work item.', isError: true);
    }
  }

  Future<void> _saveEffort() async {
    final item = _effectiveItem;
    if (item == null) return;
    setState(() => _isSavingEffort = true);

    try {
      final sp = double.tryParse(_storyPointsController.text) ?? 0.0;
      final est = double.tryParse(_estimatedHoursController.text) ?? 0.0;
      final rem = double.tryParse(_remainingHoursController.text) ?? 0.0;
      final act = double.tryParse(_actualHoursController.text) ?? 0.0;

      final progress = _calculateEffortProgress(act, rem);
      await _updateFields(
        {
          'story_points': sp,
          'estimated_hours': est,
          'remaining_hours': rem,
          'actual_hours': act,
          'progress_percentage': progress,
        },
        successMessage: 'Updated effort: $act hrs actual, $rem hrs remaining ($progress% progress)',
      );
    } catch (_) {}

    if (mounted) {
      setState(() => _isSavingEffort = false);
    }
  }

  // ==========================================
  // ASSIGNEE MANAGEMENT CRUD
  // ==========================================
  Future<void> _openManageAssigneesDialog(WorkItemModel item) async {
    if (_assignableUsers.isEmpty) {
      await _loadContextData();
    }
    if (!mounted) return;

    final selectedIds = item.assignees
        .map((a) => a.userId.isNotEmpty ? a.userId : a.id)
        .where((id) => id.isNotEmpty)
        .toSet();
    final searchCtrl = TextEditingController();
    String roleFilter = 'All';
    bool isSaving = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            final q = searchCtrl.text.trim().toLowerCase();
            final filteredUsers = _assignableUsers.where((u) {
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
                width: 480,
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
                                    '${u.role.toUpperCase()}${u.department != null && u.department!.isNotEmpty ? ' • ${u.department}' : ''}${u.email != null ? ' • ${u.email}' : ''}',
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
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
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
                          Navigator.pop(ctx, true);
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

    if (saved == true) {
      await _updateFields(
        {'assignee_ids': selectedIds.toList()},
        successMessage: 'Updated assignees (${selectedIds.length} assigned)',
      );
    }
  }

  Future<void> _removeSingleAssignee(WorkItemModel item, String userIdToRemove) async {
    final remaining = item.assignees
        .map((a) => a.userId.isNotEmpty ? a.userId : a.id)
        .where((id) => id.isNotEmpty && id != userIdToRemove)
        .toList();
    await _updateFields(
      {'assignee_ids': remaining},
      successMessage: 'Removed assignee',
    );
  }

  // ==========================================
  // CHECKLIST FULL CRUD
  // ==========================================
  Future<void> _addChecklistItem() async {
    final item = _effectiveItem;
    final text = _newChecklistController.text.trim();
    if (item == null || text.isEmpty) return;

    setState(() => _isAddingChecklist = true);
    final api = ref.read(workApiServiceProvider);
    final res = await api.addChecklistEntry(item.id, text);
    if (mounted) {
      setState(() => _isAddingChecklist = false);
    }

    if (res['success'] == true) {
      _newChecklistController.clear();
      setState(() => _showAddChecklistInput = false);
      await _loadDetail(item.id, notifyParent: true);
      _refreshAllProviders();
      _showSnack('Checklist item added');
    } else {
      _showSnack(res['error']?.toString() ?? 'Failed to add checklist item', isError: true);
    }
  }

  Future<void> _toggleChecklist(String checkId, bool currentVal) async {
    final item = _effectiveItem;
    if (item == null) return;
    final api = ref.read(workApiServiceProvider);
    final ok = await api.toggleChecklistEntry(checkId, !currentVal);
    if (ok) {
      await _loadDetail(item.id, notifyParent: true);
      _refreshAllProviders();
    }
  }

  Future<void> _editChecklistDialog(String checkId, String currentTitle) async {
    final item = _effectiveItem;
    if (item == null) return;
    final ctrl = TextEditingController(text: currentTitle);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Edit Checklist Item', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              hintText: 'Checklist title...',
              filled: true,
              fillColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmed == true && ctrl.text.trim().isNotEmpty) {
      final api = ref.read(workApiServiceProvider);
      final ok = await api.updateChecklistEntry(checkId, title: ctrl.text.trim());
      if (ok) {
        await _loadDetail(item.id, notifyParent: true);
        _showSnack('Checklist item updated');
      }
    }
  }

  Future<void> _deleteChecklist(String checkId) async {
    final item = _effectiveItem;
    if (item == null) return;
    final api = ref.read(workApiServiceProvider);
    final ok = await api.deleteChecklistEntry(checkId);
    if (ok) {
      await _loadDetail(item.id, notifyParent: true);
      _refreshAllProviders();
      _showSnack('Checklist item deleted');
    }
  }

  // ==========================================
  // LABELS & TITLE/DESCRIPTION EDIT & DELETE
  // ==========================================
  Future<void> _addLabel(List<dynamic> currentLabels) async {
    final text = _newLabelController.text.trim();
    if (text.isEmpty) return;
    final updated = [
      ...currentLabels.map((l) => l is Map ? (l['name']?.toString() ?? '') : l.toString()),
      text,
    ].where((s) => s.isNotEmpty).toSet().toList();
    _newLabelController.clear();
    setState(() => _showAddLabelInput = false);
    await _updateFields({'labels': updated}, successMessage: 'Label "$text" added');
  }

  Future<void> _removeLabel(List<dynamic> currentLabels, String toRemove) async {
    final updated = currentLabels
        .map((l) => l is Map ? (l['name']?.toString() ?? '') : l.toString())
        .where((s) => s.isNotEmpty && s != toRemove)
        .toList();
    await _updateFields({'labels': updated});
  }

  Future<void> _editTitleDescDialog(WorkItemModel item) async {
    final titleCtrl = TextEditingController(text: item.title);
    final descCtrl = TextEditingController(text: item.description);
    final catCtrl = TextEditingController(text: item.category);
    String selectedType = item.workType.toUpperCase();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
              ),
              title: Text(
                'Edit ${item.itemNumber}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Title *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleCtrl,
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Work Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569))),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: ['EPIC', 'STORY', 'TASK', 'BUG', 'ISSUE', 'HOMEWORK', 'ASSIGNMENT'].contains(selectedType)
                                    ? selectedType
                                    : 'TASK',
                                isDense: true,
                                dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                items: const ['TASK', 'STORY', 'BUG', 'EPIC', 'ISSUE', 'HOMEWORK', 'ASSIGNMENT']
                                    .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12.5))))
                                    .toList(),
                                onChanged: (v) => setDlgState(() => selectedType = v ?? 'TASK'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Area / Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569))),
                              const SizedBox(height: 6),
                              TextField(
                                controller: catCtrl,
                                style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white : Colors.black),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descCtrl,
                      maxLines: 4,
                      style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    if (titleCtrl.text.trim().isNotEmpty) {
                      Navigator.pop(ctx, true);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                  child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true) {
      await _updateFields(
        {
          'title': titleCtrl.text.trim(),
          'description': descCtrl.text.trim(),
          'category': catCtrl.text.trim(),
          'work_type': selectedType,
        },
        successMessage: 'Saved changes to ${item.itemNumber}',
      );
    }
  }

  Future<void> _deleteWorkItemDialog(WorkItemModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444), size: 22),
              SizedBox(width: 8),
              Text('Delete Work Item?', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
            ],
          ),
          content: Text(
            'Are you sure you want to delete "${item.itemNumber}: ${item.title}"? This will archive the work item from active views.',
            style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      setState(() => _isDeleting = true);
      final api = ref.read(workApiServiceProvider);
      final ok = await api.deleteItem(item.id);
      if (mounted) setState(() => _isDeleting = false);

      if (ok) {
        _refreshAllProviders();
        _showSnack('Deleted ${item.itemNumber}');
        widget.onClose();
      } else {
        _showSnack('Failed to delete ${item.itemNumber}', isError: true);
      }
    }
  }

  Future<void> _pickAndUpdateDate({required bool isStart}) async {
    final item = _effectiveItem;
    if (item == null) return;
    final existingStr = isStart ? item.startDate : item.dueDate;
    final initial = (existingStr != null && existingStr.length >= 10)
        ? (DateTime.tryParse(existingStr.substring(0, 10)) ?? DateTime.now())
        : DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      final iso = picked.toIso8601String().substring(0, 10);
      await _updateFields(
        {isStart ? 'start_date' : 'due_date': iso},
        successMessage: '${isStart ? 'Start date' : 'Due date'} set to $iso',
      );
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    final item = _effectiveItem;
    if (text.isEmpty || item == null) return;

    setState(() => _isAddingComment = true);
    final api = ref.read(workApiServiceProvider);
    final ok = await api.addComment(item.id, text);
    if (ok) {
      _commentController.clear();
      await _loadDetail(item.id, notifyParent: true);
    }
    if (mounted) {
      setState(() => _isAddingComment = false);
    }
  }

  Future<void> _changeStatus(String newStatus) async {
    final item = _effectiveItem;
    if (item == null) return;
    await ref.read(workBoardProvider.notifier).transitionStatus(item.id, newStatus);
    await _loadDetail(item.id, notifyParent: true);
    _refreshAllProviders();
    _showSnack('Status changed to $newStatus');
  }

  Future<void> _copyWorkItemDialog() async {
    final item = _effectiveItem;
    if (item == null) return;

    final titleController = TextEditingController(text: 'Copy of ${item.title}');
    bool includeChildren = true;
    bool includeAttachments = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Row(
                children: [
                  const Icon(Icons.copy_rounded, color: Color(0xFF2563EB), size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Create Copy of ${item.workType}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Clone this work item with its configuration, tags, and effort values.',
                      style: TextStyle(fontSize: 12.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),
                    Text('New Title', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF334155))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleController,
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    CheckboxListTile(
                      value: includeChildren,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                      title: const Text('Include child tasks / sub-items', style: TextStyle(fontSize: 12.5)),
                      onChanged: (v) => setDlgState(() => includeChildren = v ?? true),
                    ),
                    CheckboxListTile(
                      value: includeAttachments,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                      title: const Text('Include document attachments', style: TextStyle(fontSize: 12.5)),
                      onChanged: (v) => setDlgState(() => includeAttachments = v ?? true),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.white),
                  label: const Text('Create Copy', style: TextStyle(color: Colors.white)),
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

    if (confirmed == true) {
      setState(() => _isCopying = true);
      final api = ref.read(workApiServiceProvider);
      final res = await api.copyWorkItem(
        item.id,
        newTitle: titleController.text.trim(),
        includeChildren: includeChildren,
        includeAttachments: includeAttachments,
      );
      if (mounted) setState(() => _isCopying = false);

      if (res['success'] == true) {
        _refreshAllProviders();
        _showSnack('Successfully created copy: ${res['item_number']} - ${res['title']}');
      }
    }
  }

  Future<void> _moveToBoard(String newBoardId) async {
    final item = _effectiveItem;
    if (item == null || newBoardId == _selectedBoardId) return;
    setState(() => _selectedBoardId = newBoardId);
    await _updateFields({'board_id': newBoardId}, successMessage: 'Moved to selected board');
  }

  Future<void> _moveToSprint(String? newSprintId) async {
    final item = _effectiveItem;
    if (item == null) return;
    setState(() => _selectedSprintId = newSprintId);
    await _updateFields(
      {'sprint_id': newSprintId},
      successMessage: newSprintId == null ? 'Moved to Backlog' : 'Moved to selected Sprint',
    );
  }

  // ==========================================
  // ATTACHMENTS: REAL LOCAL FILE UPLOAD + URL + DOWNLOAD + DELETE
  // ==========================================
  Future<void> _uploadAttachmentDialog() async {
    final item = _effectiveItem;
    if (item == null) return;

    Uint8List? pickedBytes;
    String? pickedFileName;
    int pickedSize = 0;
    bool useUrlMode = false;
    bool isUploading = false;
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();

    final didUpload = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
              ),
              title: Row(
                children: [
                  const Icon(Icons.upload_file_rounded, color: Color(0xFF2563EB), size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Attach Document',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
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
                    // Mode Switcher
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Upload Local File', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                            selected: !useUrlMode,
                            selectedColor: const Color(0xFF2563EB),
                            labelStyle: TextStyle(color: !useUrlMode ? Colors.white : (isDark ? Colors.white70 : Colors.black87)),
                            backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF1F5F9),
                            onSelected: (_) => setDlgState(() => useUrlMode = false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('External Link / URL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                            selected: useUrlMode,
                            selectedColor: const Color(0xFF2563EB),
                            labelStyle: TextStyle(color: useUrlMode ? Colors.white : (isDark ? Colors.white70 : Colors.black87)),
                            backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF1F5F9),
                            onSelected: (_) => setDlgState(() => useUrlMode = true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (!useUrlMode) ...[
                      InkWell(
                        onTap: isUploading
                            ? null
                            : () async {
                                final result = await FilePicker.platform.pickFiles(
                                  withData: true,
                                  type: FileType.any,
                                );
                                if (result != null && result.files.isNotEmpty) {
                                  final file = result.files.first;
                                  if (file.bytes != null) {
                                    setDlgState(() {
                                      pickedBytes = file.bytes;
                                      pickedFileName = file.name;
                                      pickedSize = file.size;
                                    });
                                  }
                                }
                              },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: pickedBytes != null
                                  ? const Color(0xFF10B981)
                                  : (isDark ? const Color(0xFF1F293D) : const Color(0xFFCBD5E1)),
                              width: 1.4,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                pickedBytes != null ? Icons.check_circle_outline_rounded : Icons.cloud_upload_outlined,
                                size: 36,
                                color: pickedBytes != null ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                pickedFileName ?? 'Click to browse local file from your device',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                pickedBytes != null
                                    ? '${(pickedSize / 1024).toStringAsFixed(1)} KB • Ready to upload'
                                    : 'Supports PDF, DOCX, XLSX, Images, ZIP (up to 50 MB)',
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      TextField(
                        controller: nameCtrl,
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black),
                        decoration: InputDecoration(
                          labelText: 'Document Name *',
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: urlCtrl,
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black),
                        decoration: InputDecoration(
                          labelText: 'Document URL *',
                          hintText: 'https://...',
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isUploading ? null : () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: isUploading
                      ? null
                      : () async {
                          final api = ref.read(workApiServiceProvider);
                          if (!useUrlMode) {
                            if (pickedBytes == null || pickedFileName == null) return;
                            setDlgState(() => isUploading = true);
                            final res = await api.uploadAttachment(item.id, pickedBytes!, pickedFileName!);
                            if (ctx.mounted) Navigator.pop(ctx, res['success'] == true);
                          } else {
                            if (nameCtrl.text.trim().isEmpty || urlCtrl.text.trim().isEmpty) return;
                            setDlgState(() => isUploading = true);
                            final fname = nameCtrl.text.trim();
                            final res = await api.addAttachment(
                              item.id,
                              fname,
                              urlCtrl.text.trim(),
                              fileSizeBytes: 0,
                              fileType: fname.toLowerCase().endsWith('.pdf') ? 'pdf' : 'document',
                            );
                            if (ctx.mounted) Navigator.pop(ctx, res['success'] == true);
                          }
                        },
                  icon: isUploading
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.attach_file_rounded, size: 16, color: Colors.white),
                  label: Text(isUploading ? 'Uploading...' : 'Attach', style: const TextStyle(color: Colors.white)),
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

    if (didUpload == true) {
      await _loadDetail(item.id, notifyParent: true);
      _refreshAllProviders();
      _showSnack('Attachment uploaded successfully');
    }
  }

  Future<void> _downloadAttachment(Map<String, dynamic> att) async {
    final fname = att['file_name']?.toString() ?? 'document';
    final rawUrl = att['file_url']?.toString() ?? '';
    if (rawUrl.isEmpty) {
      _showSnack('Download URL not available for $fname', isError: true);
      return;
    }

    final resolvedUrl = rawUrl.startsWith('http://') || rawUrl.startsWith('https://')
        ? rawUrl
        : '${AppConfig.baseUrl}$rawUrl';
    try {
      await getDownloadHelper().downloadFile(resolvedUrl, fname);
    } catch (e) {
      _showSnack('Download triggered for $fname');
    }
  }

  Future<void> _deleteAttachment(String attId, String fname) async {
    final item = _effectiveItem;
    if (item == null || attId.isEmpty) return;
    final api = ref.read(workApiServiceProvider);
    final ok = await api.deleteAttachment(attId);
    if (ok) {
      await _loadDetail(item.id, notifyParent: true);
      _refreshAllProviders();
      _showSnack('Removed attachment $fname');
    } else {
      _showSnack('Failed to remove attachment', isError: true);
    }
  }

  Future<void> _addLinkDialog() async {
    final item = _effectiveItem;
    if (item == null) return;
    final targetNumCtrl = TextEditingController();
    String linkType = 'RELATED';
    List<WorkItemModel> candidateItems = [];
    bool isLoadingCandidates = true;
    bool isLinking = false;
    String? errorMessage;
    bool fetchedOnce = false;

    final linkedSuccess = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;

            if (!fetchedOnce) {
              fetchedOnce = true;
              ref.read(workApiServiceProvider).getItemsPaged(pageSize: 100).then((res) {
                if (ctx.mounted) {
                  final list = (res['items'] as List<WorkItemModel>? ?? [])
                      .where((w) => w.id != item.id)
                      .toList();
                  setDlgState(() {
                    candidateItems = list;
                    isLoadingCandidates = false;
                  });
                }
              }).catchError((_) {
                if (ctx.mounted) {
                  setDlgState(() => isLoadingCandidates = false);
                }
              });
            }

            final q = targetNumCtrl.text.trim().toLowerCase();
            final filteredCandidates = candidateItems.where((w) {
              if (q.isEmpty) return true;
              return w.itemNumber.toLowerCase().contains(q) ||
                  w.title.toLowerCase().contains(q) ||
                  w.id.toLowerCase() == q;
            }).toList();

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
              ),
              title: Row(
                children: [
                  const Icon(Icons.add_link_rounded, color: Color(0xFF2563EB), size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Link Related Work Item',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Relationship type',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: linkType,
                      isDense: true,
                      dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'RELATED', child: Text('Related')),
                        DropdownMenuItem(value: 'CHILD', child: Text('Child (Subtask)')),
                        DropdownMenuItem(value: 'PARENT', child: Text('Parent (Story/Epic)')),
                        DropdownMenuItem(value: 'BLOCKS', child: Text('Blocks')),
                        DropdownMenuItem(value: 'BLOCKED_BY', child: Text('Blocked By')),
                      ],
                      onChanged: (v) => setDlgState(() => linkType = v ?? 'RELATED'),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Search or enter Item Number (e.g. WM-1048)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: targetNumCtrl,
                      onChanged: (_) => setDlgState(() => errorMessage = null),
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        hintText: 'Type WM-1048 or search by title...',
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF3B82F6)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 210,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: isLoadingCandidates
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                          : filteredCandidates.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No matching items found. You can still type an exact number or UUID.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: filteredCandidates.length,
                                  separatorBuilder: (_, __) => Divider(
                                    height: 1,
                                    color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
                                  ),
                                  itemBuilder: (context, idx) {
                                    final cand = filteredCandidates[idx];
                                    final isSelected =
                                        targetNumCtrl.text.trim().toUpperCase() == cand.itemNumber.toUpperCase() ||
                                        targetNumCtrl.text.trim() == cand.id;
                                    final tColor = _getTypeColor(cand.workType);
                                    return InkWell(
                                      onTap: () {
                                        setDlgState(() {
                                          targetNumCtrl.text = cand.itemNumber;
                                          errorMessage = null;
                                        });
                                      },
                                      child: Container(
                                        color: isSelected
                                            ? const Color(0xFF2563EB).withValues(alpha: 0.16)
                                            : Colors.transparent,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: tColor.withValues(alpha: 0.14),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                cand.workType,
                                                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: tColor),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              cand.itemNumber,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF3B82F6),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                cand.title,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isSelected)
                                              const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF2563EB)),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorMessage!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLinking ? null : () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: isLinking
                      ? null
                      : () async {
                          final targetRef = targetNumCtrl.text.trim();
                          if (targetRef.isEmpty) {
                            setDlgState(() => errorMessage = 'Please select or enter a work item.');
                            return;
                          }
                          setDlgState(() {
                            isLinking = true;
                            errorMessage = null;
                          });
                          final res = await ref.read(workApiServiceProvider).linkWorkItemDetailed(
                                item.id,
                                targetRef,
                                linkType,
                              );
                          if (!ctx.mounted) return;
                          if (res['success'] == true) {
                            Navigator.pop(ctx, true);
                          } else {
                            setDlgState(() {
                              isLinking = false;
                              errorMessage = res['error']?.toString() ?? 'Failed to link work item.';
                            });
                          }
                        },
                  icon: isLinking
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.add_link_rounded, size: 16, color: Colors.white),
                  label: Text(isLinking ? 'Linking...' : 'Add Link', style: const TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                ),
              ],
            );
          },
        );
      },
    );

    if (linkedSuccess == true) {
      await _loadDetail(item.id, notifyParent: true);
      _refreshAllProviders();
      _showSnack('Linked work item successfully');
    }
  }

  Future<void> _showAddChildDialog(WorkItemModel parentItem) async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final estCtrl = TextEditingController(text: '8');
    String selectedType = 'TASK';
    String selectedPriority = 'MEDIUM';
    String? selectedAssigneeId;
    bool isSubmitting = false;
    String? errorMsg;

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_task_rounded, color: Color(0xFF2563EB), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Child Work Item',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Under ${parentItem.itemNumber} - ${parentItem.title}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Title *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: titleCtrl,
                        autofocus: true,
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black),
                        decoration: InputDecoration(
                          hintText: 'e.g. Implement user login API endpoint',
                          isDense: true,
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Work Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569))),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  initialValue: selectedType,
                                  isDense: true,
                                  dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  items: const ['TASK', 'BUG', 'ISSUE']
                                      .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12.5))))
                                      .toList(),
                                  onChanged: (v) => setDlgState(() => selectedType = v ?? 'TASK'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Priority', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569))),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  initialValue: selectedPriority,
                                  isDense: true,
                                  dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  items: const ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW']
                                      .map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 12.5))))
                                      .toList(),
                                  onChanged: (v) => setDlgState(() => selectedPriority = v ?? 'MEDIUM'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          SizedBox(
                            width: 120,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Est. Hours', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569))),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: estCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    filled: true,
                                    fillColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Assignee', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569))),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String?>(
                                  initialValue: selectedAssigneeId,
                                  isDense: true,
                                  dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  items: [
                                    const DropdownMenuItem<String?>(value: null, child: Text('Unassigned', style: TextStyle(fontSize: 12.5))),
                                    ..._assignableUsers.map((u) => DropdownMenuItem<String?>(
                                          value: u.id,
                                          child: Text(
                                            '${u.fullName} (${u.role})',
                                            style: const TextStyle(fontSize: 12.5),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        )),
                                  ],
                                  onChanged: (v) => setDlgState(() => selectedAssigneeId = v),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: descCtrl,
                        maxLines: 3,
                        style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white : Colors.black),
                        decoration: InputDecoration(
                          hintText: 'Acceptance criteria or details...',
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      if (errorMsg != null) ...[
                        const SizedBox(height: 8),
                        Text(errorMsg!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final title = titleCtrl.text.trim();
                          if (title.isEmpty) {
                            setDlgState(() => errorMsg = 'Please enter a title');
                            return;
                          }
                          setDlgState(() {
                            isSubmitting = true;
                            errorMsg = null;
                          });
                          final estHours = double.tryParse(estCtrl.text.trim()) ?? 8.0;
                          final api = ref.read(workApiServiceProvider);
                          final res = await api.createWorkItem({
                            'title': title,
                            'description': descCtrl.text.trim(),
                            'work_type': selectedType,
                            'priority': selectedPriority,
                            'status': 'NEW',
                            'category': parentItem.category,
                            'parent_id': parentItem.id,
                            'board_id': parentItem.boardId,
                            'sprint_id': parentItem.sprintId,
                            'estimated_hours': estHours,
                            if (selectedAssigneeId != null) 'assignee_ids': [selectedAssigneeId],
                          });
                          if (!ctx.mounted) return;
                          if (res['success'] == true) {
                            Navigator.pop(ctx, true);
                          } else {
                            setDlgState(() {
                              isSubmitting = false;
                              errorMsg = res['error']?.toString() ?? 'Failed to create child item';
                            });
                          }
                        },
                  icon: isSubmitting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.add_task_rounded, size: 16, color: Colors.white),
                  label: Text(isSubmitting ? 'Creating...' : 'Create Child Item', style: const TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                ),
              ],
            );
          },
        );
      },
    );

    if (created == true) {
      await _loadDetail(parentItem.id, notifyParent: true);
      _refreshAllProviders();
      _showSnack('Child work item created and linked successfully');
    }
  }

  Future<void> _showEditLinkRelationshipDialog(
    WorkItemModel sourceItem,
    String targetId,
    String currentType,
    String targetNum,
    String targetTitle,
  ) async {
    String selectedRelation = currentType.toUpperCase();
    bool isSaving = false;
    String? errorMsg;

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
              ),
              title: Row(
                children: [
                  const Icon(Icons.sync_alt_rounded, color: Color(0xFF2563EB), size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Update Relationship',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Modify relationship with $targetNum - $targetTitle:',
                      style: TextStyle(fontSize: 12.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Select Relationship Type',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: ['RELATED', 'CHILD', 'PARENT', 'BLOCKS', 'BLOCKED_BY'].contains(selectedRelation)
                          ? selectedRelation
                          : 'RELATED',
                      isDense: true,
                      dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'RELATED', child: Text('Related (Bidirectional link)')),
                        DropdownMenuItem(value: 'CHILD', child: Text('Child (Subtask of this item)')),
                        DropdownMenuItem(value: 'PARENT', child: Text('Parent (Parent story/epic of this item)')),
                        DropdownMenuItem(value: 'BLOCKS', child: Text('Blocks (This item blocks target)')),
                        DropdownMenuItem(value: 'BLOCKED_BY', child: Text('Blocked By (This item is blocked by target)')),
                      ],
                      onChanged: (v) => setDlgState(() => selectedRelation = v ?? 'RELATED'),
                    ),
                    if (errorMsg != null) ...[
                      const SizedBox(height: 10),
                      Text(errorMsg!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDlgState(() {
                            isSaving = true;
                            errorMsg = null;
                          });
                          final ok = await ref.read(workApiServiceProvider).updateLinkRelationship(
                                sourceItem.id,
                                targetId,
                                selectedRelation,
                              );
                          if (!ctx.mounted) return;
                          if (ok) {
                            Navigator.pop(ctx, true);
                          } else {
                            setDlgState(() {
                              isSaving = false;
                              errorMsg = 'Failed to update relationship';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                  child: Text(isSaving ? 'Updating...' : 'Update Relationship', style: const TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );

    if (updated == true) {
      await _loadDetail(sourceItem.id, notifyParent: true);
      _refreshAllProviders();
      _showSnack('Relationship updated to $selectedRelation');
    }
  }

  void _insertMention(String userName) {
    final current = _commentController.text;
    _commentController.text = '$current@$userName ';
    _commentController.selection = TextSelection.fromPosition(TextPosition(offset: _commentController.text.length));
  }

  @override
  Widget build(BuildContext context) {
    final item = _effectiveItem;
    if (item == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final typeColor = _getTypeColor(item.workType);

    final checklists = (_fullDetail?['checklists'] as List<dynamic>?) ?? [];
    final comments = (_fullDetail?['comments'] as List<dynamic>?) ?? [];
    final activityLogs = (_fullDetail?['activity_logs'] as List<dynamic>?) ?? (_fullDetail?['activity'] as List<dynamic>?) ?? [];
    final attachments = (_fullDetail?['attachments'] as List<dynamic>?) ?? [];
    final children = (_fullDetail?['children'] as List<dynamic>?) ?? [];
    final dependencies = (_fullDetail?['dependencies'] as List<dynamic>?) ?? [];
    final labels = (_fullDetail?['labels'] as List<dynamic>?) ?? item.labels;

    final completedChecks = checklists.where((c) => c['is_completed'] == true).length;
    final totalChecks = checklists.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isHeightBounded = constraints.hasBoundedHeight;
        final mediaWidth = MediaQuery.of(context).size.width;
        final responsiveWidth = mediaWidth < 500 ? mediaWidth : 480.0;
        final targetWidth = constraints.hasBoundedWidth
            ? (constraints.maxWidth < responsiveWidth ? constraints.maxWidth : responsiveWidth)
            : responsiveWidth;

        return Container(
          width: targetWidth,
          height: isHeightBounded ? null : 850,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF13182C) : Colors.white,
            border: Border(
              left: BorderSide(
                color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 16,
                offset: const Offset(-4, 0),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drawer Header Toolbar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                item.itemNumber,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: typeColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.workType.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: typeColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () => _editTitleDescDialog(item),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                item.title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Full CRUD Actions (Edit, Copy, Delete, Close)
                    IconButton(
                      onPressed: () => _editTitleDescDialog(item),
                      tooltip: 'Edit Title / Description',
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      splashRadius: 18,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(6),
                    ),
                    IconButton(
                      onPressed: _isCopying ? null : _copyWorkItemDialog,
                      tooltip: 'Create Copy / Clone',
                      icon: const Icon(Icons.content_copy_rounded, size: 18),
                      color: const Color(0xFF2563EB),
                      splashRadius: 18,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(6),
                    ),
                    IconButton(
                      onPressed: _isDeleting ? null : () => _deleteWorkItemDialog(item),
                      tooltip: 'Delete Work Item',
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      color: const Color(0xFFEF4444),
                      splashRadius: 18,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(6),
                    ),
                    IconButton(
                      onPressed: widget.onClose,
                      tooltip: 'Close',
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      splashRadius: 18,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(6),
                    ),
                  ],
                ),
              ),

              // Tabs (Details, Comments, Activity, Links)
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFF2563EB),
                  unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  indicatorColor: const Color(0xFF2563EB),
                  indicatorWeight: 2.5,
                  labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  tabs: [
                    const Tab(text: 'Details'),
                    Tab(text: 'Comments (${comments.length})'),
                    Tab(text: 'Activity (${activityLogs.length})'),
                    Tab(text: 'Links (${children.length + dependencies.length})'),
                  ],
                ),
              ),

              // Tab Content
              if (_isLoading)
                const LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDetailsTab(
                      context,
                      item,
                      checklists,
                      completedChecks,
                      totalChecks,
                      attachments,
                      labels,
                      isDark,
                    ),
                    _buildCommentsTab(context, comments, isDark),
                    _buildActivityTab(context, activityLogs, isDark),
                    _buildLinksTab(context, children, dependencies, isDark),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailsTab(
    BuildContext context,
    WorkItemModel item,
    List<dynamic> checklists,
    int completedChecks,
    int totalChecks,
    List<dynamic> attachments,
    List<dynamic> labels,
    bool isDark,
  ) {
    final statusList = ['NEW', 'ACTIVE', 'IN PROGRESS', 'RESOLVED', 'COMPLETED'];
    final priorityList = ['LOW', 'MEDIUM', 'HIGH', 'URGENT', 'CRITICAL'];

    final double actH = double.tryParse(_actualHoursController.text) ?? item.actualHours;
    final double remH = double.tryParse(_remainingHoursController.text) ?? item.remainingHours;
    final int dynamicProgress = _calculateEffortProgress(actH, remH);
    final reporterName = (_fullDetail?['reporter_name']?.toString() ?? item.reporterName ?? 'System').trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status
          _buildPropertyRow(
            label: 'Status:',
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: statusList.contains(item.status.toUpperCase()) ? item.status.toUpperCase() : 'NEW',
                isDense: true,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                onChanged: (v) {
                  if (v != null) _changeStatus(v);
                },
                items: statusList.map((s) {
                  return DropdownMenuItem<String>(
                    value: s,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _getStatusColor(s),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(s),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          // Priority
          _buildPropertyRow(
            label: 'Priority:',
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: priorityList.contains(item.priority.toUpperCase()) ? item.priority.toUpperCase() : 'MEDIUM',
                isDense: true,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                onChanged: (v) async {
                  if (v != null) {
                    await _updateFields({'priority': v}, successMessage: 'Priority updated to $v');
                  }
                },
                items: priorityList.map((p) {
                  return DropdownMenuItem<String>(
                    value: p,
                    child: Text(
                      '= $p',
                      style: TextStyle(
                        color: p == 'HIGH' || p == 'URGENT' || p == 'CRITICAL'
                            ? const Color(0xFFEF4444)
                            : p == 'MEDIUM'
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF10B981),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          // Board Selector
          _buildPropertyRow(
            label: 'Board:',
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _boards.any((b) => b.id == _selectedBoardId)
                    ? _selectedBoardId
                    : (_boards.isNotEmpty ? _boards.first.id : null),
                isDense: true,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                onChanged: (v) {
                  if (v != null) _moveToBoard(v);
                },
                items: _boards.map((b) {
                  return DropdownMenuItem<String>(
                    value: b.id,
                    child: Text(b.name, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
              ),
            ),
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          // Sprint Selector
          Builder(
            builder: (context) {
              final sprintsState = ref.watch(allSprintsProvider);
              final currentSprints = sprintsState.sprints.isNotEmpty ? sprintsState.sprints : _sprints;
              return _buildPropertyRow(
                label: 'Sprint:',
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: currentSprints.any((s) => s.id == _selectedSprintId) ? _selectedSprintId : null,
                    isDense: true,
                    isExpanded: true,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                    onChanged: (v) => _moveToSprint(v),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Backlog (No Sprint)', overflow: TextOverflow.ellipsis),
                      ),
                      ...currentSprints.map((s) {
                        return DropdownMenuItem<String?>(
                          value: s.id,
                          child: Text(s.displayLabel, overflow: TextOverflow.ellipsis),
                        );
                      }),
                    ],
                  ),
                ),
                isDark: isDark,
              );
            },
          ),
          const SizedBox(height: 12),

          // Team Selector
          _buildPropertyRow(
            label: 'Team:',
            child: DropdownButtonHideUnderline(
              child: Builder(
                builder: (context) {
                  final displayTeams = <String>{
                    ..._teamsList.where((t) => t != 'All'),
                    if (_selectedTeamName != null && _selectedTeamName!.isNotEmpty && _selectedTeamName != 'Unassigned')
                      _selectedTeamName!,
                    if (item.teamName != null && item.teamName!.isNotEmpty && item.teamName != 'Unassigned')
                      item.teamName!,
                  }.toList();

                  final effectiveValue = (_selectedTeamName != null && _selectedTeamName!.isNotEmpty && _selectedTeamName != 'Unassigned')
                      ? _selectedTeamName
                      : ((item.teamName != null && item.teamName!.isNotEmpty && item.teamName != 'Unassigned') ? item.teamName : null);

                  final dropdownValue = (effectiveValue != null && displayTeams.contains(effectiveValue))
                      ? effectiveValue
                      : null;

                  return DropdownButton<String?>(
                    value: dropdownValue,
                    isDense: true,
                    isExpanded: true,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                    onChanged: (v) async {
                      setState(() => _selectedTeamName = v);
                      final teamVal = (v == null || v == 'Unassigned') ? 'UNASSIGN' : v;
                      await _updateFields({'team_name': teamVal}, successMessage: v == null ? 'Team unassigned' : 'Team updated to $v');
                    },
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Unassigned (No Team)', overflow: TextOverflow.ellipsis),
                      ),
                      ...displayTeams.map((t) {
                        return DropdownMenuItem<String?>(
                          value: t,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.groups_rounded, size: 14, color: Color(0xFF6366F1)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(t, overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          // Assignees (Interactive CRUD: Add / Change / Remove Assignees)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 90,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Assignee(s):',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (item.assignees.isEmpty)
                          Text(
                            'Unassigned',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                            ),
                          )
                        else ...[
                          ...item.assignees.take(3).map((a) {
                            final uid = a.userId.isNotEmpty ? a.userId : a.id;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF1F293D) : const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 9,
                                    backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.2),
                                    backgroundImage: (a.avatarUrl != null && a.avatarUrl!.isNotEmpty)
                                        ? NetworkImage(a.avatarUrl!)
                                        : null,
                                    child: (a.avatarUrl == null || a.avatarUrl!.isEmpty)
                                        ? Text(
                                            a.fullName.isNotEmpty ? a.fullName[0].toUpperCase() : 'U',
                                            style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 5),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 120),
                                    child: Text(
                                      a.fullName,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: () => _removeSingleAssignee(item, uid),
                                    child: const Icon(Icons.close_rounded, size: 12, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            );
                          }),
                          if (item.assignees.length > 3)
                            InkWell(
                              onTap: () => _openManageAssigneesDialog(item),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '+${item.assignees.length - 3} more',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF3B82F6)),
                                ),
                              ),
                            ),
                        ],
                        InkWell(
                          onTap: () => _openManageAssigneesDialog(item),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.35)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_outlined, size: 12, color: Color(0xFF3B82F6)),
                                SizedBox(width: 4),
                                Text(
                                  'Change',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF3B82F6)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Reporter
          _buildPropertyRow(
            label: 'Reporter:',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
                  child: Text(
                    reporterName.isNotEmpty ? reporterName[0].toUpperCase() : 'S',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  reporterName,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          // Start Date (Editable)
          _buildPropertyRow(
            label: 'Start Date:',
            child: InkWell(
              onTap: () => _pickAndUpdateDate(isStart: true),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 13, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 6),
                    Text(
                      item.startDate != null && item.startDate!.length >= 10
                          ? item.startDate!.substring(0, 10)
                          : 'Set Start Date',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            isDark: isDark,
          ),
          const SizedBox(height: 10),

          // Due Date (Editable)
          _buildPropertyRow(
            label: 'Due Date:',
            child: InkWell(
              onTap: () => _pickAndUpdateDate(isStart: false),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.event_outlined, size: 13, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 6),
                    Text(
                      item.dueDate != null && item.dueDate!.length >= 10
                          ? item.dueDate!.substring(0, 10)
                          : 'Set Due Date',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            isDark: isDark,
          ),
          const SizedBox(height: 18),

          // ==========================================
          // EFFORT & PROGRESS CARD
          // ==========================================
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 16, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Effort & Progress',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$dynamicProgress%',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (dynamicProgress / 100).clamp(0.0, 1.0),
                    backgroundColor: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      dynamicProgress == 100 ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                    ),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 14),
                if (item.workType.toUpperCase() == 'STORY' || item.workType.toUpperCase() == 'EPIC') ...[
                  Row(
                    children: [
                      Text(
                        'Story Points:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF334155)),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 90,
                        height: 32,
                        child: TextField(
                          controller: _storyPointsController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white : Colors.black),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    Expanded(
                      child: _buildEffortField(
                        label: 'Original (h)',
                        controller: _estimatedHoursController,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildEffortField(
                        label: 'Remaining (h)',
                        controller: _remainingHoursController,
                        isDark: isDark,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildEffortField(
                        label: 'Completed (h)',
                        controller: _actualHoursController,
                        isDark: isDark,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _isSavingEffort ? null : _saveEffort,
                    icon: _isSavingEffort
                        ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_rounded, size: 14, color: Colors.white),
                    label: const Text('Save Effort', style: TextStyle(fontSize: 11.5, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Labels (Full Add/Remove CRUD)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 90,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Labels:',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ...labels.map((l) {
                          final name = l is Map ? (l['name']?.toString() ?? '') : l.toString();
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isDark ? const Color(0xFF2563EB).withValues(alpha: 0.4) : const Color(0xFFBFDBFE),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () => _removeLabel(labels, name),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 12,
                                    color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        InkWell(
                          onTap: () => setState(() => _showAddLabelInput = !_showAddLabelInput),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFCBD5E1)),
                            ),
                            child: const Text('+ Add Label', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF3B82F6))),
                          ),
                        ),
                      ],
                    ),
                    if (_showAddLabelInput) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 32,
                              child: TextField(
                                controller: _newLabelController,
                                onSubmitted: (_) => _addLabel(labels),
                                style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black),
                                decoration: InputDecoration(
                                  hintText: 'Enter tag / label...',
                                  isDense: true,
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          ElevatedButton(
                            onPressed: () => _addLabel(labels),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              minimumSize: const Size(0, 32),
                            ),
                            child: const Text('Add', style: TextStyle(fontSize: 11, color: Colors.white)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Description (Editable)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Description',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              InkWell(
                onTap: () => _editTitleDescDialog(item),
                child: const Text('Edit', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF3B82F6))),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.description.isNotEmpty ? item.description : 'No description added yet. Click Edit to add details.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: item.description.isNotEmpty
                  ? (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155))
                  : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
            ),
          ),
          const SizedBox(height: 20),

          // Checklist FULL CRUD
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Checklist ($completedChecks/$totalChecks)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              InkWell(
                onTap: () {
                  setState(() => _showAddChecklistInput = !_showAddChecklistInput);
                },
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_showAddChecklistInput ? Icons.close_rounded : Icons.add, size: 16, color: const Color(0xFF2563EB)),
                      const SizedBox(width: 2),
                      Text(
                        _showAddChecklistInput ? 'Cancel' : 'Add Item',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_showAddChecklistInput) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      controller: _newChecklistController,
                      autofocus: true,
                      onSubmitted: (_) => _addChecklistItem(),
                      style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        hintText: 'Enter checklist step...',
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isAddingChecklist ? null : _addChecklistItem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(0, 36),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isAddingChecklist
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Add', style: TextStyle(fontSize: 12, color: Colors.white)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          if (checklists.isEmpty)
            Text(
              'No checklist items yet. Click "Add Item" to create one.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: checklists.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, idx) {
                final c = checklists[idx] as Map<String, dynamic>;
                final checkId = c['id']?.toString() ?? '';
                final title = c['title']?.toString() ?? '';
                final isDone = c['is_completed'] == true;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => _toggleChecklist(checkId, isDone),
                        child: Icon(
                          isDone ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                          size: 18,
                          color: isDone ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () => _toggleChecklist(checkId, isDone),
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 12.5,
                              decoration: isDone ? TextDecoration.lineThrough : null,
                              color: isDone
                                  ? (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))
                                  : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _editChecklistDialog(checkId, title),
                        icon: const Icon(Icons.edit_outlined, size: 14),
                        color: const Color(0xFF94A3B8),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                        tooltip: 'Edit',
                      ),
                      IconButton(
                        onPressed: () => _deleteChecklist(checkId),
                        icon: const Icon(Icons.delete_outline_rounded, size: 14),
                        color: const Color(0xFFEF4444),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 22),

          // Attachments FULL CRUD (Real DB data + Local File Upload + Download + Delete)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Attachments (${attachments.length})',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              InkWell(
                onTap: _uploadAttachmentDialog,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.upload_file_outlined, size: 14, color: Color(0xFF2563EB)),
                      SizedBox(width: 4),
                      Text('Upload File', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (attachments.isEmpty)
            Text(
              'No attachments yet. Click "Upload File" to attach a local file.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            )
          else
            ...attachments.map((att) {
              final a = Map<String, dynamic>.from(att as Map);
              final attId = a['id']?.toString() ?? '';
              final fname = a['file_name']?.toString() ?? 'Document';
              final sizeBytes = (a['file_size_bytes'] as num?)?.toInt() ?? 0;
              final fsize = a['file_size_fmt']?.toString() ??
                  (sizeBytes >= 1048576
                      ? '${(sizeBytes / 1048576).toStringAsFixed(1)} MB'
                      : sizeBytes >= 1024
                          ? '${(sizeBytes / 1024).toStringAsFixed(1)} KB'
                          : '$sizeBytes B');
              final isPdf = fname.toLowerCase().endsWith('.pdf');
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildAttachmentItem(
                  name: '$fname ($fsize)',
                  isPdf: isPdf,
                  isDark: isDark,
                  onDownload: () => _downloadAttachment(a),
                  onDelete: () => _deleteAttachment(attId, fname),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildEffortField({
    required String label,
    required TextEditingController controller,
    required bool isDark,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 32,
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: onChanged,
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPropertyRow({
    required String label,
    required Widget child,
    required bool isDark,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  Widget _buildAttachmentItem({
    required String name,
    required bool isPdf,
    required bool isDark,
    required VoidCallback onDownload,
    required VoidCallback onDelete,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isPdf ? Icons.picture_as_pdf_outlined : Icons.description_outlined,
            size: 18,
            color: isPdf ? const Color(0xFFEF4444) : const Color(0xFF2563EB),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: onDownload,
            icon: const Icon(Icons.download_rounded, size: 16),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            color: const Color(0xFF3B82F6),
            tooltip: 'Download',
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, size: 15),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            color: const Color(0xFFEF4444),
            tooltip: 'Delete Attachment',
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: COMMENTS & USER TAGGING (@)
  // ==========================================
  Widget _buildCommentsTab(BuildContext context, List<dynamic> comments, bool isDark) {
    final mentionNames = _assignableUsers.take(8).map((u) => u.fullName).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: comments.isEmpty
                ? Center(
                    child: Text(
                      'No comments yet. Write one below.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: comments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, idx) {
                      final c = comments[idx] as Map<String, dynamic>;
                      final author = c['author_name']?.toString() ?? 'Author';
                      final content = c['comment_text']?.toString() ?? c['content']?.toString() ?? '';
                      final avatar = c['author_avatar']?.toString() ?? c['avatar_url']?.toString() ?? '';
                      final rawTime = c['created_at']?.toString() ?? 'Today';
                      final timeAgo = rawTime.length > 16 ? rawTime.substring(0, 16) : rawTime;

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 13,
                            backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.2),
                            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                            child: avatar.isEmpty
                                ? Text(author.isNotEmpty ? author[0] : 'U', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        author,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      Text(
                                        timeAgo,
                                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    content,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),

          if (mentionNames.isNotEmpty) ...[
            Row(
              children: [
                const Text('Tag user: ', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: mentionNames.map((name) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            visualDensity: VisualDensity.compact,
                            backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFEFF6FF),
                            side: BorderSide(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
                            label: Text('@$name', style: const TextStyle(fontSize: 10.5, color: Color(0xFF3B82F6))),
                            onPressed: () => _insertMention(name),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  onSubmitted: (_) => _addComment(),
                  style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    hintText: 'Write a comment... (use @ to mention)',
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF1F293D) : const Color(0xFFCBD5E1),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isAddingComment ? null : _addComment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isAddingComment
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, size: 16, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: AUDIT HISTORY (WHO CHANGED WHAT TO WHAT)
  // ==========================================
  Widget _buildActivityTab(BuildContext context, List<dynamic> logs, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: logs.isEmpty
          ? Center(
              child: Text(
                'No activity history yet.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
              ),
            )
          : ListView.separated(
              itemCount: logs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, idx) {
                final log = logs[idx] as Map<String, dynamic>;
                final actor = log['actor_name']?.toString() ?? 'User';
                final actionType = log['action_type']?.toString().toUpperCase() ?? 'ACTIVITY';
                final oldValue = log['old_value']?.toString();
                final newValue = log['new_value']?.toString();
                final message = log['message']?.toString() ?? '';
                final time = log['created_at']?.toString() ?? '';

                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
                        child: Text(
                          actor.isNotEmpty ? actor[0].toUpperCase() : 'U',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    actor,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  time,
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (actionType == 'STATUS_CHANGE' && oldValue != null && newValue != null) ...[
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(oldValue).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      oldValue.toUpperCase(),
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getStatusColor(oldValue)),
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 6),
                                    child: Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF64748B)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(newValue).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      newValue.toUpperCase(),
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getStatusColor(newValue)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                            ],
                            Text(
                              message.isNotEmpty ? message : '$actor updated $actionType',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  // ==========================================
  // TAB 4: RELATED ITEMS & CHILDREN HIERARCHY
  // ==========================================
  Widget _buildLinksTab(BuildContext context, List<dynamic> children, List<dynamic> dependencies, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Related Work & Hierarchy',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _addLinkDialog,
                icon: const Icon(Icons.add_link_rounded, size: 14),
                label: const Text('Add Link', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CHILD WORK ITEMS (${children.length})',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5),
              ),
              InkWell(
                onTap: () {
                  final item = _effectiveItem;
                  if (item != null) _showAddChildDialog(item);
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 13, color: Color(0xFF2563EB)),
                      SizedBox(width: 4),
                      Text(
                        'Add Child Item',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (children.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('No child tasks attached. Click "Add Child Item" or "Add Link" with relation CHILD to attach subtasks.', style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: children.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final ch = children[idx] as Map<String, dynamic>;
                final childId = ch['id']?.toString() ?? '';
                final childNum = ch['item_number']?.toString() ?? 'TK';
                final title = ch['title']?.toString() ?? '';
                final status = ch['status']?.toString() ?? 'NEW';
                final prog = (ch['progress_percentage'] as num?)?.toInt() ?? 0;

                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.subdirectory_arrow_right_rounded, size: 16, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            if (childId.isNotEmpty) {
                              _loadDetail(childId, notifyParent: true);
                            }
                          },
                          child: Row(
                            children: [
                              Text(
                                childNum,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2563EB),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getStatusColor(status)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('$prog%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: () {
                          final item = _effectiveItem;
                          if (item != null && childId.isNotEmpty) {
                            _showEditLinkRelationshipDialog(item, childId, 'CHILD', childNum, title);
                          }
                        },
                        icon: const Icon(Icons.edit_outlined, size: 14),
                        color: const Color(0xFF94A3B8),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Edit Relationship Type',
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: () async {
                          final item = _effectiveItem;
                          if (item != null && childId.isNotEmpty) {
                            await ref.read(workApiServiceProvider).unlinkWorkItems(item.id, childId);
                            await _loadDetail(item.id, notifyParent: true);
                            _refreshAllProviders();
                            _showSnack('Unlinked child $childNum');
                          }
                        },
                        icon: const Icon(Icons.link_off_rounded, size: 15),
                        color: const Color(0xFF94A3B8),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Unlink Child',
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 18),
          Text(
            'DEPENDENCIES & RELATED LINKS (${dependencies.length})',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),
          if (dependencies.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('No related links yet.', style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: dependencies.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final dep = dependencies[idx] as Map<String, dynamic>;
                final depType = dep['dependency_type']?.toString() ?? 'RELATED';
                final itemNum = dep['item_number']?.toString() ?? '';
                final title = dep['title']?.toString() ?? '';
                final targetId = dep['linked_item_id']?.toString() ?? '';

                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () {
                          final item = _effectiveItem;
                          if (item != null && targetId.isNotEmpty) {
                            _showEditLinkRelationshipDialog(item, targetId, depType, itemNum, title);
                          }
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                depType,
                                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                              ),
                              const SizedBox(width: 3),
                              const Icon(Icons.edit_rounded, size: 10, color: Color(0xFF2563EB)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            if (targetId.isNotEmpty) {
                              _loadDetail(targetId, notifyParent: true);
                            }
                          },
                          child: Row(
                            children: [
                              Text(
                                itemNum,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2563EB),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          final item = _effectiveItem;
                          if (item != null && targetId.isNotEmpty) {
                            _showEditLinkRelationshipDialog(item, targetId, depType, itemNum, title);
                          }
                        },
                        icon: const Icon(Icons.sync_alt_rounded, size: 15),
                        color: const Color(0xFF94A3B8),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Update Link Relationship',
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: () async {
                          final item = _effectiveItem;
                          if (item != null && targetId.isNotEmpty) {
                            await ref.read(workApiServiceProvider).unlinkWorkItems(item.id, targetId);
                            await _loadDetail(item.id, notifyParent: true);
                            _refreshAllProviders();
                            _showSnack('Unlinked $itemNum');
                          }
                        },
                        icon: const Icon(Icons.link_off_rounded, size: 16),
                        color: const Color(0xFF94A3B8),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Unlink',
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
