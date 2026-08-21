import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../constants/app_fonts.dart';
import '../models/attendance_models.dart';
import '../providers/attendance_provider.dart';

class LeavePermissionsTab extends ConsumerStatefulWidget {
  const LeavePermissionsTab({Key? key}) : super(key: key);

  @override
  ConsumerState<LeavePermissionsTab> createState() => _LeavePermissionsTabState();
}

class _LeavePermissionsTabState extends ConsumerState<LeavePermissionsTab> {
  String _statusFilter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceProvider);
    final notifier = ref.read(attendanceProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    var requests = state.leaveRequests;
    if (_statusFilter != 'ALL') {
      requests = requests.where((r) => r.status.toUpperCase() == _statusFilter).toList();
    }

    final total = state.leaveRequests.length;
    final pending = state.leaveRequests.where((r) => r.status.toUpperCase() == 'PENDING').length;
    final approved = state.leaveRequests.where((r) => r.status.toUpperCase() == 'APPROVED').length;
    final rejected = state.leaveRequests.where((r) => r.status.toUpperCase() == 'REJECTED').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Info Notice Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1B4B).withValues(alpha: 0.4) : const Color(0xFFFAF5FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF3730A3) : const Color(0xFFE9D5FF)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.beach_access_rounded, color: Color(0xFF8B5CF6), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Integrated Leave Management & Attendance Synchronization',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF6B21A8),
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Approved leave applications are automatically reflected in daily student and staff attendance rosters as "On Leave (O)".',
                        style: TextStyle(
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF7E22CE),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Header Row & Quick Filter Tabs
          Row(
            children: [
              Text(
                'Leave Requests',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 14),
              _buildFilterChip('ALL', 'All ($total)', isDark),
              const SizedBox(width: 8),
              _buildFilterChip('PENDING', 'Pending ($pending)', isDark),
              const SizedBox(width: 8),
              _buildFilterChip('APPROVED', 'Approved ($approved)', isDark),
              const SizedBox(width: 8),
              _buildFilterChip('REJECTED', 'Rejected ($rejected)', isDark),
            ],
          ),
          const SizedBox(height: 16),

          // Leave Requests List
          if (requests.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.event_busy_rounded, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(
                    'No leave requests found for this filter',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final req = requests[index];
                return _buildLeaveRequestCard(context, req, notifier, isDark, theme);
              },
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, bool isDark) {
    final isSelected = _statusFilter == key;
    return InkWell(
      onTap: () => setState(() => _statusFilter = key),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4F46E5)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: isSelected
                ? Colors.white
                : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaveRequestCard(
    BuildContext context,
    AttendanceLeaveRequestModel req,
    AttendanceNotifier notifier,
    bool isDark,
    ThemeData theme,
  ) {
    final startStr = DateFormat('dd MMM yyyy').format(req.startDate);
    final endStr = DateFormat('dd MMM yyyy').format(req.endDate);
    final isPending = req.status.toLowerCase() == 'pending';
    final isApproved = req.status.toLowerCase() == 'approved';

    Color statusColor = const Color(0xFFF59E0B);
    Color statusBg = const Color(0xFFFFFBEB);
    Color statusBorder = const Color(0xFFFDE68A);

    if (isApproved) {
      statusColor = const Color(0xFF10B981);
      statusBg = const Color(0xFFECFDF5);
      statusBorder = const Color(0xFFBBF7D0);
    } else if (req.status.toLowerCase() == 'rejected') {
      statusColor = const Color(0xFFEF4444);
      statusBg = const Color(0xFFFEF2F2);
      statusBorder = const Color(0xFFFECACA);
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
              border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.25)),
            ),
            child: Center(
              child: Text(
                req.applicantName.isNotEmpty ? req.applicantName[0].toUpperCase() : 'A',
                style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF8B5CF6), fontSize: 16),
              ),
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
                      '${req.applicantName} • ${req.applicantRole.toUpperCase()}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? statusColor.withValues(alpha: 0.15) : statusBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: statusBorder),
                      ),
                      child: Text(
                        req.status.toUpperCase(),
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${req.leaveType} • $startStr to $endStr (${req.daysCount} days)',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Reason: ${req.reason}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                  ),
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
            const SizedBox(width: 16),
            Column(
              children: [
                ElevatedButton(
                  onPressed: () => notifier.handleLeaveAction(req.id, 'APPROVE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    elevation: 0,
                  ),
                  child: const Text('Approve', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 6),
                OutlinedButton(
                  onPressed: () => notifier.handleLeaveAction(req.id, 'REJECT'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFFECACA)),
                    backgroundColor: const Color(0xFFFEF2F2),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('Reject', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
