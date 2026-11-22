import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/work_models.dart';
import '../../providers/work_management_provider.dart';

class SprintCapacityTabView extends ConsumerStatefulWidget {
  final String sprintId;
  final String? selectedTeam;
  final ValueChanged<String>? onTeamChanged;
  final ValueChanged<String>? onSprintChanged;

  const SprintCapacityTabView({
    super.key,
    required this.sprintId,
    this.selectedTeam,
    this.onTeamChanged,
    this.onSprintChanged,
  });

  @override
  ConsumerState<SprintCapacityTabView> createState() => _SprintCapacityTabViewState();
}

class _SprintCapacityTabViewState extends ConsumerState<SprintCapacityTabView> {
  Set<String> _selectedMemberIds = {};
  final TextEditingController _gridSearchController = TextEditingController();
  Timer? _searchDebounce;

  List<WorkAssigneeModel> _assignableUsers = const [
    WorkAssigneeModel(id: '1', userId: '55555555-0001-0000-0000-000000000001', fullName: 'Neha Sharma', role: 'Teacher'),
    WorkAssigneeModel(id: '2', userId: '55555555-0002-0000-0000-000000000002', fullName: 'Amit Kumar', role: 'Staff'),
    WorkAssigneeModel(id: '3', userId: '55555555-0003-0000-0000-000000000003', fullName: 'Priya Singh', role: 'Staff'),
    WorkAssigneeModel(id: '4', userId: '55555555-0004-0000-0000-000000000004', fullName: 'Rahul Mehta', role: 'Staff'),
  ];

  @override
  void initState() {
    super.initState();
    _loadAssignableUsers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final team = widget.selectedTeam ?? 'Digital Campus Team';
      ref.read(workSprintCapacityProvider.notifier).init(
            sprintId: widget.sprintId,
            team: team,
          );
    });
  }

  Future<void> _loadAssignableUsers() async {
    try {
      final api = ref.read(workApiServiceProvider);
      final users = await api.getAssignableUsers(limit: 60);
      if (mounted && users.isNotEmpty) {
        setState(() => _assignableUsers = users);
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant SprintCapacityTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sprintId != widget.sprintId || oldWidget.selectedTeam != widget.selectedTeam) {
      final team = widget.selectedTeam ?? 'Digital Campus Team';
      ref.read(workSprintCapacityProvider.notifier).init(
            sprintId: widget.sprintId,
            team: team,
          );
    }
  }

  @override
  void dispose() {
    _gridSearchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  // ==========================================
  // DIALOGS & ACTIONS
  // ==========================================

  void _openAddMemberDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final users = _assignableUsers;

    String? selectedUserId = users.isNotEmpty ? users.first.userId : null;
    String selectedRole = 'Developer';
    final hoursController = TextEditingController(text: '40');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.person_add_alt_1_rounded, size: 20, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text('Add Member to Sprint Capacity', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Institute Member', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedUserId,
                  isExpanded: true,
                  dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                  items: users.map<DropdownMenuItem<String>>((u) {
                    return DropdownMenuItem<String>(
                      value: u.userId,
                      child: Text('${u.fullName} (${u.role})', overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (v) => setDialogState(() => selectedUserId = v),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Role in Sprint', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                  items: [
                    'Team Lead',
                    'Senior Developer',
                    'Backend Developer',
                    'UI/UX Designer',
                    'QA Engineer',
                    'DevOps Engineer',
                    'System Analyst',
                    'Developer',
                    'Member',
                  ].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (v) => setDialogState(() => selectedRole = v ?? 'Developer'),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Sprint Available Capacity (Hours)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                TextField(
                  controller: hoursController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    suffixText: 'hours',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
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
                if (selectedUserId != null) {
                  final hours = double.tryParse(hoursController.text.trim()) ?? 40.0;
                  final nav = Navigator.of(ctx);
                  await ref.read(workSprintCapacityProvider.notifier).manageMemberCapacity(
                        userId: selectedUserId!,
                        capacityHours: hours,
                        role: selectedRole,
                      );
                  nav.pop();
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              child: const Text('Add Member', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _openAdjustCapacityDialog(SprintCapacityMemberModel member) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hoursController = TextEditingController(text: member.capacityHours.toStringAsFixed(0));
    final dailyHoursController = TextEditingController(text: member.dailyWorkingHours.toStringAsFixed(1));
    final daysController = TextEditingController(text: member.workingDays.toString());
    final overrideController = TextEditingController(text: member.overrideValue != null ? member.overrideValue!.toStringAsFixed(0) : '');
    final reasonController = TextEditingController(text: member.overrideReason ?? '');
    final notesController = TextEditingController(text: member.notes ?? '');
    String selectedRole = member.role;
    bool hasOverride = member.overrideValue != null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              const Icon(Icons.tune_rounded, size: 20, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Adjust Capacity: ${member.fullName}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
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
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Daily Working Hours', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                            const SizedBox(height: 6),
                            TextField(
                              controller: dailyHoursController,
                              keyboardType: TextInputType.number,
                              onChanged: (v) {
                                final d = double.tryParse(v) ?? 8.0;
                                final days = int.tryParse(daysController.text) ?? 5;
                                hoursController.text = (d * days).toStringAsFixed(0);
                                setDialogState(() {});
                              },
                              decoration: InputDecoration(
                                suffixText: 'h/day',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                            const Text('Sprint Working Days', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                            const SizedBox(height: 6),
                            TextField(
                              controller: daysController,
                              keyboardType: TextInputType.number,
                              onChanged: (v) {
                                final days = int.tryParse(v) ?? 5;
                                final d = double.tryParse(dailyHoursController.text) ?? 8.0;
                                hoursController.text = (d * days).toStringAsFixed(0);
                                setDialogState(() {});
                              },
                              decoration: InputDecoration(
                                suffixText: 'days',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('Total Available Capacity (Hours)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: hoursController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      suffixText: 'hours',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Member Role in Sprint', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                    items: [
                      'Team Lead',
                      'Senior Developer',
                      'Backend Developer',
                      'UI/UX Designer',
                      'QA Engineer',
                      'DevOps Engineer',
                      'System Analyst',
                      'Developer',
                    ].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (v) => setDialogState(() => selectedRole = v ?? selectedRole),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 14),
                  CheckboxListTile(
                    value: hasOverride,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Manual Capacity Override', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Override standard calculated hours with custom value', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    onChanged: (v) => setDialogState(() => hasOverride = v ?? false),
                  ),
                  if (hasOverride) ...[
                    const SizedBox(height: 6),
                    TextField(
                      controller: overrideController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Override Hours',
                        suffixText: 'hours',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: reasonController,
                      decoration: InputDecoration(
                        labelText: 'Reason for Override',
                        hintText: 'e.g. Dedicated to Exam module, Part-time support...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  const Text('Notes / Remarks', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Optional notes for sprint planning...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(10),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final capHours = double.tryParse(hoursController.text.trim()) ?? member.capacityHours;
                final dailyHours = double.tryParse(dailyHoursController.text.trim());
                final days = int.tryParse(daysController.text.trim());
                final overrideVal = hasOverride ? double.tryParse(overrideController.text.trim()) : null;
                final overrideReason = hasOverride ? reasonController.text.trim() : null;
                final notes = notesController.text.trim();

                final nav = Navigator.of(ctx);
                await ref.read(workSprintCapacityProvider.notifier).manageMemberCapacity(
                      userId: member.userId,
                      capacityHours: capHours,
                      dailyWorkingHours: dailyHours,
                      workingDays: days,
                      role: selectedRole,
                      overrideValue: overrideVal,
                      overrideReason: overrideReason,
                      notes: notes.isNotEmpty ? notes : null,
                    );
                nav.pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              child: const Text('Save Capacity', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _openBatchAdjustCapacityDialog(List<SprintCapacityMemberModel> selectedMembers) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hoursController = TextEditingController(text: '40');
    final dailyHoursController = TextEditingController(text: '8.0');
    final daysController = TextEditingController(text: '5');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              const Icon(Icons.tune_rounded, size: 20, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Adjust Capacity for ${selectedMembers.length} Members',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
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
                  'Apply standard capacity to: ${selectedMembers.map((m) => m.fullName).join(", ")}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                const Text('Total Available Capacity (Hours) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                TextField(
                  controller: hoursController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    suffixText: 'hours/member',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Daily Working Hours', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                          const SizedBox(height: 6),
                          TextField(
                            controller: dailyHoursController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              suffixText: 'h/day',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                          const Text('Working Days', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                          const SizedBox(height: 6),
                          TextField(
                            controller: daysController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              suffixText: 'days',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                        ],
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
              onPressed: isSaving ? null : () async {
                setDialogState(() => isSaving = true);
                final capHours = double.tryParse(hoursController.text.trim()) ?? 40.0;
                final dailyHours = double.tryParse(dailyHoursController.text.trim()) ?? 8.0;
                final days = int.tryParse(daysController.text.trim()) ?? 5;

                for (final member in selectedMembers) {
                  await ref.read(workSprintCapacityProvider.notifier).manageMemberCapacity(
                    userId: member.userId,
                    capacityHours: capHours,
                    dailyWorkingHours: dailyHours,
                    workingDays: days,
                    role: member.role,
                  );
                }
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                setState(() => _selectedMemberIds.clear());
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              child: Text(isSaving ? 'Applying...' : 'Apply to ${selectedMembers.length} Members', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemoveSelectedMembers(List<SprintCapacityMemberModel> allMembers) {
    final selected = allMembers.where((m) => _selectedMemberIds.contains(m.userId)).toList();
    if (selected.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${selected.length} Members?'),
        content: Text('Are you sure you want to remove ${selected.map((m) => m.fullName).join(", ")} from this sprint capacity plan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              for (final m in selected) {
                await ref.read(workSprintCapacityProvider.notifier).removeMember(m.userId);
              }
              setState(() => _selectedMemberIds.clear());
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openManageAvailabilityDialog(SprintCapacityMemberModel member) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final startDateController = TextEditingController(text: '2025-01-10');
    final endDateController = TextEditingController(text: '2025-01-10');
    final hoursController = TextEditingController(text: '8.0');
    final reasonController = TextEditingController(text: 'Medical Leave');
    String availabilityType = 'LEAVE';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              const Icon(Icons.event_busy_rounded, size: 20, color: Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Manage Availability: ${member.fullName}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
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
                const Text('Log Time Off or Unavailability Exception', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Start Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                          const SizedBox(height: 6),
                          TextField(
                            controller: startDateController,
                            decoration: InputDecoration(
                              suffixIcon: const Icon(Icons.calendar_today_outlined, size: 16),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                          const Text('End Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                          const SizedBox(height: 6),
                          TextField(
                            controller: endDateController,
                            decoration: InputDecoration(
                              suffixIcon: const Icon(Icons.calendar_today_outlined, size: 16),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Unavailable Hours', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                          const SizedBox(height: 6),
                          TextField(
                            controller: hoursController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              suffixText: 'hours',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                          const Text('Exception Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: availabilityType,
                            dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                            items: ['LEAVE', 'TRAINING', 'EXAM_DUTY', 'OTHER'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                            onChanged: (v) => setDialogState(() => availabilityType = v ?? 'LEAVE'),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Reason / Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Vacation, Medical Leave, Conference...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
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
                final unavailHours = double.tryParse(hoursController.text.trim()) ?? 8.0;
                final nav = Navigator.of(ctx);
                await ref.read(workSprintCapacityProvider.notifier).manageAvailability(
                      userId: member.userId,
                      startDate: startDateController.text.trim(),
                      endDate: endDateController.text.trim(),
                      unavailableHours: unavailHours,
                      reason: reasonController.text.trim(),
                    );
                nav.pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)),
              child: const Text('Log Exception', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _openRebalanceWorkloadDialog(SprintCapacityMemberModel fromMember) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final capState = ref.read(workSprintCapacityProvider);
    final allMembers = capState.dashboard?.members ?? [];
    final eligibleDestinations = allMembers.where((m) => m.userId != fromMember.userId).toList();

    // Fetch sprint work items to pick which item to reassign
    final api = ref.read(workApiServiceProvider);
    final dash = await api.getSprintDashboard(widget.sprintId);
    final items = (dash['items'] as List<WorkItemModel>?) ?? [];

    if (!mounted) return;

    if (eligibleDestinations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other team members available to rebalance workload.')),
      );
      return;
    }

    String selectedDestinationId = eligibleDestinations.first.userId;
    String? selectedItemId = items.isNotEmpty ? items.first.id : null;
    final reasonController = TextEditingController(text: 'Workload balancing from ${fromMember.fullName}');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final targetMember = eligibleDestinations.firstWhere(
            (m) => m.userId == selectedDestinationId,
            orElse: () => eligibleDestinations.first,
          );

          final selectedItem = items.firstWhere(
            (it) => it.id == selectedItemId,
            orElse: () => items.isNotEmpty
                ? items.first
                : const WorkItemModel(
                    id: 'temp',
                    itemNumber: 'TK-1001',
                    title: 'Sprint Task',
                    workType: 'TASK',
                    status: 'NEW',
                    priority: 'MEDIUM',
                  ),
          );

          final itemHours = selectedItem.remainingHours > 0 ? selectedItem.remainingHours : (selectedItem.estimatedHours > 0 ? selectedItem.estimatedHours : 5.0);

          // Projected values
          final projectedFromHours = (fromMember.plannedHours - itemHours).clamp(0.0, 999.0);
          final projectedFromUtil = fromMember.capacityHours > 0 ? ((projectedFromHours / fromMember.capacityHours) * 100) : 0.0;

          final projectedTargetHours = targetMember.plannedHours + itemHours;
          final projectedTargetUtil = targetMember.capacityHours > 0 ? ((projectedTargetHours / targetMember.capacityHours) * 100) : 0.0;

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Row(
              children: [
                Icon(Icons.sync_alt_rounded, size: 20, color: Color(0xFF2563EB)),
                SizedBox(width: 8),
                Text('Rebalance Team Workload', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 20, color: Color(0xFFEF4444)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Source Member: ${fromMember.fullName} (${fromMember.status})',
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                                ),
                                Text(
                                  'Current: ${fromMember.plannedHours.toStringAsFixed(0)}h / ${fromMember.capacityHours.toStringAsFixed(0)}h (${fromMember.utilizationPct.toStringAsFixed(1)}% utilization)',
                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFFB91C1C)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Select Work Item to Transfer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedItemId,
                      isExpanded: true,
                      dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                      items: items.map((it) {
                        return DropdownMenuItem(
                          value: it.id,
                          child: Text(
                            '${it.itemNumber} - ${it.title} (${it.estimatedHours > 0 ? it.estimatedHours.toStringAsFixed(0) : 5}h)',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setDialogState(() => selectedItemId = v),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Reassign To (Destination Member)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedDestinationId,
                      isExpanded: true,
                      dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                      items: eligibleDestinations.map((m) {
                        return DropdownMenuItem(
                          value: m.userId,
                          child: Text(
                            '${m.fullName} (${m.role}) - ${m.plannedHours.toStringAsFixed(0)}h/${m.capacityHours.toStringAsFixed(0)}h (${m.utilizationPct.toStringAsFixed(1)}%)',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setDialogState(() => selectedDestinationId = v ?? selectedDestinationId),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // LIVE CAPACITY IMPACT PREVIEW
                    const Text('Live Capacity Rebalance Preview', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(fromMember.fullName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              Text(
                                '${fromMember.utilizationPct.toStringAsFixed(1)}% ➔ ${projectedFromUtil.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: projectedFromUtil <= 100 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (projectedFromUtil / 100).clamp(0.0, 1.0),
                              backgroundColor: const Color(0xFFE2E8F0),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                projectedFromUtil <= 100 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              ),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(targetMember.fullName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              Text(
                                '${targetMember.utilizationPct.toStringAsFixed(1)}% ➔ ${projectedTargetUtil.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: projectedTargetUtil <= 100 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (projectedTargetUtil / 100).clamp(0.0, 1.0),
                              backgroundColor: const Color(0xFFE2E8F0),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                projectedTargetUtil <= 100 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Reassignment Reason', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: reasonController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  if (selectedItemId != null) {
                    final nav = Navigator.of(ctx);
                    await ref.read(workSprintCapacityProvider.notifier).rebalanceWorkload(
                          workItemId: selectedItemId!,
                          fromUserId: fromMember.userId,
                          toUserId: selectedDestinationId,
                          reason: reasonController.text.trim(),
                        );
                    nav.pop();
                  }
                },
                icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                label: const Text('Confirm Rebalance', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _triggerExportCsv() async {
    final csv = await ref.read(workSprintCapacityProvider.notifier).exportCsv();
    if (!mounted) return;
    if (csv != null) {
      await Clipboard.setData(ClipboardData(text: csv));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Capacity data exported and copied to clipboard as CSV!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to export capacity data.')),
      );
    }
  }

  // ==========================================
  // BUILD METHOD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final capState = ref.watch(workSprintCapacityProvider);
    final dash = capState.dashboard;

    if (capState.isLoading && dash == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: Color(0xFF2563EB)),
        ),
      );
    }

    if (dash == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 40, color: Color(0xFFEF4444)),
              const SizedBox(height: 12),
              Text(
                capState.errorMessage ?? 'No capacity data available for this sprint.',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.read(workSprintCapacityProvider.notifier).loadCapacity(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1080;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 0. TOP SCOPE FILTERS (Sprint & Team Dropdowns + Refresh)
              _buildTopScreenFiltersBar(dash, capState, isDark),
              const SizedBox(height: 14),

              // 1. TOP HERO & 6 KPI PILLS ROW
              _buildTopKpiRow(dash, isDark, constraints.maxWidth),
              const SizedBox(height: 16),

              // 2. TWO-COLUMN WORKLOAD & CAPACITY LAYOUT
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEFT COLUMN (Daily Grouped Bar Chart + Team Member Table)
                    Expanded(
                      flex: 68,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDailyGroupedBarChartCard(dash, isDark),
                          const SizedBox(height: 16),
                          _buildTeamMemberWorkloadTableCard(dash, isDark),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // RIGHT COLUMN (Donut Chart + Summary + Insights)
                    Expanded(
                      flex: 32,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCapacityUtilizationDonutCard(dash, isDark),
                          const SizedBox(height: 16),
                          _buildCapacitySummaryCard(dash, isDark),
                          const SizedBox(height: 16),
                          _buildCapacityInsightsCard(dash, isDark),
                        ],
                      ),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDailyGroupedBarChartCard(dash, isDark),
                    const SizedBox(height: 16),
                    _buildTeamMemberWorkloadTableCard(dash, isDark),
                    const SizedBox(height: 16),
                    _buildCapacityUtilizationDonutCard(dash, isDark),
                    const SizedBox(height: 16),
                    _buildCapacitySummaryCard(dash, isDark),
                    const SizedBox(height: 16),
                    _buildCapacityInsightsCard(dash, isDark),
                  ],
                ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // 0. TOP SCREEN FILTERS ROW (Sprint & Team scope)
  // ==========================================

  Widget _buildTopScreenFiltersBar(
    SprintCapacityDashboardModel dash,
    WorkSprintCapacityState capState,
    bool isDark,
  ) {
    final allSprints = ref.watch(allSprintsProvider).sprints;
    final sprintItems = <Map<String, String>>[];
    if (allSprints.isNotEmpty) {
      for (final s in allSprints) {
        sprintItems.add({
          'id': s.id,
          'label': '${s.name} (${s.status})',
          'name': s.name,
        });
      }
    } else if (dash.sprints.isNotEmpty) {
      for (final s in dash.sprints) {
        sprintItems.add({
          'id': s.id,
          'label': '${s.name} (${s.status})',
          'name': s.name,
        });
      }
    } else {
      sprintItems.add({'id': widget.sprintId, 'label': dash.sprintName, 'name': dash.sprintName});
    }

    final teamItems = <String>['All Teams'];
    if (dash.teams.isNotEmpty) {
      for (final t in dash.teams) {
        if (!teamItems.contains(t.name)) {
          teamItems.add(t.name);
        }
      }
    } else if (capState.availableTeams.isNotEmpty) {
      for (final t in capState.availableTeams) {
        if (!teamItems.contains(t.name)) {
          teamItems.add(t.name);
        }
      }
    } else {
      teamItems.addAll([
        'Digital Campus Team',
        'Academic Systems Team',
        'Examination Team',
        'IT Operations Team',
        'Infrastructure & Maintenance Team',
        'Library Systems Team',
      ]);
    }

    String currentSprintId = capState.sprintId;
    if (!sprintItems.any((s) => s['id'] == currentSprintId)) {
      final match = sprintItems.firstWhere(
        (s) => s['name'] == dash.sprintName,
        orElse: () => sprintItems.first,
      );
      currentSprintId = match['id']!;
    }

    String currentTeam = capState.selectedTeam;
    if (!teamItems.contains(currentTeam)) {
      currentTeam = teamItems.first;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13182C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tune_rounded, size: 18, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 8),
              const Text(
                'Capacity Scope Filters',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // 1. Sprint Selector Dropdown
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.directions_run_rounded, size: 16, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    const Text('Sprint:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                    const SizedBox(width: 6),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: currentSprintId,
                        dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        icon: const Icon(Icons.arrow_drop_down_rounded, size: 20),
                        items: sprintItems.map((s) {
                          return DropdownMenuItem<String>(
                            value: s['id'],
                            child: Text(s['label']!),
                          );
                        }).toList(),
                        onChanged: (newSid) {
                          if (newSid != null) {
                            ref.read(workSprintCapacityProvider.notifier).selectSprint(newSid);
                            widget.onSprintChanged?.call(newSid);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Team Selector Dropdown
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.groups_rounded, size: 16, color: Color(0xFF10B981)),
                    const SizedBox(width: 8),
                    const Text('Team:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                    const SizedBox(width: 6),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: currentTeam,
                        dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        icon: const Icon(Icons.arrow_drop_down_rounded, size: 20),
                        items: teamItems.map((teamName) {
                          return DropdownMenuItem<String>(
                            value: teamName,
                            child: Text(teamName),
                          );
                        }).toList(),
                        onChanged: (newTeam) {
                          if (newTeam != null) {
                            ref.read(workSprintCapacityProvider.notifier).selectTeam(newTeam);
                            widget.onTeamChanged?.call(newTeam);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Quick Refresh Button
              IconButton(
                tooltip: 'Refresh Capacity Data',
                onPressed: () {
                  ref.read(workSprintCapacityProvider.notifier).loadCapacity(forceRefresh: true);
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  padding: const EdgeInsets.all(8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 1. TOP HERO & 6 KPI PILLS ROW
  // ==========================================

  Widget _buildTopKpiRow(SprintCapacityDashboardModel dash, bool isDark, double availableWidth) {
    final kpis = dash.kpis;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13182C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isLarge = constraints.maxWidth >= 1380;

          final heroWidget = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.groups_rounded, color: Color(0xFF2563EB), size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dash.selectedTeam,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${dash.sprintName} (${dash.sprintDuration})',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          );

          final kpiCards = [
            _buildKpiPill('Team Members', '${kpis.teamMembers}', Icons.person_outline_rounded, const Color(0xFF2563EB), isDark),
            _buildKpiPill('Total Capacity', '${kpis.totalCapacityHours.toStringAsFixed(0)} h', Icons.calendar_today_outlined, const Color(0xFF2563EB), isDark),
            _buildKpiPill('Planned Work', '${kpis.plannedWorkHours.toStringAsFixed(0)} h', Icons.layers_outlined, const Color(0xFF2563EB), isDark),
            _buildKpiPill('Remaining', '${kpis.remainingCapacityHours.toStringAsFixed(0)} h', Icons.sync_rounded, const Color(0xFF10B981), isDark, valueColor: const Color(0xFF10B981)),
            _buildKpiPill('Utilization', '${kpis.utilizationPct.toStringAsFixed(1)}%', Icons.speed_rounded, const Color(0xFF2563EB), isDark),
            _buildKpiPill('Over Allocation', kpis.overAllocationHours.toStringAsFixed(0), Icons.warning_amber_rounded, const Color(0xFFEF4444), isDark, valueColor: const Color(0xFFEF4444)),
          ];

          if (isLarge) {
            return Row(
              children: [
                heroWidget,
                const SizedBox(width: 16),
                const SizedBox(height: 36, child: VerticalDivider(width: 1, color: Color(0xFFE2E8F0))),
                const SizedBox(width: 16),
                Expanded(
                  child: Row(
                    children: kpiCards
                        .map((card) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: card,
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            );
          } else {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heroWidget,
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: kpiCards,
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildKpiPill(
    String label,
    String value,
    IconData icon,
    Color iconColor,
    bool isDark, {
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: valueColor ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. DAILY GROUPED BAR CHART CARD
  // ==========================================

  Widget _buildDailyGroupedBarChartCard(SprintCapacityDashboardModel dash, bool isDark) {
    final daily = dash.dailyChart;

    // Calculate dynamic upper bound for bar chart
    double maxBarValue = 0.0;
    for (final pt in daily) {
      if (pt.capacityHours > maxBarValue) maxBarValue = pt.capacityHours;
      if (pt.plannedHours > maxBarValue) maxBarValue = pt.plannedHours;
      if (pt.actualHours > maxBarValue) maxBarValue = pt.actualHours;
    }
    final dynamicMaxY = maxBarValue > 0 ? (((maxBarValue * 1.25) / 6).ceil() * 6.0).clamp(42.0, 200.0) : 42.0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13182C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Info Icon & Legend
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Capacity vs Workload (Daily)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Tooltip(
                    message: 'Daily planned effort and actual recorded work compared to standard team capacity.',
                    child: Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
              // Legend
              Wrap(
                spacing: 14,
                children: [
                  _buildLegendIndicator('Capacity (h)', const Color(0xFF2563EB)),
                  _buildLegendIndicator('Planned (h)', const Color(0xFF60A5FA)),
                  _buildLegendIndicator('Actual (h)', const Color(0xFF10B981)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Grouped Bar Chart
          SizedBox(
            height: 220,
            child: daily.isEmpty
                ? const Center(child: Text('No daily tracking records found.', style: TextStyle(color: Color(0xFF64748B))))
                : BarChart(
                    BarChartData(
                      maxY: dynamicMaxY,
                      minY: 0,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          tooltipRoundedRadius: 8,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            if (groupIndex >= daily.length) return null;
                            final pt = daily[groupIndex];
                            return BarTooltipItem(
                              '${pt.dateFmt}\n',
                              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              children: [
                                TextSpan(
                                  text: 'Capacity: ${pt.capacityHours.toStringAsFixed(0)}h\n',
                                  style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 11),
                                ),
                                TextSpan(
                                  text: 'Planned: ${pt.plannedHours.toStringAsFixed(0)}h\n',
                                  style: const TextStyle(color: Color(0xFFBAE6FD), fontSize: 11),
                                ),
                                TextSpan(
                                  text: 'Actual: ${pt.actualHours.toStringAsFixed(0)}h',
                                  style: const TextStyle(color: Color(0xFF86EFAC), fontSize: 11),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: 6,
                            getTitlesWidget: (val, meta) {
                              if (val % 6 != 0 || val > dynamicMaxY) return const SizedBox.shrink();
                              return Text(
                                val.toInt().toString(),
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, meta) {
                              final idx = val.toInt();
                              if (idx >= 0 && idx < daily.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    daily[idx].dateFmt,
                                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 10.5),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 6,
                        getDrawingHorizontalLine: (val) => FlLine(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(daily.length, (idx) {
                        final pt = daily[idx];
                        return BarChartGroupData(
                          x: idx,
                          barsSpace: 3,
                          barRods: [
                            BarChartRodData(
                              toY: pt.capacityHours,
                              color: const Color(0xFF2563EB),
                              width: 6,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                            ),
                            BarChartRodData(
                              toY: pt.plannedHours,
                              color: const Color(0xFF60A5FA),
                              width: 6,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                            ),
                            BarChartRodData(
                              toY: pt.actualHours,
                              color: const Color(0xFF10B981),
                              width: 6,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendIndicator(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  // ==========================================
  // 3. TEAM MEMBER CAPACITY & WORKLOAD TABLE CARD
  // ==========================================

  // ==========================================
  // 3. TEAM MEMBER CAPACITY & WORKLOAD TABLE CARD
  // ==========================================

  Widget _buildTeamMemberWorkloadTableCard(SprintCapacityDashboardModel dash, bool isDark) {
    final capState = ref.watch(workSprintCapacityProvider);
    final rawMembers = dash.members.isNotEmpty ? dash.members : capState.allMembers;
    final filteredMembers = _getFilteredAndSortedMembers(rawMembers, capState);
    final totalCount = dash.pagination.totalMembers > 0
        ? dash.pagination.totalMembers
        : filteredMembers.length;
    final totalPages = dash.pagination.totalPages > 0
        ? dash.pagination.totalPages
        : (totalCount > 0 ? (totalCount / capState.rowsPerPage).ceil() : 1);
    final page = capState.currentPage.clamp(1, totalPages < 1 ? 1 : totalPages);

    // Paginated slice: if dash.members is already a paginated page from server, use it directly;
    // otherwise (or if client filtered), slice the filtered list
    final displayedMembers = (dash.pagination.totalMembers > 0 && dash.members.length <= capState.rowsPerPage && capState.searchQuery.isEmpty && capState.selectedRole == 'All' && capState.selectedStatus == 'All')
        ? dash.members
        : (filteredMembers.length > capState.rowsPerPage
            ? filteredMembers.skip((page - 1) * capState.rowsPerPage).take(capState.rowsPerPage).toList()
            : filteredMembers);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13182C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Action Buttons
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Team Member Capacity & Workload ($totalCount)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  if (_selectedMemberIds.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_selectedMemberIds.length} selected',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => setState(() => _selectedMemberIds.clear()),
                            child: const Icon(Icons.close_rounded, size: 13, color: Color(0xFF2563EB)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  OutlinedButton.icon(
                    onPressed: _openAddMemberDialog,
                    icon: const Icon(Icons.add_rounded, size: 14, color: Color(0xFF2563EB)),
                    label: const Text('Add Team Member', style: TextStyle(fontSize: 11.5, color: Color(0xFF2563EB))),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      side: const BorderSide(color: Color(0xFF2563EB)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      if (_selectedMemberIds.isNotEmpty) {
                        final selected = rawMembers.where((m) => _selectedMemberIds.contains(m.userId)).toList();
                        if (selected.length == 1) {
                          _openAdjustCapacityDialog(selected.first);
                        } else {
                          _openBatchAdjustCapacityDialog(selected);
                        }
                      } else if (displayedMembers.isNotEmpty) {
                        _openAdjustCapacityDialog(displayedMembers.first);
                      }
                    },
                    icon: const Icon(Icons.edit_note_rounded, size: 14, color: Color(0xFF475569)),
                    label: Text(
                      _selectedMemberIds.isNotEmpty ? 'Adjust Capacity (${_selectedMemberIds.length})' : 'Adjust Capacity',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      side: BorderSide(color: _selectedMemberIds.isNotEmpty ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                  if (_selectedMemberIds.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => _confirmRemoveSelectedMembers(rawMembers),
                      icon: const Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFEF4444)),
                      label: Text('Remove (${_selectedMemberIds.length})', style: const TextStyle(fontSize: 11.5, color: Color(0xFFEF4444))),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: _triggerExportCsv,
                    icon: const Icon(Icons.file_download_outlined, size: 14, color: Color(0xFF475569)),
                    label: const Text('Export', style: TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // GRID POWERFUL FILTERS TOOLBAR
          _buildGridFiltersBar(dash, capState, isDark),
          const SizedBox(height: 16),

          // Horizontal scroll wrapper for responsive table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: true,
              onSelectAll: (all) {
                setState(() {
                  if (all == true) {
                    _selectedMemberIds = displayedMembers.map((m) => m.userId).toSet();
                  } else {
                    _selectedMemberIds.clear();
                  }
                });
              },
              columnSpacing: 18,
              horizontalMargin: 8,
              headingRowHeight: 38,
              dataRowMinHeight: 46,
              dataRowMaxHeight: 48,
              headingRowColor: WidgetStateProperty.all(
                isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              ),
              columns: [
                DataColumn(label: _buildSortableHeader('Team Member', 'name', capState.sortBy, capState.sortOrder, isDark)),
                DataColumn(label: _buildSortableHeader('Role', 'role', capState.sortBy, capState.sortOrder, isDark)),
                DataColumn(label: _buildSortableHeader('Capacity (h)', 'capacity', capState.sortBy, capState.sortOrder, isDark)),
                DataColumn(label: _buildSortableHeader('Planned (h)', 'planned', capState.sortBy, capState.sortOrder, isDark)),
                DataColumn(label: _buildSortableHeader('Actual (h)', 'actual', capState.sortBy, capState.sortOrder, isDark)),
                DataColumn(label: _buildSortableHeader('Remaining (h)', 'remaining', capState.sortBy, capState.sortOrder, isDark)),
                DataColumn(label: _buildSortableHeader('Utilization', 'utilization', capState.sortBy, capState.sortOrder, isDark)),
                DataColumn(label: _buildSortableHeader('Work Items', 'work_items', capState.sortBy, capState.sortOrder, isDark)),
                DataColumn(label: _buildSortableHeader('Status', 'status', capState.sortBy, capState.sortOrder, isDark)),
                const DataColumn(label: Text('Actions', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold))),
              ],
              rows: displayedMembers.map((m) {
                final isSelected = _selectedMemberIds.contains(m.userId);
                final isOverloaded = m.status == 'Overloaded' || m.utilizationPct > 100.0;
                final isHigh = m.status == 'High';

                final barColor = isOverloaded
                    ? const Color(0xFFEF4444)
                    : (isHigh ? const Color(0xFFF59E0B) : const Color(0xFF10B981));

                return DataRow(
                  selected: isSelected,
                  onSelectChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selectedMemberIds.add(m.userId);
                      } else {
                        _selectedMemberIds.remove(m.userId);
                      }
                    });
                  },
                  cells: [
                    // Member Avatar & Name
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 13,
                            backgroundColor: const Color(0xFFEFF6FF),
                            child: Text(
                              m.fullName.isNotEmpty ? m.fullName.substring(0, 1).toUpperCase() : 'U',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            m.fullName,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Role
                    DataCell(Text(m.role, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                    // Capacity (h)
                    DataCell(Text('${m.capacityHours.toStringAsFixed(0)} h', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                    // Planned (h)
                    DataCell(Text('${m.plannedHours.toStringAsFixed(0)} h', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                    // Actual (h)
                    DataCell(Text('${m.actualHours.toStringAsFixed(0)} h', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                    // Remaining (h)
                    DataCell(Text('${m.remainingHours.toStringAsFixed(0)} h', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                    // Utilization % with progress bar
                    DataCell(
                      SizedBox(
                        width: 90,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  '${m.utilizationPct.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: barColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: (m.utilizationPct / 100).clamp(0.0, 1.0),
                                backgroundColor: const Color(0xFFE2E8F0),
                                valueColor: AlwaysStoppedAnimation<Color>(barColor),
                                minHeight: 4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Work Items
                    DataCell(Text('${m.workItemsCount}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                    // Status Badge
                    DataCell(_buildStatusBadge(m.status)),
                    // Actions Menu
                    DataCell(
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, size: 16, color: Color(0xFF64748B)),
                        tooltip: 'Actions',
                        onSelected: (val) {
                          switch (val) {
                            case 'adjust':
                              _openAdjustCapacityDialog(m);
                              break;
                            case 'availability':
                              _openManageAvailabilityDialog(m);
                              break;
                            case 'rebalance':
                              _openRebalanceWorkloadDialog(m);
                              break;
                            case 'remove':
                              ref.read(workSprintCapacityProvider.notifier).removeMember(m.userId);
                              break;
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(value: 'adjust', child: Text('Adjust Capacity', style: TextStyle(fontSize: 12.5))),
                          const PopupMenuItem(value: 'availability', child: Text('Manage Availability', style: TextStyle(fontSize: 12.5))),
                          const PopupMenuItem(value: 'rebalance', child: Text('Rebalance Workload', style: TextStyle(fontSize: 12.5))),
                          const PopupMenuDivider(),
                          const PopupMenuItem(value: 'remove', child: Text('Remove from Sprint', style: TextStyle(fontSize: 12.5, color: Color(0xFFEF4444)))),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),

          // Empty state if no items
          if (displayedMembers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.search_off_rounded, size: 36, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 8),
                    const Text('No members found matching the selected filters.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        _gridSearchController.clear();
                        ref.read(workSprintCapacityProvider.notifier).resetFilters();
                      },
                      child: const Text('Reset All Filters'),
                    ),
                  ],
                ),
              ),
            ),

          // POWERFUL PAGINATION FOOTER
          const SizedBox(height: 12),
          _buildPaginationFooter(totalCount, page, capState.rowsPerPage, totalPages, isDark),
        ],
      ),
    );
  }

  // ==========================================
  // GRID FILTERS TOOLBAR
  // ==========================================

  Widget _buildGridFiltersBar(
    SprintCapacityDashboardModel dash,
    WorkSprintCapacityState capState,
    bool isDark,
  ) {
    final availableRoles = <String>{'All'};
    for (final m in dash.members) {
      if (m.role.isNotEmpty) availableRoles.add(m.role);
    }
    for (final m in capState.allMembers) {
      if (m.role.isNotEmpty) availableRoles.add(m.role);
    }
    final standardRoles = [
      'Team Lead', 'Senior Developer', 'Backend Developer', 'UI/UX Designer',
      'QA Engineer', 'DevOps Engineer', 'System Analyst', 'Developer',
      'Scrum Master', 'Teacher', 'Staff'
    ];
    availableRoles.addAll(standardRoles);
    final roleList = availableRoles.toList();

    final statusList = ['All', 'Overloaded', 'High', 'Balanced', 'Underallocated'];

    final hasActiveFilters = capState.searchQuery.isNotEmpty ||
        capState.selectedRole != 'All' ||
        capState.selectedStatus != 'All';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // 1. Search Box
            SizedBox(
              width: 280,
              height: 38,
              child: TextField(
                controller: _gridSearchController,
                onChanged: (val) {
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                    ref.read(workSprintCapacityProvider.notifier).setSearch(val.trim());
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search member by name, role...',
                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 17, color: Color(0xFF64748B)),
                  suffixIcon: _gridSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 15),
                          onPressed: () {
                            _gridSearchController.clear();
                            ref.read(workSprintCapacityProvider.notifier).setSearch('');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                ),
                style: const TextStyle(fontSize: 12.5),
              ),
            ),

            // 2. Role Dropdown Filter
            Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.badge_outlined, size: 15, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  const Text('Role:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  const SizedBox(width: 6),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: roleList.contains(capState.selectedRole) ? capState.selectedRole : 'All',
                      dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      items: roleList.map((r) {
                        return DropdownMenuItem<String>(
                          value: r,
                          child: Text(r == 'All' ? 'All Roles' : r),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          ref.read(workSprintCapacityProvider.notifier).setRoleFilter(val);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            // 3. Workload Status Dropdown Filter
            Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.speed_rounded, size: 15, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  const Text('Status:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  const SizedBox(width: 6),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: statusList.contains(capState.selectedStatus) ? capState.selectedStatus : 'All',
                      dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      items: statusList.map((s) {
                        return DropdownMenuItem<String>(
                          value: s,
                          child: Text(s == 'All' ? 'All Statuses' : s),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          ref.read(workSprintCapacityProvider.notifier).setStatusFilter(val);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            // 4. Reset Filters Button
            if (hasActiveFilters)
              TextButton.icon(
                onPressed: () {
                  _gridSearchController.clear();
                  ref.read(workSprintCapacityProvider.notifier).resetFilters();
                },
                icon: const Icon(Icons.filter_alt_off_rounded, size: 15, color: Color(0xFFEF4444)),
                label: const Text('Reset Filters', style: TextStyle(fontSize: 12, color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
          ],
        ),

        // Active Filter Chips Row
        if (hasActiveFilters) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Active filters:',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              ),
              if (capState.searchQuery.isNotEmpty)
                _buildFilterBadge('Search: "${capState.searchQuery}"', () {
                  _gridSearchController.clear();
                  ref.read(workSprintCapacityProvider.notifier).setSearch('');
                }),
              if (capState.selectedRole != 'All')
                _buildFilterBadge('Role: ${capState.selectedRole}', () {
                  ref.read(workSprintCapacityProvider.notifier).setRoleFilter('All');
                }),
              if (capState.selectedStatus != 'All')
                _buildFilterBadge('Status: ${capState.selectedStatus}', () {
                  ref.read(workSprintCapacityProvider.notifier).setStatusFilter('All');
                }),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildFilterBadge(String label, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, size: 12, color: Color(0xFF2563EB)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SORTABLE COLUMN HEADER
  // ==========================================

  Widget _buildSortableHeader(
    String label,
    String columnKey,
    String currentSortBy,
    String currentSortOrder,
    bool isDark,
  ) {
    final isSelected = currentSortBy.toLowerCase() == columnKey.toLowerCase();
    final isAsc = currentSortOrder.toLowerCase() == 'asc';

    return InkWell(
      onTap: () {
        ref.read(workSprintCapacityProvider.notifier).setSorting(columnKey);
      },
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.bold,
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF1E293B)),
              ),
            ),
            const SizedBox(width: 4),
            if (isSelected)
              Icon(
                isAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                size: 14,
                color: const Color(0xFF2563EB),
              )
            else
              const Icon(
                Icons.unfold_more_rounded,
                size: 13,
                color: Color(0xFF94A3B8),
              ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // PAGINATION FOOTER
  // ==========================================

  Widget _buildPaginationFooter(
    int totalCount,
    int currentPage,
    int rowsPerPage,
    int totalPages,
    bool isDark,
  ) {
    final from = totalCount == 0 ? 0 : (currentPage - 1) * rowsPerPage + 1;
    final to = (currentPage * rowsPerPage).clamp(0, totalCount);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 10,
        children: [
          // Left: Showing X – Y of Z & Rows per page
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Showing $from – $to of $totalCount members',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Rows per page:',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: rowsPerPage,
                  dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  items: [5, 10, 20, 50].map((n) {
                    return DropdownMenuItem<int>(
                      value: n,
                      child: Text('$n'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(workSprintCapacityProvider.notifier).setRowsPerPage(val);
                    }
                  },
                ),
              ),
            ],
          ),

          // Right: Page navigation buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.first_page_rounded, size: 18),
                tooltip: 'First Page',
                onPressed: currentPage > 1
                    ? () => ref.read(workSprintCapacityProvider.notifier).setPage(1)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                tooltip: 'Previous Page',
                onPressed: currentPage > 1
                    ? () => ref.read(workSprintCapacityProvider.notifier).setPage(currentPage - 1)
                    : null,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Page $currentPage of ${totalPages < 1 ? 1 : totalPages}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                tooltip: 'Next Page',
                onPressed: currentPage < totalPages
                    ? () => ref.read(workSprintCapacityProvider.notifier).setPage(currentPage + 1)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.last_page_rounded, size: 18),
                tooltip: 'Last Page',
                onPressed: currentPage < totalPages
                    ? () => ref.read(workSprintCapacityProvider.notifier).setPage(totalPages)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // CLIENT-SIDE FILTER & SORT HELPER
  // ==========================================

  List<SprintCapacityMemberModel> _getFilteredAndSortedMembers(
    List<SprintCapacityMemberModel> members,
    WorkSprintCapacityState capState,
  ) {
    var list = List<SprintCapacityMemberModel>.from(members);

    if (capState.searchQuery.trim().isNotEmpty) {
      final q = capState.searchQuery.trim().toLowerCase();
      list = list.where((m) =>
        m.fullName.toLowerCase().contains(q) ||
        m.role.toLowerCase().contains(q) ||
        (m.email != null && m.email!.toLowerCase().contains(q))
      ).toList();
    }

    if (capState.selectedRole != 'All') {
      list = list.where((m) => m.role.toLowerCase() == capState.selectedRole.toLowerCase()).toList();
    }

    if (capState.selectedStatus != 'All') {
      final s = capState.selectedStatus.toLowerCase();
      list = list.where((m) {
        if (s == 'overloaded') return m.status.toLowerCase() == 'overloaded' || m.utilizationPct > 100.0;
        if (s == 'high') return m.status.toLowerCase() == 'high' || (m.utilizationPct >= 90.0 && m.utilizationPct <= 100.0);
        if (s == 'balanced') return m.status.toLowerCase() == 'balanced' || (m.utilizationPct >= 70.0 && m.utilizationPct < 90.0);
        if (s == 'underallocated') return m.status.toLowerCase() == 'underallocated' || m.utilizationPct < 70.0;
        return m.status.toLowerCase() == s;
      }).toList();
    }

    list.sort((a, b) {
      int cmp = 0;
      switch (capState.sortBy.toLowerCase()) {
        case 'role':
          cmp = a.role.compareTo(b.role);
          break;
        case 'capacity':
          cmp = a.capacityHours.compareTo(b.capacityHours);
          break;
        case 'planned':
          cmp = a.plannedHours.compareTo(b.plannedHours);
          break;
        case 'actual':
          cmp = a.actualHours.compareTo(b.actualHours);
          break;
        case 'remaining':
          cmp = a.remainingHours.compareTo(b.remainingHours);
          break;
        case 'utilization':
          cmp = a.utilizationPct.compareTo(b.utilizationPct);
          break;
        case 'work_items':
          cmp = a.workItemsCount.compareTo(b.workItemsCount);
          break;
        case 'status':
          cmp = a.status.compareTo(b.status);
          break;
        case 'name':
        default:
          cmp = a.fullName.compareTo(b.fullName);
          break;
      }
      return capState.sortOrder.toLowerCase() == 'desc' ? -cmp : cmp;
    });

    return list;
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;

    switch (status.toUpperCase()) {
      case 'OVERLOADED':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        break;
      case 'HIGH':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        break;
      case 'BALANCED':
      default:
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  // ==========================================
  // 4. CAPACITY UTILIZATION DONUT CARD
  // ==========================================

  Widget _buildCapacityUtilizationDonutCard(SprintCapacityDashboardModel dash, bool isDark) {
    final util = dash.utilization;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13182C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Capacity Utilization',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 18),

          // Circular Donut with Center Utilization Text
          Center(
            child: SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 48,
                      startDegreeOffset: -90,
                      sections: [
                        PieChartSectionData(
                          value: util.plannedPct > 0 ? util.plannedPct : 91.8,
                          color: const Color(0xFF10B981),
                          radius: 14,
                          showTitle: false,
                        ),
                        PieChartSectionData(
                          value: util.availablePct > 0 ? util.availablePct : 8.2,
                          color: const Color(0xFF93C5FD),
                          radius: 14,
                          showTitle: false,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${util.plannedPct.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const Text(
                        'Utilization',
                        style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Legend / Stats below chart
          Row(
            children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              const Expanded(
                child: Text('Planned Work', style: TextStyle(fontSize: 12, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 6),
              Text(
                '${util.plannedHours.toStringAsFixed(0)} h (${util.plannedPct.toStringAsFixed(1)}%)',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF93C5FD), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              const Expanded(
                child: Text('Available Capacity', style: TextStyle(fontSize: 12, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 6),
              Text(
                '${util.availableHours.toStringAsFixed(0)} h (${util.availablePct.toStringAsFixed(1)}%)',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Capacity', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
              Text(
                '${util.totalCapacityHours.toStringAsFixed(0)} h',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 5. CAPACITY SUMMARY CARD
  // ==========================================

  Widget _buildCapacitySummaryCard(SprintCapacityDashboardModel dash, bool isDark) {
    final summary = dash.summary;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13182C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Capacity Summary',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 6),
              const Tooltip(
                message: 'Aggregated commitment and execution figures for this team during the sprint.',
                child: Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildSummaryRow('Total Team Capacity', summary.totalTeamCapacity, Icons.groups_outlined),
          const SizedBox(height: 10),
          _buildSummaryRow('Planned / Committed Work', summary.plannedCommittedWork, Icons.layers_outlined),
          const SizedBox(height: 10),
          _buildSummaryRow('Actual Work (Completed)', summary.actualWorkCompleted, Icons.play_circle_outline_rounded),
          const SizedBox(height: 10),
          _buildSummaryRow('Remaining Capacity', summary.remainingCapacity, Icons.hourglass_bottom_rounded),
          const SizedBox(height: 10),
          _buildSummaryRow('Utilization', summary.utilization, Icons.speed_rounded),
          const SizedBox(height: 10),
          _buildSummaryRow('Over Allocation', summary.overAllocation, Icons.bolt_rounded),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // ==========================================
  // 6. CAPACITY INSIGHTS CARD
  // ==========================================

  Widget _buildCapacityInsightsCard(SprintCapacityDashboardModel dash, bool isDark) {
    final insights = dash.insights;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13182C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded, size: 16, color: Color(0xFFF59E0B)),
              const SizedBox(width: 6),
              Text(
                'Capacity Insights',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (insights.isEmpty)
            const Text('No capacity recommendations generated.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B)))
          else
            ...insights.map((ins) {
              Color iconColor;
              IconData iconData;

              switch (ins.type.toUpperCase()) {
                case 'SUCCESS':
                  iconColor = const Color(0xFF10B981);
                  iconData = Icons.check_circle_rounded;
                  break;
                case 'WARNING':
                  iconColor = const Color(0xFFF59E0B);
                  iconData = Icons.warning_amber_rounded;
                  break;
                case 'INFO':
                default:
                  iconColor = const Color(0xFF2563EB);
                  iconData = Icons.info_outline_rounded;
                  break;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(iconData, size: 16, color: iconColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ins.text,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
