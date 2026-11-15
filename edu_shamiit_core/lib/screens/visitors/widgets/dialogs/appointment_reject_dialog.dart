import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/visitor_models.dart';
import '../../providers/visitors_provider.dart';

class AppointmentRejectDialog extends ConsumerStatefulWidget {
  final ScheduledAppointmentItem appointment;

  const AppointmentRejectDialog({super.key, required this.appointment});

  @override
  ConsumerState<AppointmentRejectDialog> createState() => _AppointmentRejectDialogState();
}

class _AppointmentRejectDialogState extends ConsumerState<AppointmentRejectDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonCtrl = TextEditingController(text: 'Host unavailable at the requested time slot');
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final ok = await ref.read(visitorsProvider.notifier).rejectAppointment(
      widget.appointment.id,
      reason: _reasonCtrl.text.trim(),
    );

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
    final isNarrow = screenWidth < 500;
    final dialogWidth = math.min(screenWidth * 0.95, 480.0);

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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.cancel_outlined, color: Color(0xFFEF4444), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reject Appointment',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'For ${widget.appointment.visitorName}',
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
              const SizedBox(height: 18),

              TextFormField(
                controller: _reasonCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Rejection Reason *',
                  hintText: 'Provide reason for rejecting this appointment...',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Rejection reason required' : null,
              ),
              const SizedBox(height: 24),

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
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Confirm Rejection'),
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
