import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/work_management_provider.dart';

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
  final TextEditingController _nameController = TextEditingController(text: 'Sprint 9');
  final TextEditingController _goalController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController(text: '120');

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 14));
  bool _isSubmitting = false;

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
    final api = ref.read(workApiServiceProvider);

    final payload = {
      'name': _nameController.text.trim(),
      'goal': _goalController.text.trim(),
      'board_id': widget.boardId,
      'start_date': _startDate.toIso8601String().substring(0, 10),
      'end_date': _endDate.toIso8601String().substring(0, 10),
      'capacity_points': int.tryParse(_capacityController.text.trim()) ?? 120,
    };

    final result = await api.createSprint(payload);
    if (result) {
      ref.read(workSprintDashboardProvider.notifier).loadSprintDashboard();
      if (mounted) Navigator.of(context).pop(true);
    } else {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create sprint.')),
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
                      'Create New Sprint',
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

                // Sprint Name
                Text('Sprint Name *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black),
                  decoration: _inputDecoration('e.g. Sprint 9', isDark),
                ),
                const SizedBox(height: 12),

                // Sprint Goal
                Text('Sprint Goal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _goalController,
                  maxLines: 2,
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black),
                  decoration: _inputDecoration('e.g. Deliver mobile attendance, parent push alerts and gradebook sync.', isDark),
                ),
                const SizedBox(height: 12),

                // Dates Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Start Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569))),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _startDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) setState(() => _startDate = picked);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0B0F19) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF2563EB)),
                                  const SizedBox(width: 8),
                                  Text(
                                    _startDate.toIso8601String().substring(0, 10),
                                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black87),
                                  ),
                                ],
                              ),
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
                          Text('End Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569))),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _endDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) setState(() => _endDate = picked);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0B0F19) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF2563EB)),
                                  const SizedBox(width: 8),
                                  Text(
                                    _endDate.toIso8601String().substring(0, 10),
                                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black87),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Capacity points
                Text('Capacity (Story Points / Hours)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _capacityController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black),
                  decoration: _inputDecoration('120', isDark),
                ),
                const SizedBox(height: 18),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Cancel', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
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
