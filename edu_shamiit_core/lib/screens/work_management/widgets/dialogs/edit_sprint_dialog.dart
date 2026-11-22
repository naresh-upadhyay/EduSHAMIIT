import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/work_models.dart';
import '../../providers/work_management_provider.dart';
import '../../services/work_api_service.dart';
import '../../utils/work_sprint_date_helper.dart';

class EditSprintDialog extends ConsumerStatefulWidget {
  final WorkSprintModel sprint;

  const EditSprintDialog({
    super.key,
    required this.sprint,
  });

  @override
  ConsumerState<EditSprintDialog> createState() => _EditSprintDialogState();
}

class _EditSprintDialogState extends ConsumerState<EditSprintDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _goalController;
  late TextEditingController _capacityController;
  late DateTime _startDate;
  late DateTime _endDate;
  late String _selectedStatus;

  String? _selectedTeamId;
  String _selectedTeamName = 'All Teams';
  List<TeamDirectoryItemModel> _availableTeams = [];
  bool _isLoadingTeams = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.sprint.name);
    _goalController = TextEditingController(text: widget.sprint.goal);
    _capacityController = TextEditingController(text: widget.sprint.capacityHours.toStringAsFixed(0));
    _selectedStatus = widget.sprint.status.toUpperCase();
    _selectedTeamId = widget.sprint.teamId;
    _selectedTeamName = widget.sprint.teamName.isNotEmpty ? widget.sprint.teamName : 'All Teams';

    _startDate = DateTime.tryParse(widget.sprint.startDate ?? '') ??
        DateTime.tryParse(widget.sprint.startDateFmt) ??
        WorkSprintDateHelper.currentSprintStart;
    _endDate = DateTime.tryParse(widget.sprint.endDate ?? '') ??
        DateTime.tryParse(widget.sprint.endDateFmt) ??
        WorkSprintDateHelper.currentSprintEnd;

    _loadTeams();
  }

  Future<void> _loadTeams() async {
    try {
      final resp = await WorkApiService.instance.getTeamsDirectory(limit: 100);
      if (mounted) {
        setState(() {
          _availableTeams = resp?.teams ?? [];
          _isLoadingTeams = false;

          // Match existing team if teamId was null but teamName matches
          if (_selectedTeamId == null && _selectedTeamName.isNotEmpty && _selectedTeamName != 'All Teams') {
            final match = _availableTeams.where((t) => t.name.toLowerCase() == _selectedTeamName.toLowerCase()).firstOrNull;
            if (match != null) {
              _selectedTeamId = match.id;
            }
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingTeams = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _goalController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final success = await ref.read(allSprintsProvider.notifier).updateSprint(widget.sprint.id, {
      'name': _nameController.text.trim(),
      'goal': _goalController.text.trim(),
      'team_id': _selectedTeamId,
      'team_name': _selectedTeamName,
      'status': _selectedStatus,
      'capacity_hours': double.tryParse(_capacityController.text.trim()) ?? 120.0,
      'start_date': _startDate.toIso8601String().substring(0, 10),
      'end_date': _endDate.toIso8601String().substring(0, 10),
    });

    if (mounted) {
      if (success) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sprint "${_nameController.text.trim()}" updated successfully.'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      } else {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update sprint details. Please try again.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 500;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.edit_note_rounded, size: 22, color: Color(0xFF3B82F6)),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Edit Sprint Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                      color: const Color(0xFF94A3B8),
                    ),
                  ],
                ),
                Divider(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
                const SizedBox(height: 14),

                // Sprint Name
                Text(
                  'Sprint Name *',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Sprint name is required' : null,
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                  decoration: _inputDecoration('Sprint Name', isDark),
                ),
                const SizedBox(height: 14),

                // Sprint Goal
                Text(
                  'Sprint Goal / Objectives',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _goalController,
                  maxLines: 2,
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                  decoration: _inputDecoration('Describe key sprint objectives...', isDark),
                ),
                const SizedBox(height: 14),

                // Team & Status Row (Responsive)
                if (isCompact) ...[
                  _buildTeamSelector(isDark),
                  const SizedBox(height: 14),
                  _buildStatusSelector(isDark),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _buildTeamSelector(isDark)),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: _buildStatusSelector(isDark)),
                    ],
                  ),
                ],
                const SizedBox(height: 14),

                // Capacity & Dates Row (Responsive)
                if (isCompact) ...[
                  _buildCapacityField(isDark),
                  const SizedBox(height: 14),
                  _buildDateButton('Start Date', _startDate, (picked) => setState(() => _startDate = picked), isDark),
                  const SizedBox(height: 12),
                  _buildDateButton('End Date', _endDate, (picked) => setState(() => _endDate = picked), isDark),
                ] else ...[
                  Row(
                    children: [
                      Expanded(child: _buildCapacityField(isDark)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDateButton('Start Date', _startDate, (picked) => setState(() => _startDate = picked), isDark),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDateButton('End Date', _endDate, (picked) => setState(() => _endDate = picked), isDark),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 22),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
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
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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

  Widget _buildTeamSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Target Team *',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569)),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFCBD5E1)),
          ),
          child: _isLoadingTeams
              ? const SizedBox(
                  height: 36,
                  child: Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))),
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedTeamId,
                    hint: Text(
                      _selectedTeamName.isNotEmpty ? _selectedTeamName : 'Select Team',
                      style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white : Colors.black87),
                    ),
                    dropdownColor: isDark ? const Color(0xFF1E2640) : Colors.white,
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('All Teams (Cross-Functional)'),
                      ),
                      ..._availableTeams.map((team) {
                        return DropdownMenuItem<String>(
                          value: team.id,
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3B82F6),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  team.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ),
                              if (team.department.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF13182C) : const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    team.department,
                                    style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedTeamId = (val != null && val.isNotEmpty) ? val : null;
                        if (_selectedTeamId != null) {
                          final match = _availableTeams.firstWhere((t) => t.id == _selectedTeamId, orElse: () => _availableTeams.first);
                          _selectedTeamName = match.name;
                        } else {
                          _selectedTeamName = 'All Teams';
                        }
                      });
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildStatusSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sprint Status *',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569)),
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
              isExpanded: true,
              value: _selectedStatus,
              dropdownColor: isDark ? const Color(0xFF1E2640) : Colors.white,
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
              items: const [
                DropdownMenuItem(
                  value: 'PLANNED',
                  child: Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 14, color: Color(0xFF3B82F6)),
                      SizedBox(width: 8),
                      Text('Planned'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'ACTIVE',
                  child: Row(
                    children: [
                      Icon(Icons.play_circle_fill_rounded, size: 14, color: Color(0xFF10B981)),
                      SizedBox(width: 8),
                      Text('Active'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'COMPLETED',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF8B5CF6)),
                      SizedBox(width: 8),
                      Text('Completed'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'CLOSED',
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFF64748B)),
                      SizedBox(width: 8),
                      Text('Closed'),
                    ],
                  ),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedStatus = val);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCapacityField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Capacity (Hours)',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569)),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _capacityController,
          keyboardType: TextInputType.number,
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
          decoration: _inputDecoration('120', isDark),
        ),
      ],
    );
  }

  Widget _buildDateButton(String label, DateTime date, Function(DateTime) onPicked, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569))),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (picked != null) onPicked(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFCBD5E1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                Text(
                  date.toIso8601String().substring(0, 10),
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black87),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      filled: true,
      fillColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF1F293D) : const Color(0xFFCBD5E1),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF1F293D) : const Color(0xFFCBD5E1),
        ),
      ),
    );
  }
}
