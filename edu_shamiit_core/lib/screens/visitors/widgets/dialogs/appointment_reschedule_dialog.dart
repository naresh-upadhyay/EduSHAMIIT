import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/visitor_models.dart';
import '../../providers/visitors_provider.dart';

class AppointmentRescheduleDialog extends ConsumerStatefulWidget {
  final ScheduledAppointmentItem appointment;

  const AppointmentRescheduleDialog({super.key, required this.appointment});

  @override
  ConsumerState<AppointmentRescheduleDialog> createState() => _AppointmentRescheduleDialogState();
}

class _AppointmentRescheduleDialogState extends ConsumerState<AppointmentRescheduleDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _hostCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _reasonCtrl;

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 11, minute: 0);
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _hostCtrl = TextEditingController(text: widget.appointment.hostName);
    _locationCtrl = TextEditingController(text: widget.appointment.location);
    _reasonCtrl = TextEditingController(text: 'Host rescheduled due to faculty meeting');
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _locationCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final startStr = '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}';
    final endStr = '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}';

    final payload = {
      'new_date': dateStr,
      'new_start_time': startStr,
      'new_end_time': endStr,
      'new_host': _hostCtrl.text.trim(),
      'new_location': _locationCtrl.text.trim(),
      'reason': _reasonCtrl.text.trim(),
    };

    final ok = await ref.read(visitorsProvider.notifier).rescheduleAppointment(widget.appointment.id, payload);
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (ok) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isNarrow = screenWidth < 540;
    final dialogWidth = math.min(screenWidth * 0.95, 520.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: EdgeInsets.symmetric(horizontal: isNarrow ? 10 : 24, vertical: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: screenHeight * 0.90,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isNarrow ? 16 : 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_calendar_rounded, color: Color(0xFF2563EB), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reschedule Appointment',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'For ${widget.appointment.visitorName} (${widget.appointment.appointmentNumber})',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Date Picker Field
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined, size: 20, color: Color(0xFF2563EB)),
                      const SizedBox(width: 12),
                      Text(
                        'New Date: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Start & End Time Pickers
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(context: context, initialTime: _startTime);
                        if (picked != null) setState(() => _startTime = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.schedule, size: 18, color: Color(0xFF2563EB)),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Start: ${_startTime.format(context)}',
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(context: context, initialTime: _endTime);
                        if (picked != null) setState(() => _endTime = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.schedule, size: 18, color: Color(0xFF2563EB)),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'End: ${_endTime.format(context)}',
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Host & Location
              if (isNarrow) ...[
                TextFormField(
                  controller: _hostCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Host / Person to Meet *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Host required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _locationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Location / Destination *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Location required' : null,
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _hostCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Host / Person to Meet *',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Host required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _locationCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Location / Destination *',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Location required' : null,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),

              // Reason
              TextFormField(
                controller: _reasonCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Rescheduling Reason *',
                  hintText: 'Enter reason for changing the date or time...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Reason required' : null,
              ),
              const SizedBox(height: 24),

              // Footer Buttons
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
                        : const Text('Confirm Reschedule'),
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
}
