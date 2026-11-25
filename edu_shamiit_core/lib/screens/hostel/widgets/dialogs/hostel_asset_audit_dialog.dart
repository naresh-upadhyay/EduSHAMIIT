import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/hostel_provider.dart';

class HostelAssetAuditDialog extends ConsumerStatefulWidget {
  final String? studentId;
  final String? admissionId;
  final String? studentName;
  final String? roomNumber;
  final String? bedNumber;
  final String? roomId;
  final String? bedId;
  final String auditType; // CHECK_IN, CHECK_OUT, PERIODIC

  const HostelAssetAuditDialog({
    super.key,
    this.studentId,
    this.admissionId,
    this.studentName,
    this.roomNumber,
    this.bedNumber,
    this.roomId,
    this.bedId,
    this.auditType = 'CHECK_OUT',
  });

  @override
  ConsumerState<HostelAssetAuditDialog> createState() => _HostelAssetAuditDialogState();
}

class _HostelAssetAuditDialogState extends ConsumerState<HostelAssetAuditDialog> {
  final List<Map<String, dynamic>> _checklist = [
    {'item': 'Mattress & Bed Frame', 'condition': 'GOOD', 'is_present': true, 'damage_cost': 0.0},
    {'item': 'Study Desk & Chair', 'condition': 'GOOD', 'is_present': true, 'damage_cost': 0.0},
    {'item': 'Cupboard / Wardrobe & Key', 'condition': 'GOOD', 'is_present': true, 'damage_cost': 0.0},
    {'item': 'Ceiling Fan & Speed Regulator', 'condition': 'GOOD', 'is_present': true, 'damage_cost': 0.0},
    {'item': 'Electrical Sockets & Switches', 'condition': 'GOOD', 'is_present': true, 'damage_cost': 0.0},
    {'item': 'Room Door Lock & Brass Key', 'condition': 'GOOD', 'is_present': true, 'damage_cost': 0.0},
  ];

  bool _applyDepositDeduction = false;
  final TextEditingController _remarksController = TextEditingController();
  bool _isSubmitting = false;

  double get _totalDamages {
    double sum = 0;
    for (final c in _checklist) {
      sum += (c['damage_cost'] as num).toDouble();
    }
    return sum;
  }

  Future<void> _submitAudit() async {
    final notifier = ref.read(hostelProvider.notifier);
    final state = ref.read(hostelProvider);

    final sid = widget.studentId ?? state.selectedStudentDetail?.id;
    if (sid == null) {
      notifier.showError('No student selected for handover audit');
      return;
    }

    setState(() => _isSubmitting = true);
    final payload = {
      'student_id': sid,
      'admission_id': widget.admissionId ?? state.selectedStudentDetail?.admissionId,
      'room_id': widget.roomId ?? state.selectedStudentDetail?.roomId,
      'bed_id': widget.bedId ?? state.selectedStudentDetail?.bedId,
      'audit_type': widget.auditType,
      'items_checklist': _checklist,
      'total_damages_cost': _totalDamages,
      'deposit_deduction_applied': _applyDepositDeduction,
      'remarks': _remarksController.text.trim(),
    };

    final navigator = Navigator.of(context);
    try {
      final res = await notifier.service.recordAssetAudit(payload);
      if (mounted) {
        if (res['success'] == true) {
          navigator.pop();
          notifier.showSuccess('Room asset audit saved successfully! (Total Damages: ₹$_totalDamages)');
        } else {
          notifier.showError(res['message']?.toString() ?? 'Failed to record asset audit');
        }
      }
    } catch (e) {
      if (mounted) notifier.showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(hostelProvider);
    final name = widget.studentName ?? state.selectedStudentDetail?.studentName ?? 'Student';
    final room = widget.roomNumber ?? state.selectedStudentDetail?.roomNumber ?? 'Room';
    final bed = widget.bedNumber ?? state.selectedStudentDetail?.bedNo ?? 'Bed';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 780,
        height: 680,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF8B5CF6), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Room & Bed Asset Handover Audit (${widget.auditType})',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Student: $name  |  $room - $bed  |  Handover clearance checklist',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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

            // Checklist table
            Expanded(
              child: ListView.separated(
                itemCount: _checklist.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final row = _checklist[i];
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Checkbox(
                          value: row['is_present'] as bool,
                          onChanged: (val) {
                            setState(() => row['is_present'] = val ?? true);
                          },
                        ),
                        Expanded(
                          flex: 4,
                          child: Text(
                            row['item'] as String,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                        // Condition Dropdown
                        Expanded(
                          flex: 3,
                          child: AppSearchableDropdownFormField<String>.fromMenuItems(
                            initialValue: row['condition'] as String,
                            isDense: true,
                            decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                            items: const [
                              DropdownMenuItem(value: 'GOOD', child: Text('Good Condition')),
                              DropdownMenuItem(value: 'DAMAGED', child: Text('Damaged')),
                              DropdownMenuItem(value: 'MISSING', child: Text('Missing / Lost')),
                            ],
                            onChanged: (val) {
                              setState(() {
                                row['condition'] = val ?? 'GOOD';
                                if (val == 'GOOD') row['damage_cost'] = 0.0;
                                if (val == 'DAMAGED' && (row['damage_cost'] as num) == 0) row['damage_cost'] = 500.0;
                                if (val == 'MISSING' && (row['damage_cost'] as num) == 0) row['damage_cost'] = 1000.0;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Damage penalty field
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            initialValue: (row['damage_cost'] as num).toString(),
                            decoration: const InputDecoration(
                              labelText: 'Damage (₹)',
                              isDense: true,
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (val) {
                              setState(() {
                                row['damage_cost'] = double.tryParse(val) ?? 0.0;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Summary strip & Deposit Deduction toggle
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: _applyDepositDeduction,
                    onChanged: (val) => setState(() => _applyDepositDeduction = val ?? false),
                  ),
                  const Expanded(
                    child: Text(
                      'Apply damage cost as caution deposit deduction (records penalty in billing ledger)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    'Total Liability: ₹$_totalDamages',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _totalDamages > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Submit Buttons
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _remarksController,
                    decoration: const InputDecoration(
                      labelText: 'Handover Remarks / Student Signature Notes',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                TextButton(
                  onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitAudit,
                  icon: _isSubmitting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.verified_rounded, size: 18),
                  label: const Text('Save Audit Record'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
