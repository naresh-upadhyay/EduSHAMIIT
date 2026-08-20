import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/attendance_models.dart';
import '../providers/attendance_provider.dart';

class LeavePermissionsTab extends ConsumerWidget {
  const LeavePermissionsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(attendanceProvider);
    final notifier = ref.read(attendanceProvider.notifier);
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Info Notice
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF5FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE9D5FF)),
            ),
            child: const Row(
              children: [
                Icon(Icons.beach_access_rounded, color: Color(0xFF8B5CF6), size: 24),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Integrated Leave Management & Attendance Synchronization',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6B21A8), fontSize: 14),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Approved leave applications are automatically reflected in daily student and staff attendance rosters as "On Leave (O)".',
                        style: TextStyle(color: Color(0xFF7E22CE), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Leave Requests List
          if (state.leaveRequests.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.event_busy_rounded, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No leave requests found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.leaveRequests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final req = state.leaveRequests[index];
                return _buildLeaveRequestCard(context, req, notifier, theme);
              },
            ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildLeaveRequestCard(
    BuildContext context,
    AttendanceLeaveRequestModel req,
    AttendanceNotifier notifier,
    ThemeData theme,
  ) {
    final startStr = DateFormat('dd MMM yyyy').format(req.startDate);
    final endStr = DateFormat('dd MMM yyyy').format(req.endDate);
    final isPending = req.status.toLowerCase() == 'pending';
    final isApproved = req.status.toLowerCase() == 'approved';

    Color statusColor = const Color(0xFFF59E0B);
    if (isApproved) statusColor = const Color(0xFF10B981);
    if (req.status.toLowerCase() == 'rejected') statusColor = const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.12),
            child: Text(
              req.applicantName.isNotEmpty ? req.applicantName[0].toUpperCase() : 'A',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${req.applicantName} (${req.applicantRole.toUpperCase()})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        req.status.toUpperCase(),
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${req.leaveType} • $startStr to $endStr (${req.daysCount} days)',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  'Reason: ${req.reason}',
                  style: const TextStyle(fontSize: 12),
                ),
                if (req.remarks != null && req.remarks!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Remarks: ${req.remarks}',
                    style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          if (isPending) ...[
            const SizedBox(width: 14),
            Column(
              children: [
                ElevatedButton(
                  onPressed: () => notifier.handleLeaveAction(req.id, 'APPROVE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: const Size(80, 32),
                  ),
                  child: const Text('Approve', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(height: 6),
                OutlinedButton(
                  onPressed: () => notifier.handleLeaveAction(req.id, 'REJECT'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: const Size(80, 32),
                  ),
                  child: const Text('Reject', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
