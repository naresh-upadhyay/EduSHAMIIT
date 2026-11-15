import 'package:flutter/material.dart';
import '../providers/broadcast_provider.dart';

class ScheduleBroadcastDialog extends StatefulWidget {
  final BroadcastProvider provider;

  const ScheduleBroadcastDialog({super.key, required this.provider});

  @override
  State<ScheduleBroadcastDialog> createState() => _ScheduleBroadcastDialogState();
}

class _ScheduleBroadcastDialogState extends State<ScheduleBroadcastDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _classSubjectController = TextEditingController(text: 'Class 10 - Mathematics');
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);
  String _selectedPlatform = 'youtube';
  String _selectedPrivacy = 'Public';
  final String _selectedQuality = '1080p (Full HD)';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _classSubjectController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final dt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final success = await widget.provider.scheduleBroadcast(
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      classSubject: _classSubjectController.text.trim(),
      scheduledTime: dt.toIso8601String(),
      platform: _selectedPlatform,
      privacy: _selectedPrivacy,
      quality: _selectedQuality,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Broadcast scheduled successfully!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to schedule broadcast. Please try again.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.calendar_month, color: Color(0xFF2563EB)),
                          SizedBox(width: 8),
                          Text(
                            'Schedule Live Broadcast',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Title
                  const Text('Stream Title *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Class 10 - Mathematics: Quadratic Equations',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
                  ),
                  const SizedBox(height: 14),

                  // Class / Subject
                  const Text('Class & Subject *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _classSubjectController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Class 10 - A : Mathematics',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Class/Subject required' : null,
                  ),
                  const SizedBox(height: 14),

                  // Date & Time Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (d != null) setState(() => _selectedDate = d);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                                    const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
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
                            const Text('Time', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () async {
                                final t = await showTimePicker(context: context, initialTime: _selectedTime);
                                if (t != null) setState(() => _selectedTime = t);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_selectedTime.format(context)),
                                    const Icon(Icons.access_time, size: 16, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Primary Platform & Privacy
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Platform', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedPlatform,
                              items: const [
                                DropdownMenuItem(value: 'youtube', child: Text('YouTube Live')),
                                DropdownMenuItem(value: 'facebook', child: Text('Facebook Live')),
                                DropdownMenuItem(value: 'custom_rtmp', child: Text('Custom RTMP')),
                              ],
                              onChanged: (v) => setState(() => _selectedPlatform = v!),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                            const Text('Privacy', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedPrivacy,
                              items: const [
                                DropdownMenuItem(value: 'Public', child: Text('Public')),
                                DropdownMenuItem(value: 'Unlisted', child: Text('Unlisted')),
                                DropdownMenuItem(value: 'Private', child: Text('Private')),
                              ],
                              onChanged: (v) => setState(() => _selectedPrivacy = v!),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Description
                  const Text('Description (Optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _descController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Provide details about topics and prerequisites...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Schedule Broadcast'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
