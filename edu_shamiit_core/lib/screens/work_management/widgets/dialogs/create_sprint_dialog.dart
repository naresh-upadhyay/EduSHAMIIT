import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/work_models.dart';
import '../../providers/work_management_provider.dart';
import '../../services/work_api_service.dart';

class CreateSprintDialog extends ConsumerStatefulWidget {
  final String? boardId;

  const CreateSprintDialog({
    super.key,
    this.boardId,
  });

  @override
  ConsumerState<CreateSprintDialog> createState() => _CreateSprintDialogState();
}

class _CreateSprintDialogState extends ConsumerState<CreateSprintDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController(text: 'Sprint 11');
  final TextEditingController _goalController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController(text: '160');

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 14));
  String _selectedStatus = 'PLANNED';
  String? _selectedTeamId;
  String _selectedTeamName = 'All Teams';

  List<TeamDirectoryItemModel> _availableTeams = [];
  bool _isLoadingTeams = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    try {
      final resp = await WorkApiService.instance.getTeamsDirectory(limit: 100);
      if (mounted) {
        setState(() {
          _availableTeams = resp?.teams ?? [];
          _isLoadingTeams = false;
          if (_availableTeams.isNotEmpty && _selectedTeamId == null) {
            _selectedTeamId = _availableTeams.first.id;
            _selectedTeamName = _availableTeams.first.name;
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

    final payload = {
      'name': _nameController.text.trim(),
      'goal': _goalController.text.trim(),
      'board_id': widget.boardId,
      'start_date': _startDate.toIso8601String().substring(0, 10),
      'end_date': _endDate.toIso8601String().substring(0, 10),
      'capacity_hours': double.tryParse(_capacityController.text.trim()) ?? 160.0,
      'status': _selectedStatus,
      'team_id': _selectedTeamId,
      'team_name': _selectedTeamName,
    };

    final result = await ref.read(allSprintsProvider.notifier).createSprint(payload);
    if (result) {
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sprint "${_nameController.text.trim()}" created successfully.'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } else {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create sprint. Please try again.'),
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
                            color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.add_task_rounded, size: 20, color: Color(0xFF2563EB)),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Create New Sprint',
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
                  decoration: _inputDecoration('e.g. Sprint 11', isDark),
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
                  decoration: _inputDecoration('e.g. Deliver mobile attendance, parent push alerts and gradebook sync.', isDark),
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

                // Dates Row (Responsive)
                if (isCompact) ...[
                  _buildDateButton('Start Date', _startDate, (picked) => setState(() => _startDate = picked), isDark),
                  const SizedBox(height: 12),
                  _buildDateButton('End Date', _endDate, (picked) => setState(() => _endDate = picked), isDark),
                ] else ...[
                  Row(
                    children: [
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
                const SizedBox(height: 14),

                // Capacity Points / Hours
                Text(
                  'Total Team Capacity (Hours)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _capacityController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                  decoration: _inputDecoration('160', isDark),
                ),
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
                          : const Text('Create Sprint', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
                  child: AppSearchableDropdown<String>.fromMenuItems(
                    isExpanded: true,
                    value: _selectedTeamId,
                    hint: Text('Select Team', style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white70 : const Color(0xFF64748B))),
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
          'Initial Status',
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
            child: AppSearchableDropdown<String>.fromMenuItems(
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
