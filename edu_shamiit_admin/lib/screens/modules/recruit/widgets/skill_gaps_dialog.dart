import 'package:flutter/material.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import 'package:edu_shamiit_admin/services/hr_lookup_helper.dart';
import 'create_training_dialog.dart';

class SkillGapsDialog extends StatefulWidget {
  final VoidCallback? onGapsChanged;

  const SkillGapsDialog({super.key, this.onGapsChanged});

  @override
  State<SkillGapsDialog> createState() => _SkillGapsDialogState();
}

class _SkillGapsDialogState extends State<SkillGapsDialog> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  bool _showAddForm = false;
  List<dynamic> _skillGaps = [];

  // Form controllers
  final _deptController = TextEditingController(text: 'Teaching');
  final _topicController = TextEditingController();
  final _countController = TextEditingController(text: '5');
  final String _priority = 'HIGH';
  bool _isSaving = false;

  List<String> _departments = HRLookupHelper.instance.getCachedLabels('DEPARTMENT');

  @override
  void initState() {
    super.initState();
    HRLookupHelper.instance.addListener(_onLookupsChanged);
    _fetchSkillGaps();
    _loadLookups(true);
  }

  void _onLookupsChanged() {
    if (mounted) {
      _loadLookups(true);
    }
  }

  Future<void> _loadLookups([bool forceRefresh = true]) async {
    final depts = await HRLookupHelper.instance.getLookupLabels('DEPARTMENT', forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _departments = depts;
        if (!_departments.contains(_deptController.text) && _departments.isNotEmpty) {
          _deptController.text = _departments.first;
        }
      });
    }
  }

  @override
  void dispose() {
    HRLookupHelper.instance.removeListener(_onLookupsChanged);
    _deptController.dispose();
    _topicController.dispose();
    _countController.dispose();
    super.dispose();
  }

  Future<void> _fetchSkillGaps() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get('/training/skill-gaps', useCache: false);
      if (res['success'] == true) {
        setState(() {
          _skillGaps = (res['data'] as List<dynamic>?) ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addSkillGap() async {
    if (_topicController.text.trim().isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final payload = {
        'department': _deptController.text.trim(),
        'designation': 'All',
        'topic': _topicController.text.trim(),
        'required_proficiency': 'Advanced',
        'current_proficiency': 'Intermediate',
        'identified_employees_count': int.tryParse(_countController.text.trim()) ?? 5,
        'priority': _priority,
      };
      final res = await _api.post('/training/skill-gaps', payload);
      if (res['success'] == true) {
        _topicController.clear();
        setState(() => _showAddForm = false);
        _fetchSkillGaps();
        widget.onGapsChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _openCreateTrainingForGap(Map<String, dynamic> gap) {
    final dept = gap['department']?.toString() ?? 'Teaching';
    final topic = gap['topic']?.toString() ?? gap['required_training_title']?.toString() ?? 'Digital Classroom';
    final count = int.tryParse(gap['identified_employees_count']?.toString() ?? gap['employees_count']?.toString() ?? '5') ?? 5;
    final gapId = gap['id']?.toString();

    // Map department to standard category
    String cat = 'Professional Development';
    final deptLower = dept.toLowerCase();
    if (deptLower.contains('teach') || deptLower.contains('academic')) {
      cat = 'Pedagogy & Teaching';
    } else if (deptLower.contains('trans') || deptLower.contains('safety') || deptLower.contains('health')) {
      cat = 'Health & Safety';
    } else if (deptLower.contains('tech') || deptLower.contains('it')) {
      cat = 'Digital & Technology';
    } else if (deptLower.contains('admin')) {
      cat = 'Compliance & Safety';
    }

    showDialog(
      context: context,
      builder: (_) => CreateTrainingDialog(
        initialTraining: {
          'title': topic,
          'description': 'Targeted institutional training program designed to address identified skill gap in $dept regarding "$topic" for $count staff members.',
          'category_name': cat,
          'training_type': 'Technical',
          'target_audience': dept,
          'capacity': count > 20 ? count + 10 : 30,
          'trainer_name': 'Internal HR Trainer',
          'provider_name': 'Greenfield Learning Academy',
          'mode': 'Offline',
          'duration_hours': 2,
          'duration_display': '2 Hours',
          'skill_gap_id': gapId,
        },
        onTrainingCreated: () async {
          // Update skill gap status via PATCH if gapId exists
          if (gapId != null && gapId.isNotEmpty) {
            try {
              await _api.patch('/training/skill-gaps/$gapId', {'status': 'Training Created'});
            } catch (_) {}
          }
          _fetchSkillGaps();
          widget.onGapsChanged?.call();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Training program created for "$topic"! Skill gap updated.'),
                backgroundColor: const Color(0xFF10B981),
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 760,
        height: 600,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF13182C) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.psychology_alt_outlined, color: Color(0xFF0284C7), size: 24),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Training Needs & Skill Gaps',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Outfit',
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Identified competencies requiring staff training and development.',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _showAddForm = !_showAddForm),
                      icon: Icon(_showAddForm ? Icons.close : Icons.add, size: 16),
                      label: Text(_showAddForm ? 'Cancel' : 'Identify Need'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Form to Add Skill Gap
            if (_showAddForm) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Identify New Skill Gap / Training Need', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            initialValue: _departments.contains(_deptController.text) ? _deptController.text : (_departments.isNotEmpty ? _departments.first : null),
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Department', isDense: true, border: OutlineInputBorder()),
                            items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (v) => setState(() => _deptController.text = v ?? (_departments.isNotEmpty ? _departments.first : 'Teaching')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 4,
                          child: TextField(
                            controller: _topicController,
                            decoration: const InputDecoration(
                              labelText: 'Training Topic / Competency',
                              hintText: 'e.g. Digital Classroom & Interactive Screen Tools',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: _countController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Employees', isDense: true, border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _isSaving ? null : _addSkillGap,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                          child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Skill Gaps List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _skillGaps.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline, size: 40, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              const Text('No unresolved training gaps identified.', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _skillGaps.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, i) {
                            final g = _skillGaps[i];
                            final dept = g['department'] ?? 'Teaching';
                            final topic = g['topic'] ?? g['required_training_title'] ?? 'Digital Classroom';
                            final count = g['identified_employees_count'] ?? g['employees_count'] ?? 5;
                            final priority = (g['priority'] ?? 'MEDIUM').toString().toUpperCase();
                            final rawStatus = (g['status'] ?? 'Identified').toString().trim();
                            final isCreated = rawStatus.toLowerCase().contains('created') || rawStatus.toLowerCase().contains('resolved');

                            Color prioColor = const Color(0xFFF59E0B);
                            if (priority == 'HIGH') prioColor = const Color(0xFFEF4444);
                            if (priority == 'LOW') prioColor = const Color(0xFF10B981);

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isCreated
                                      ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                      : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isCreated
                                          ? const Color(0xFF10B981).withValues(alpha: 0.1)
                                          : prioColor.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isCreated ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                                      color: isCreated ? const Color(0xFF10B981) : prioColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              dept,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: prioColor.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: prioColor.withValues(alpha: 0.3)),
                                              ),
                                              child: Text(
                                                '$priority PRIORITY',
                                                style: TextStyle(color: prioColor, fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            if (isCreated)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                                                ),
                                                child: Text(
                                                  rawStatus.toUpperCase(),
                                                  style: const TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$count employees need "$topic" training',
                                          style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  if (isCreated)
                                    OutlinedButton.icon(
                                      onPressed: () => _openCreateTrainingForGap(g),
                                      icon: const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF10B981)),
                                      label: const Text('Training Created', style: TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Color(0xFF10B981)),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    )
                                  else
                                    ElevatedButton.icon(
                                      onPressed: () => _openCreateTrainingForGap(g),
                                      icon: const Icon(Icons.add_rounded, size: 15),
                                      label: const Text('Create Training', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF4F46E5),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  const SizedBox(width: 4),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert_rounded, size: 18),
                                    tooltip: 'Options',
                                    onSelected: (val) async {
                                      final gapId = g['id']?.toString();
                                      if (gapId == null) return;
                                      if (val == 'resolve') {
                                        try {
                                          await _api.patch('/training/skill-gaps/$gapId', {'status': 'Resolved'});
                                          _fetchSkillGaps();
                                          widget.onGapsChanged?.call();
                                        } catch (_) {}
                                      } else if (val == 'delete') {
                                        try {
                                          await _api.delete('/training/skill-gaps/$gapId');
                                          _fetchSkillGaps();
                                          widget.onGapsChanged?.call();
                                        } catch (_) {}
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(
                                        value: 'resolve',
                                        child: Row(
                                          children: [
                                            Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF10B981)),
                                            SizedBox(width: 8),
                                            Text('Mark as Resolved'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Delete Need', style: TextStyle(color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
