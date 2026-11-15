import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/hostel_models.dart';
import '../../providers/hostel_provider.dart';

class EndHostelStaffDialog extends ConsumerStatefulWidget {
  final HostelStaffRosterItem staff;

  const EndHostelStaffDialog({super.key, required this.staff});

  @override
  ConsumerState<EndHostelStaffDialog> createState() => _EndHostelStaffDialogState();
}

class _EndHostelStaffDialogState extends ConsumerState<EndHostelStaffDialog> {
  final _reasonController = TextEditingController(text: 'Duty Completed / Relieved from Hostel Assignment');
  DateTime _endDate = DateTime.now();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person_off_outlined, color: Color(0xFFDC2626), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'End Hostel Assignment - ${widget.staff.name}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Facility: ${widget.staff.hostelName} (${widget.staff.role})',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Non-Destructive Info Alert Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF2563EB)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Ending this hostel assignment will relieve the staff member from duties and archive their hostel record. Their main employee profile in School Management will remain ACTIVE.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // End Date
              const Text('Effective End Date', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${_endDate.day}/${_endDate.month}/${_endDate.year}', style: const TextStyle(fontSize: 13)),
                      const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF64748B)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Reason
              const Text('Reason / Handover Remarks', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _reasonController,
                maxLines: 2,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitEndAssignment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('End Assignment'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitEndAssignment() async {
    setState(() => _isSubmitting = true);
    final payload = {
      'assignment_id': widget.staff.assignmentId,
      'end_date': '${_endDate.year}-${_endDate.month.toString().padLeft(2, '0')}-${_endDate.day.toString().padLeft(2, '0')}',
      'reason': _reasonController.text.trim(),
    };

    final success = await ref.read(hostelProvider.notifier).endStaffAssignment(
      widget.staff.assignmentId,
      payload,
    );
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) Navigator.of(context).pop();
    }
  }
}
