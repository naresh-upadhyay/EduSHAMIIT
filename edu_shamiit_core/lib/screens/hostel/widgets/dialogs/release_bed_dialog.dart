import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/hostel_models.dart';
import '../../providers/hostel_provider.dart';

class ReleaseBedDialog extends ConsumerStatefulWidget {
  final HostelStudentRosterItem student;

  const ReleaseBedDialog({super.key, required this.student});

  @override
  ConsumerState<ReleaseBedDialog> createState() => _ReleaseBedDialogState();
}

class _ReleaseBedDialogState extends ConsumerState<ReleaseBedDialog> {
  final TextEditingController _reasonController = TextEditingController(text: 'Temporary Vacate / Bed Released');
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final notifier = ref.read(hostelProvider.notifier);
    final payload = {
      'admission_id': widget.student.admissionId,
      'student_id': widget.student.studentId,
      'reason': _reasonController.text.trim(),
    };

    final ok = await notifier.releaseStudentBed(payload);
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (ok) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.bed_outlined, color: Color(0xFFDC2626), size: 18),
          ),
          const SizedBox(width: 10),
          const Text('Release Bed Allocation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to release Room ${widget.student.roomNumber} (Bed ${widget.student.bedNo}) for ${widget.student.studentName}?',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            const Text(
              'This will free up the bed for other students. The student will remain active in the hostel pool as "Awaiting Allocation".',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            const Text('Reason for release', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _reasonController,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
          child: Text(
            _isSubmitting ? 'Releasing...' : 'Release Bed',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
