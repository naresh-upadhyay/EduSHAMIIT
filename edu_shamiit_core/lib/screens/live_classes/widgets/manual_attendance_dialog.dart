import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/live_class_models.dart';
import '../providers/live_class_management_provider.dart';

class ManualAttendanceDialog extends ConsumerStatefulWidget {
  final AttendanceItem student;

  const ManualAttendanceDialog({super.key, required this.student});

  @override
  ConsumerState<ManualAttendanceDialog> createState() =>
      _ManualAttendanceDialogState();
}

class _ManualAttendanceDialogState
    extends ConsumerState<ManualAttendanceDialog> {
  late String _selectedStatus;
  final _reasonController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.student.status;
    _reasonController.text = widget.student.overrideReason ?? '';
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(liveClassManagementProvider.notifier).overrideAttendance(
            widget.student.attendanceId,
            _selectedStatus,
            _reasonController.text.trim(),
          );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF10B981),
            content: Text('Attendance override saved and audited successfully!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('Error updating attendance: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final cardDivider = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final inputBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: cardBg,
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit_calendar_rounded,
                      color: Color(0xFF2563EB), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manual Attendance Override',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textPrimary),
                      ),
                      Text(
                        'Roll ${widget.student.rollNo} • ${widget.student.studentName}',
                        style: TextStyle(
                            fontSize: 13, color: textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Divider(height: 24, color: cardDivider),

            // Details summary card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cardBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text('Join Time',
                          style: TextStyle(fontSize: 11, color: textSecondary)),
                      const SizedBox(height: 2),
                      Text(widget.student.joinTime,
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
                    ],
                  ),
                  Column(
                    children: [
                      Text('Leave Time',
                          style: TextStyle(fontSize: 11, color: textSecondary)),
                      const SizedBox(height: 2),
                      Text(widget.student.leaveTime,
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
                    ],
                  ),
                  Column(
                    children: [
                      Text('Participation',
                          style: TextStyle(fontSize: 11, color: textSecondary)),
                      const SizedBox(height: 2),
                      Text('${widget.student.participationPct}%',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2563EB))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Status dropdown
            Text('Attendance Status',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155))),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _selectedStatus,
              dropdownColor: cardBg,
              style: TextStyle(fontSize: 13, color: textPrimary),
              decoration: InputDecoration(
                filled: true,
                fillColor: inputBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cardBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cardBorder)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              items: const [
                DropdownMenuItem(value: 'Present', child: Text('Present')),
                DropdownMenuItem(value: 'Absent', child: Text('Absent')),
                DropdownMenuItem(value: 'Late', child: Text('Late')),
                DropdownMenuItem(value: 'Partial', child: Text('Partial')),
                DropdownMenuItem(value: 'Excused', child: Text('Excused')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _selectedStatus = v);
              },
            ),
            const SizedBox(height: 14),

            // Reason field
            Text('Override Reason / Remarks *',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155))),
            const SizedBox(height: 6),
            TextField(
              controller: _reasonController,
              maxLines: 2,
              style: TextStyle(fontSize: 13, color: textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g. Technical connectivity issue verified by instructor',
                hintStyle: TextStyle(fontSize: 12, color: textSecondary),
                filled: true,
                fillColor: inputBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cardBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cardBorder)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 20),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: cardBorder),
                    foregroundColor: textSecondary,
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save Override'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
