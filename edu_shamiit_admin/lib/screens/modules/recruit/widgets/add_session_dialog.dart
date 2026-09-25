import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:edu_shamiit_core/services/api_service.dart';

class AddSessionDialog extends StatefulWidget {
  final String programId;
  final String programTitle;
  final VoidCallback onSessionAdded;

  const AddSessionDialog({
    super.key,
    required this.programId,
    required this.programTitle,
    required this.onSessionAdded,
  });

  @override
  State<AddSessionDialog> createState() => _AddSessionDialogState();
}

class _AddSessionDialogState extends State<AddSessionDialog> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _api = ApiService();
  bool _isSubmitting = false;

  final _titleController = TextEditingController();
  final _trainerController = TextEditingController();
  final _locationController = TextEditingController(text: 'Seminar Hall 1');
  final _capacityController = TextEditingController(text: '30');
  final _notesController = TextEditingController();

  DateTime _sessionDate = DateTime.now().add(const Duration(days: 3));
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 12, minute: 0);

  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void dispose() {
    _titleController.dispose();
    _trainerController.dispose();
    _locationController.dispose();
    _capacityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final payload = {
      'program_id': widget.programId,
      'session_title': _titleController.text.trim(),
      'session_date': _dateFormat.format(_sessionDate),
      'start_time': _formatTime(_startTime),
      'end_time': _formatTime(_endTime),
      'trainer_name': _trainerController.text.trim().isNotEmpty ? _trainerController.text.trim() : null,
      'location_or_link': _locationController.text.trim().isNotEmpty ? _locationController.text.trim() : null,
      'capacity': int.tryParse(_capacityController.text.trim()) ?? 30,
      'notes': _notesController.text.trim(),
    };

    try {
      final res = await _api.post('/training/sessions', payload);
      if (res['success'] == true) {
        widget.onSessionAdded();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session scheduled successfully!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding session: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        height: 580,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF13182C) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Form(
          key: _formKey,
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
                            color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.event_available_outlined, color: Color(0xFF4F46E5), size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Add Training Session',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Outfit',
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.programTitle,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Fields
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Session Title *',
                          hintText: 'e.g., Module 1: Foundational Concepts & Setup',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Session title is required' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Material(
                              color: Colors.transparent,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                shape: RoundedRectangleBorder(
                                  side: BorderSide(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                leading: const Icon(Icons.calendar_today_outlined, size: 20),
                                title: const Text('Date', style: TextStyle(fontSize: 12)),
                                subtitle: Text(_dateFormat.format(_sessionDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                                onTap: () async {
                                  final d = await showDatePicker(
                                    context: context,
                                    initialDate: _sessionDate,
                                    firstDate: DateTime(2025),
                                    lastDate: DateTime(2030),
                                  );
                                  if (d != null) setState(() => _sessionDate = d);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Material(
                              color: Colors.transparent,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                shape: RoundedRectangleBorder(
                                  side: BorderSide(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                leading: const Icon(Icons.access_time, size: 20),
                                title: const Text('Timing', style: TextStyle(fontSize: 12)),
                                subtitle: Text('${_startTime.format(context)} - ${_endTime.format(context)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                onTap: () async {
                                  final st = await showTimePicker(context: context, initialTime: _startTime);
                                  if (!context.mounted || st == null) return;
                                  setState(() => _startTime = st);
                                  final et = await showTimePicker(context: context, initialTime: _endTime);
                                  if (!context.mounted || et == null) return;
                                  setState(() => _endTime = et);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _trainerController,
                              decoration: const InputDecoration(
                                labelText: 'Trainer Name',
                                hintText: 'Trainer or Faculty Lead',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _capacityController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Max Capacity',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          labelText: 'Location or Meeting Link',
                          hintText: 'e.g. Auditorium B or https://meet.google.com/...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Session Notes / Handouts',
                          hintText: 'Any specific instructions for attendees...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Actions Footer
              const Divider(height: 1),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.add_task_rounded, size: 16, color: Colors.white),
                    label: const Text('Add Session', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
