import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/attendance_models.dart';
import '../providers/attendance_provider.dart';

class BulkOperationsTab extends ConsumerStatefulWidget {
  const BulkOperationsTab({Key? key}) : super(key: key);

  @override
  ConsumerState<BulkOperationsTab> createState() => _BulkOperationsTabState();
}

class _BulkOperationsTabState extends ConsumerState<BulkOperationsTab> {
  AttendanceStatus _selectedTargetStatus = AttendanceStatus.present;
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  @override
  void dispose() {
    _remarksController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceProvider);
    final notifier = ref.read(attendanceProvider.notifier);
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          const Text('Bulk Attendance Operations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            'Perform bulk updates, status overwrites, locking/unlocking, and CSV exports across entire classes.',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 20),

          // 1. Bulk Status Assignment Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.flash_on_rounded, color: Color(0xFF4F46E5), size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text('1. Bulk Mark Entire Class Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Quickly set all students in the selected class and section to a specific status.',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Text('Target Status: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(width: 10),
                    DropdownButton<AttendanceStatus>(
                      value: _selectedTargetStatus,
                      items: [
                        AttendanceStatus.present,
                        AttendanceStatus.absent,
                        AttendanceStatus.late,
                        AttendanceStatus.onLeave,
                        AttendanceStatus.halfDay,
                      ].map((st) {
                        return DropdownMenuItem(
                          value: st,
                          child: Row(
                            children: [
                              Container(width: 8, height: 8, decoration: BoxDecoration(color: st.color, shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Text(st.label, style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedTargetStatus = val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _remarksController,
                  decoration: InputDecoration(
                    hintText: 'Optional bulk remarks (e.g. Rainy Day / Field Trip / Sports Day)',
                    hintStyle: const TextStyle(fontSize: 12),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: state.isSaving
                      ? null
                      : () {
                          final allIds = state.roster.map((s) => s.studentId).toList();
                          notifier.executeBulkOperation(
                            operation: 'MARK_STATUS',
                            studentIds: allIds,
                            targetStatus: _selectedTargetStatus.apiKey,
                            remarks: _remarksController.text.trim(),
                          );
                        },
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Apply to All Students in Class'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Bulk Lock / Unlock Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.lock_reset_rounded, color: Color(0xFFF59E0B), size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text('2. Bulk Lock / Unlock Attendance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Lock attendance to prevent accidental changes, or unlock for administrative corrections.',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _reasonController,
                  decoration: InputDecoration(
                    hintText: 'Mandatory reason for lock / unlock action...',
                    hintStyle: const TextStyle(fontSize: 12),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: state.isSaving
                          ? null
                          : () {
                              final allIds = state.roster.map((s) => s.studentId).toList();
                              notifier.executeBulkOperation(
                                operation: 'LOCK',
                                studentIds: allIds,
                                reason: _reasonController.text.trim(),
                              );
                            },
                      icon: const Icon(Icons.lock_rounded, size: 16),
                      label: const Text('Lock Class Attendance'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: state.isSaving
                          ? null
                          : () {
                              final allIds = state.roster.map((s) => s.studentId).toList();
                              notifier.executeBulkOperation(
                                operation: 'UNLOCK',
                                studentIds: allIds,
                                reason: _reasonController.text.trim(),
                              );
                            },
                      icon: const Icon(Icons.lock_open_rounded, size: 16),
                      label: const Text('Unlock Class Attendance'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
