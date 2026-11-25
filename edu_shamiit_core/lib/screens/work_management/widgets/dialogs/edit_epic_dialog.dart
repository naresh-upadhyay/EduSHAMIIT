import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/work_models.dart';
import '../../providers/work_management_provider.dart';
import '../../utils/work_filter_helper.dart';

class EditEpicDialog extends ConsumerStatefulWidget {
  final BacklogEpicModel epic;

  const EditEpicDialog({
    super.key,
    required this.epic,
  });

  @override
  ConsumerState<EditEpicDialog> createState() => _EditEpicDialogState();
}

class _EditEpicDialogState extends ConsumerState<EditEpicDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _estimateController;
  late TextEditingController _pointsController;

  late String _status;
  late String _priority;
  late String _category;
  String? _selectedTeamName;

  DateTime? _startDate;
  DateTime? _dueDate;
  bool _isSubmitting = false;

  final List<String> _statuses = ['NEW', 'ACTIVE', 'RESOLVED', 'COMPLETED'];
  final List<String> _priorities = ['LOW', 'MEDIUM', 'HIGH', 'URGENT', 'CRITICAL'];
  final List<String> _categories = [
    'Academics',
    'IT Services',
    'Facilities',
    'Administration',
    'Digital Campus',
    'General',
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.epic.title);
    _descController = TextEditingController(text: widget.epic.description);
    _estimateController = TextEditingController(
      text: widget.epic.estimatedHours > 0 ? widget.epic.estimatedHours.toStringAsFixed(0) : '',
    );
    _pointsController = TextEditingController(
      text: widget.epic.storyPoints > 0 ? widget.epic.storyPoints.toStringAsFixed(0) : '',
    );

    _status = widget.epic.status.toUpperCase();
    if (!_statuses.contains(_status)) {
      if (_status == 'IN PROGRESS' || _status == 'IN_PROGRESS') {
        _status = 'ACTIVE';
      } else if (_status == 'DONE') {
        _status = 'COMPLETED';
      } else {
        _status = 'NEW';
      }
    }

    _priority = widget.epic.priority.toUpperCase();
    if (!_priorities.contains(_priority)) _priority = 'MEDIUM';

    _category = widget.epic.category;
    if (!_categories.contains(_category)) {
      _categories.insert(0, _category);
    }

    _selectedTeamName = widget.epic.teamName;

    if (widget.epic.startDate != null) {
      _startDate = DateTime.tryParse(widget.epic.startDate!);
    }
    if (widget.epic.dueDate != null) {
      _dueDate = DateTime.tryParse(widget.epic.dueDate!);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _estimateController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'NEW':
        return const Color(0xFF64748B);
      case 'ACTIVE':
        return const Color(0xFF3B82F6);
      case 'RESOLVED':
        return const Color(0xFF10B981);
      case 'COMPLETED':
        return const Color(0xFF059669);
      default:
        return const Color(0xFF64748B);
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'CRITICAL':
      case 'URGENT':
        return const Color(0xFFEF4444);
      case 'HIGH':
        return const Color(0xFFF97316);
      case 'MEDIUM':
        return const Color(0xFFEAB308);
      case 'LOW':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF64748B);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final api = ref.read(workApiServiceProvider);
    final payload = <String, dynamic>{
      'title': _titleController.text.trim(),
      'description': _descController.text.trim(),
      'work_type': 'EPIC',
      'status': _status,
      'priority': _priority,
      'category': _category,
      'team_name': _selectedTeamName,
      'estimated_hours': double.tryParse(_estimateController.text.trim()) ?? 0.0,
      'story_points': double.tryParse(_pointsController.text.trim()) ?? 0.0,
      'start_date': _startDate?.toIso8601String().substring(0, 10),
      'due_date': _dueDate?.toIso8601String().substring(0, 10),
    };

    final targetId = widget.epic.id.isNotEmpty ? widget.epic.id : widget.epic.itemNumber;
    final success = await api.updateItem(targetId, payload);

    if (mounted) {
      if (success) {
        // Refresh live data across backlog, board, and list
        ref.read(workBacklogProvider.notifier).loadBacklog(epicId: targetId);
        ref.read(workBoardProvider.notifier).loadBoard();
        ref.read(workListProvider.notifier).loadPagedItems();

        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Updated Epic ${widget.epic.itemNumber} successfully!'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update epic. Please check database connection and try again.'),
            backgroundColor: Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF13182C) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0);

    final teamNames = <String>{
      ...WorkFilterHelper.defaultTeams.where((t) => t != 'All'),
      if (_selectedTeamName != null && _selectedTeamName!.isNotEmpty && _selectedTeamName != 'Unassigned')
        _selectedTeamName!,
      if (widget.epic.teamName != null && widget.epic.teamName!.isNotEmpty && widget.epic.teamName != 'Unassigned')
        widget.epic.teamName!,
    }.toList();

    final teamOptions = [
      {'id': null, 'label': 'No Team (Unassigned)'},
      ...teamNames.map((t) => {'id': t, 'label': t}),
    ];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: bgColor,
      elevation: 12,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header with Epic Badge & Close
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.military_tech_outlined, size: 22, color: Color(0xFF8B5CF6)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Edit Epic Details',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  widget.epic.itemNumber,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF8B5CF6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Update epic scope, strategic objectives, timeline and status',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: borderColor, height: 1),
                const SizedBox(height: 16),

                // 2. Scrollable Body
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Epic Title
                        _buildLabel('Epic Title *', isDark),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _titleController,
                          validator: (v) => v == null || v.trim().isEmpty ? 'Please enter epic title' : null,
                          style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black),
                          decoration: _inputDecoration('e.g. Student Portal Enhancement', isDark),
                        ),
                        const SizedBox(height: 14),

                        // Description / Scope
                        _buildLabel('Strategic Objectives & Scope', isDark),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _descController,
                          maxLines: 4,
                          style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black),
                          decoration: _inputDecoration(
                            'High-level goals, deliverables, architectural milestones and user expectations...',
                            isDark,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Status & Priority
                        Row(
                          children: [
                            // Status
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Status', isDark),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: AppSearchableDropdown<String>.fromMenuItems(
                                        value: _status,
                                        isExpanded: true,
                                        dropdownColor: bgColor,
                                        items: _statuses.map((s) {
                                          final c = _getStatusColor(s);
                                          return DropdownMenuItem<String>(
                                            value: s,
                                            child: Row(
                                              children: [
                                                Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                                                const SizedBox(width: 8),
                                                Text(s, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (v) => setState(() => _status = v!),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Priority
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Priority', isDark),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: AppSearchableDropdown<String>.fromMenuItems(
                                        value: _priority,
                                        isExpanded: true,
                                        dropdownColor: bgColor,
                                        items: _priorities.map((p) {
                                          final c = _getPriorityColor(p);
                                          return DropdownMenuItem<String>(
                                            value: p,
                                            child: Row(
                                              children: [
                                                Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                                                const SizedBox(width: 8),
                                                Text(p, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (v) => setState(() => _priority = v!),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Category & Target Team
                        Row(
                          children: [
                            // Category
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Category', isDark),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: AppSearchableDropdown<String>.fromMenuItems(
                                        value: _category,
                                        isExpanded: true,
                                        dropdownColor: bgColor,
                                        items: _categories.map((c) {
                                          return DropdownMenuItem<String>(
                                            value: c,
                                            child: Text(c, style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black)),
                                          );
                                        }).toList(),
                                        onChanged: (v) => setState(() => _category = v!),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Target Team
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Target Team', isDark),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: AppSearchableDropdown<String?>.fromMenuItems(
                                        value: teamOptions.any((t) => t['id'] == _selectedTeamName)
                                            ? _selectedTeamName
                                            : null,
                                        isExpanded: true,
                                        dropdownColor: bgColor,
                                        items: teamOptions.map((opt) {
                                          return DropdownMenuItem<String?>(
                                            value: opt['id'],
                                            child: Row(
                                              children: [
                                                if (opt['id'] != null) ...[
                                                  const Icon(Icons.groups_rounded, size: 14, color: Color(0xFF6366F1)),
                                                  const SizedBox(width: 6),
                                                ],
                                                Expanded(
                                                  child: Text(
                                                    opt['label']!,
                                                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (v) => setState(() => _selectedTeamName = v),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Story Points & Estimated Hours
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
                                    decoration: _inputDecoration('e.g. 50', isDark, prefixIcon: Icons.star_border_rounded),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Estimated Effort (h)', isDark),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _estimateController,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black),
                                    decoration: _inputDecoration('e.g. 160', isDark, prefixIcon: Icons.schedule_rounded),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Start Date & Due Date
                        Row(
                          children: [
                            Expanded(
                              child: _buildDatePicker(
                                label: 'Start Date',
                                selectedDate: _startDate,
                                onSelect: (d) => setState(() => _startDate = d),
                                isDark: isDark,
                                borderColor: borderColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDatePicker(
                                label: 'Target Due Date',
                                selectedDate: _dueDate,
                                onSelect: (d) => setState(() => _dueDate = d),
                                isDark: isDark,
                                borderColor: borderColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                Divider(color: borderColor, height: 1),
                const SizedBox(height: 16),

                // 3. Footer Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_rounded, size: 16),
                      label: Text(
                        _isSubmitting ? 'Saving...' : 'Save Epic Changes',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
      ),
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime? selectedDate,
    required ValueChanged<DateTime> onSelect,
    required bool isDark,
    required Color borderColor,
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
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
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
      fillColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
      ),
    );
  }
}
