import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/work_models.dart';
import '../../providers/work_management_provider.dart';

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
  late TextEditingController _teamController;
  late TextEditingController _capacityController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.sprint.name);
    _goalController = TextEditingController(text: widget.sprint.goal);
    _teamController = TextEditingController(text: widget.sprint.teamName.isNotEmpty ? widget.sprint.teamName : 'Digital Campus Team');
    _capacityController = TextEditingController(text: widget.sprint.capacityHours.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _goalController.dispose();
    _teamController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final notifier = ref.read(workSprintDashboardProvider.notifier);
    final success = await notifier.updateSprint(widget.sprint.id, {
      'name': _nameController.text.trim(),
      'goal': _goalController.text.trim(),
      'team_name': _teamController.text.trim(),
      'capacity_hours': double.tryParse(_capacityController.text.trim()) ?? 120.0,
    });

    if (mounted) {
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update sprint details')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Edit Sprint Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                      color: const Color(0xFF94A3B8),
                    ),
                  ],
                ),
                Divider(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
                const SizedBox(height: 12),

                Text('Sprint Name *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  decoration: _inputDecoration('Sprint Name', isDark),
                ),
                const SizedBox(height: 12),

                Text('Sprint Goal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _goalController,
                  maxLines: 2,
                  decoration: _inputDecoration('Describe key sprint objectives...', isDark),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Team Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569))),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _teamController,
                            decoration: _inputDecoration('e.g. Digital Campus Team', isDark),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Capacity (Hours)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569))),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _capacityController,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration('120', isDark),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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
