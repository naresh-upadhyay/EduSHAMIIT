import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/utils/download_helper.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/hostel_models.dart';
import '../../providers/hostel_provider.dart';
import 'edit_hostel_staff_dialog.dart';
import 'transfer_hostel_staff_dialog.dart';
import 'end_hostel_staff_dialog.dart';
import '../common/hostel_smooth_spinner.dart';

class HostelStaffDetailsDrawer extends ConsumerWidget {
  const HostelStaffDetailsDrawer({super.key});

  static const List<String> _tabs = [
    'Overview',
    'Assignment',
    'Leave',
    'Documents',
    'History',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hostelProvider);
    final notifier = ref.read(hostelProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final detail = state.selectedStaffDetail;

    if (state.isStaffDetailLoading) {
      return Container(
        decoration: _containerDecoration(isDark),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(strokeWidth: 2.5),
              SizedBox(height: 12),
              Text('Loading staff 360 profile...', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
        ),
      );
    }

    if (detail == null) {
      return Container(
        decoration: _containerDecoration(isDark),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Select a staff member from the roster to view their details',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: _containerDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Drawer Header Bar (Staff Details + Close X)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Staff Details',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Close Drawer',
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  onPressed: () => notifier.closeStaffDrawer(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 2. Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hero Profile Card
                  _buildHeroProfile(detail, isDark),
                  const SizedBox(height: 16),

                  // 5 Inner Tabs Bar (Overview, Assignment, Leave, Documents, History)
                  _buildInnerTabBar(state.staffDrawerTab, notifier, isDark),
                  const SizedBox(height: 16),

                  // Inner Tab View Content
                  _buildInnerTabContent(context, state.staffDrawerTab, detail, notifier, isDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _containerDecoration(bool isDark) {
    return BoxDecoration(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ],
    );
  }

  Widget _buildHeroProfile(HostelStaffDetail360 detail, bool isDark) {
    return Column(
      children: [
        // Avatar
        CircleAvatar(
          radius: 36,
          backgroundImage: detail.avatarUrl != null && detail.avatarUrl!.isNotEmpty
              ? NetworkImage(detail.avatarUrl!)
              : null,
          backgroundColor: const Color(0xFFEFF6FF),
          child: detail.avatarUrl == null || detail.avatarUrl!.isEmpty
              ? Text(
                  detail.fullName.isNotEmpty ? detail.fullName[0] : 'S',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                )
              : null,
        ),
        const SizedBox(height: 10),

        // Name and Status Pill
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                detail.fullName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: detail.status.toLowerCase().contains('active')
                    ? (isDark ? const Color(0xFF14532D).withValues(alpha: 0.3) : const Color(0xFFDCFCE7))
                    : (isDark ? const Color(0xFF78350F).withValues(alpha: 0.3) : const Color(0xFFFEF3C7)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: detail.status.toLowerCase().contains('active')
                      ? const Color(0xFF86EFAC)
                      : const Color(0xFFFDE68A),
                  width: 0.8,
                ),
              ),
              child: Text(
                detail.status,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: detail.status.toLowerCase().contains('active')
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFD97706),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),

        // Subtitle: Warden - Boys Hostel A
        Text(
          '${detail.role} - ${detail.hostelName}',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 4),

        // Meta row: Staff ID: HS001 · Joined: 12 Apr 2023
        Text(
          'Staff ID: ${detail.employeeId} · Joined: ${detail.joiningDate}',
          style: TextStyle(
            fontSize: 11.5,
            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  Widget _buildInnerTabBar(int activeTab, HostelNotifier notifier, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _tabs.asMap().entries.map((entry) {
            final index = entry.key;
            final label = entry.value;
            final isSelected = activeTab == index;

            return InkWell(
              onTap: () => notifier.setStaffDrawerTab(index),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildInnerTabContent(
    BuildContext context,
    int activeTab,
    HostelStaffDetail360 detail,
    HostelNotifier notifier,
    bool isDark,
  ) {
    switch (activeTab) {
      case 0:
        return _buildOverviewTab(context, detail, notifier, isDark);
      case 1:
        return _buildAssignmentTab(context, detail, notifier, isDark);
      case 2:
        return _buildLeaveTab(context, detail, notifier, isDark);
      case 3:
        return _buildDocumentsTab(context, detail, notifier, isDark);
      case 4:
        return _buildHistoryTab(context, detail, isDark);
      default:
        return _buildOverviewTab(context, detail, notifier, isDark);
    }
  }

  Widget _buildOverviewTab(
    BuildContext context,
    HostelStaffDetail360 detail,
    HostelNotifier notifier,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Key-Value attributes matching screenshot
        _buildInfoRow(Icons.badge_outlined, 'Role', detail.role, isDark),
        _buildInfoRow(Icons.apartment_rounded, 'Hostel', detail.hostelName, isDark),
        _buildInfoRow(Icons.phone_outlined, 'Contact', detail.contact, isDark),
        _buildInfoRow(Icons.email_outlined, 'Email', detail.email, isDark),
        _buildInfoRow(Icons.location_on_outlined, 'Address', detail.address, isDark),
        _buildInfoRow(Icons.shield_outlined, 'Emergency Contact', detail.emergencyContact, isDark),
        _buildInfoRow(Icons.access_time_rounded, 'Shift Timings', detail.shiftTimings, isDark),
        _buildInfoRow(Icons.supervisor_account_outlined, 'Reporting To', detail.reportingTo, isDark),
        _buildInfoRow(Icons.check_circle_outline_rounded, 'Status', detail.status, isDark, isStatus: true),

        const SizedBox(height: 20),

        // Assigned Areas Header with Edit button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Assigned Areas',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            InkWell(
              onTap: () async {
                final staffItem = HostelStaffRosterItem(
                  assignmentId: detail.assignmentId,
                  profileId: detail.profileId,
                  rowNum: 1,
                  name: detail.fullName,
                  employeeId: detail.employeeId,
                  role: detail.role,
                  hostelName: detail.hostelName,
                  assignedArea: detail.assignedAreas.isNotEmpty ? detail.assignedAreas.first.areaName : 'Overall',
                  contact: detail.contact,
                  status: detail.status,
                  shiftTimings: detail.shiftTimings,
                );
                await showDialog(
                  context: context,
                  builder: (context) => EditHostelStaffDialog(staff: staffItem),
                );
                await notifier.fetchStaffDetail(detail.assignmentId);
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_outlined, size: 14, color: Color(0xFF2563EB)),
                  SizedBox(width: 4),
                  Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 4 Assigned Area Cards matching screenshot
        ...detail.assignedAreas.map((area) => _buildAreaCard(area, isDark)),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, bool isDark, {bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 15,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 70, maxWidth: 105),
            child: Text(
              '$label :',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '-',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isStatus && value.toLowerCase().contains('active')
                    ? const Color(0xFF16A34A)
                    : (isDark ? Colors.white : const Color(0xFF1E293B)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAreaCard(HostelStaffArea area, bool isDark) {
    IconData icon = Icons.supervised_user_circle_rounded;
    Color iconColor = const Color(0xFF2563EB);
    Color iconBg = isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF);

    if (area.areaName.toLowerCase().contains('discipline') || area.areaName.toLowerCase().contains('safety')) {
      icon = Icons.security_rounded;
      iconColor = const Color(0xFF2563EB);
    } else if (area.areaName.toLowerCase().contains('welfare')) {
      icon = Icons.volunteer_activism_rounded;
      iconColor = const Color(0xFF7C3AED);
      iconBg = isDark ? const Color(0xFF4C1D95).withValues(alpha: 0.3) : const Color(0xFFF5F3FF);
    } else if (area.areaName.toLowerCase().contains('mess')) {
      icon = Icons.restaurant_rounded;
      iconColor = const Color(0xFFEA580C);
      iconBg = isDark ? const Color(0xFF7C2D12).withValues(alpha: 0.3) : const Color(0xFFFFF7ED);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              area.areaName,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBFDBFE), width: 0.8),
            ),
            child: Text(
              area.badgeLabel,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2563EB),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentTab(
    BuildContext context,
    HostelStaffDetail360 detail,
    HostelNotifier notifier,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionCard(
          title: 'Current Duty Scope',
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailItem('Assigned Facility', detail.hostelName, isDark),
              _buildDetailItem('Primary Role', detail.role, isDark),
              _buildDetailItem('Standard Shift', detail.shiftTimings, isDark),
              _buildDetailItem('Reporting Officer', detail.reportingTo, isDark),
              _buildDetailItem('Start Date', detail.joiningDate, isDark),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          title: 'Actions & Operations',
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  final staffItem = HostelStaffRosterItem(
                    assignmentId: detail.assignmentId,
                    profileId: detail.profileId,
                    rowNum: 1,
                    name: detail.fullName,
                    employeeId: detail.employeeId,
                    role: detail.role,
                    hostelName: detail.hostelName,
                    assignedArea: 'Overall',
                    contact: detail.contact,
                    status: detail.status,
                  );
                  showDialog(
                    context: context,
                    builder: (context) => TransferHostelStaffDialog(staff: staffItem),
                  );
                },
                icon: const Icon(Icons.swap_horiz, size: 16),
                label: const Text('Transfer to Another Hostel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(0, 36),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  final staffItem = HostelStaffRosterItem(
                    assignmentId: detail.assignmentId,
                    profileId: detail.profileId,
                    rowNum: 1,
                    name: detail.fullName,
                    employeeId: detail.employeeId,
                    role: detail.role,
                    hostelName: detail.hostelName,
                    assignedArea: 'Overall',
                    contact: detail.contact,
                    status: detail.status,
                  );
                  showDialog(
                    context: context,
                    builder: (context) => EndHostelStaffDialog(staff: staffItem),
                  );
                },
                icon: const Icon(Icons.person_off_outlined, size: 16, color: Color(0xFFDC2626)),
                label: const Text('End Hostel Assignment', style: TextStyle(color: Color(0xFFDC2626))),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                  minimumSize: const Size(0, 36),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // INNER TAB 2: LEAVE & DUTY RELIEF (Dynamic From DB & HR-Synced)
  // ==========================================================================
  Widget _buildLeaveTab(
    BuildContext context,
    HostelStaffDetail360 detail,
    HostelNotifier notifier,
    bool isDark,
  ) {
    final isOnLeave = detail.status.toLowerCase().contains('leave');
    final leaves = detail.leaves;

    final now = DateTime.now();
    double effectiveMonthlyLeaves = detail.monthlyLeavesTaken;
    if (effectiveMonthlyLeaves <= 0 && detail.leaves.isNotEmpty) {
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      for (final l in detail.leaves) {
        if (l.status == 'REJECTED' || l.status == 'CANCELLED') continue;
        final s = DateTime.tryParse(l.rawStartDate.isNotEmpty ? l.rawStartDate : l.startDate);
        final e = DateTime.tryParse(l.rawEndDate.isNotEmpty ? l.rawEndDate : l.endDate);
        if (s != null && e != null) {
          if (!(e.isBefore(monthStart) || s.isAfter(monthEnd))) {
            effectiveMonthlyLeaves += l.daysCount;
          }
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Current Status Banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isOnLeave
                ? (isDark ? const Color(0xFF78350F).withValues(alpha: 0.3) : const Color(0xFFFEF3C7))
                : (isDark ? const Color(0xFF14532D).withValues(alpha: 0.3) : const Color(0xFFDCFCE7)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isOnLeave ? const Color(0xFFFDE68A) : const Color(0xFF86EFAC),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isOnLeave ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                color: isOnLeave ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isOnLeave
                      ? 'Currently on authorized hostel duty leave. Coverage assigned to: ${detail.activeSubstituteWarden}.'
                      : 'Staff is currently active and on duty for assigned hostel shifts.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isOnLeave ? const Color(0xFF92400E) : const Color(0xFF14532D),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 2. Action Buttons Row
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showRecordStaffLeaveDialog(context, notifier, detail, isDark),
                icon: const Icon(Icons.add_circle_outline, size: 15, color: Colors.white),
                label: const Text('Record Leave', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ),
            if (isOnLeave) ...[
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await notifier.returnStaffToDuty(detail.assignmentId);
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 16, color: Colors.white),
                  label: const Text('Resume Duty', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(0, 36),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),

        // 3. HR-Synced Duty Record Card
        _buildSectionCard(
          title: 'Leave & Outing Record (HR Synced)',
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailItem('Duty Shift Attendance', '98.2% Regular', isDark),
              _buildDetailItem(
                'Monthly Leaves Taken',
                '${effectiveMonthlyLeaves.toStringAsFixed(0)} Days',
                isDark,
              ),
              _buildDetailItem(
                'Shift Timing & Hours',
                detail.shiftTimings.isNotEmpty ? detail.shiftTimings : 'Day Shift (08:00 AM - 10:00 PM)',
                isDark,
              ),
              _buildDetailItem('Backup Substitute', detail.activeSubstituteWarden, isDark),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4. Leave Records List
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Leave History & Relief Records (${leaves.length})',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (leaves.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.event_available_outlined, size: 32, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                const SizedBox(height: 6),
                Text(
                  'No Recorded Absence Records',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
                const SizedBox(height: 2),
                Text(
                  'Click "+ Record Leave" above to log duty relief or leave.',
                  style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ],
            ),
          )
        else
          ...leaves.map((l) {
            Color statusColor;
            switch (l.status.toUpperCase()) {
              case 'APPROVED':
                statusColor = const Color(0xFF16A34A);
                break;
              case 'PENDING':
                statusColor = const Color(0xFFD97706);
                break;
              case 'COMPLETED':
                statusColor = const Color(0xFF2563EB);
                break;
              case 'REJECTED':
                statusColor = const Color(0xFFDC2626);
                break;
              default:
                statusColor = const Color(0xFF64748B);
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          l.leaveType,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: statusColor.withValues(alpha: 0.4), width: 0.8),
                        ),
                        child: Text(
                          l.status,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.date_range_outlined, size: 13, color: Color(0xFF2563EB)),
                      const SizedBox(width: 5),
                      Text(
                        '${l.startDate} - ${l.endDate} (${l.daysCount.toStringAsFixed(0)} Days)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                  if (l.reason.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      l.reason,
                      style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Coverage: ${l.substituteStaffName}',
                          style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (l.emergencyContact.isNotEmpty)
                        Text(
                          ' · ${l.emergencyContact}',
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF2563EB)),
                        ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // ==========================================================================
  // INNER TAB 3: DOCUMENTS (Dynamic Upload, Verify, Download & Delete)
  // ==========================================================================
  Widget _buildDocumentsTab(
    BuildContext context,
    HostelStaffDetail360 detail,
    HostelNotifier notifier,
    bool isDark,
  ) {
    final docs = detail.documents;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Verified Documents (${docs.length})',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _showUploadStaffDocumentDialog(context, notifier, detail, isDark),
              icon: const Icon(Icons.upload_file_rounded, size: 14, color: Colors.white),
              label: const Text('Upload', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 28),
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (docs.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.folder_open_rounded, size: 36, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                const SizedBox(height: 8),
                Text(
                  'No Documents Uploaded',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Click "Upload" above to attach verified staff compliance documents.',
                  style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ],
            ),
          )
        else
          ...docs.map((d) {
            final isPdf = d.fileExtension == 'PDF';
            final isImage = d.fileExtension == 'PNG' || d.fileExtension == 'JPG' || d.fileExtension == 'JPEG';
            final docIcon = isPdf
                ? Icons.picture_as_pdf_rounded
                : isImage
                    ? Icons.image_rounded
                    : Icons.description_rounded;
            final iconColor = isPdf
                ? const Color(0xFFDC2626)
                : isImage
                    ? const Color(0xFF0D9488)
                    : const Color(0xFF2563EB);

            Color statusColor;
            switch (d.verificationStatus.toUpperCase()) {
              case 'VERIFIED':
                statusColor = const Color(0xFF16A34A);
                break;
              case 'SIGNED':
                statusColor = const Color(0xFF2563EB);
                break;
              case 'ACKNOWLEDGED':
                statusColor = const Color(0xFF7C3AED);
                break;
              case 'PENDING':
                statusColor = const Color(0xFFD97706);
                break;
              case 'REJECTED':
                statusColor = const Color(0xFFDC2626);
                break;
              default:
                statusColor = const Color(0xFF64748B);
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(docIcon, size: 18, color: iconColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.documentName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 6,
                          runSpacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '${d.fileExtension} · ${d.fileSizeFormatted}',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                d.verificationStatus,
                                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: statusColor),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Actions row with compact buttons (24x24) to avoid any RenderFlex overflow
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Verify / Change Status Action
                      Tooltip(
                        message: 'Verify / Update Status',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(4),
                          onTap: () => _showVerifyStaffDocumentDialog(context, notifier, detail, d, isDark),
                          child: const Padding(
                            padding: EdgeInsets.all(5),
                            child: Icon(Icons.verified_outlined, size: 16, color: Color(0xFF2563EB)),
                          ),
                        ),
                      ),
                      // Download Action
                      Tooltip(
                        message: 'Download Copy',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(4),
                          onTap: () async {
                            final ext = d.fileExtension.toLowerCase();
                            final baseName = d.documentName.replaceAll(RegExp(r'\s+'), '_');
                            final filename = baseName.toLowerCase().endsWith('.$ext') ? baseName : '$baseName.$ext';

                            // 1. Download real original bytes from backend staff document download endpoint
                            final realBytes = await notifier.downloadStaffDocument(d.id);
                            if (realBytes != null && realBytes.isNotEmpty) {
                              await getDownloadHelper().downloadBytes(realBytes, filename);
                            } else if (d.fileUrl.isNotEmpty && d.fileUrl.startsWith('http')) {
                              // 2. Direct public URL fallback
                              await getDownloadHelper().downloadFile(d.fileUrl, filename);
                            } else {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to download staff document: file content is not available'),
                                    backgroundColor: Color(0xFFDC2626),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                              return;
                            }

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Downloaded verified copy of ${d.documentName}'),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: const Color(0xFF16A34A),
                                ),
                              );
                            }
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(5),
                            child: Icon(Icons.download_rounded, size: 16, color: Color(0xFF64748B)),
                          ),
                        ),
                      ),
                      // Delete Action
                      Tooltip(
                        message: 'Delete Document',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(4),
                          onTap: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Document?'),
                                content: Text('Are you sure you want to delete "${d.documentName}"?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await notifier.deleteStaffDocument(
                                staffId: detail.assignmentId,
                                documentId: d.id,
                              );
                            }
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(5),
                            child: Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // ==========================================================================
  // INNER TAB 4: HISTORY & AUDIT LOGS (Fixed Screen Breaking & Zero Overflows)
  // ==========================================================================
  Widget _buildHistoryTab(BuildContext context, HostelStaffDetail360 detail, bool isDark) {
    if (detail.activities.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No recorded audit events for this staff member',
            style: TextStyle(fontSize: 12.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
        ),
      );
    }

    return Column(
      children: detail.activities.map((act) {
        Color badgeCol = const Color(0xFF2563EB);
        if (act.badgeColor == 'green') badgeCol = const Color(0xFF16A34A);
        if (act.badgeColor == 'purple') badgeCol = const Color(0xFF9333EA);
        if (act.badgeColor == 'orange') badgeCol = const Color(0xFFD97706);
        if (act.badgeColor == 'red') badgeCol = const Color(0xFFDC2626);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Constrained Row to guarantee ZERO horizontal overflow
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      act.title,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: badgeCol,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    act.createdAt,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                act.description,
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ==========================================================================
  // HELPER DIALOGS: UPLOAD DOCUMENT, VERIFY DOCUMENT, RECORD LEAVE
  // ==========================================================================

  void _showUploadStaffDocumentDialog(
    BuildContext context,
    HostelNotifier notifier,
    HostelStaffDetail360 detail,
    bool isDark,
  ) {
    final nameCtrl = TextEditingController(text: 'Staff Document');
    String docType = 'IDENTITY_VERIFICATION';
    String status = 'VERIFIED';
    final notesCtrl = TextEditingController();
    PlatformFile? pickedFile;
    String? fileError;
    bool isSubmitting = false;

    final docTypeOptions = [
      {'key': 'IDENTITY_VERIFICATION', 'label': 'Identity Verification (Aadhaar / Passport)'},
      {'key': 'POLICE_VERIFICATION', 'label': 'Police Verification Certificate'},
      {'key': 'APPOINTMENT_ORDER', 'label': 'Hostel Administrator Duty Appointment Order'},
      {'key': 'SAFETY_UNDERTAKING', 'label': 'Child Protection & Campus Safety Undertaking'},
      {'key': 'MEDICAL_FITNESS', 'label': 'Medical Fitness Certificate'},
      {'key': 'QUALIFICATION_CERTIFICATE', 'label': 'Qualification / Training Certificate'},
      {'key': 'OTHER', 'label': 'Other Compliance Document'},
    ];

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: [
                const Icon(Icons.upload_file_rounded, color: Color(0xFF2563EB), size: 22),
                const SizedBox(width: 8),
                Text(
                  'Upload Staff Document',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // File Selection Area
                    Text(
                      'Select Document File *',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        try {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: [
                              'pdf', 'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'svg',
                              'doc', 'docx', 'xls', 'xlsx', 'csv', 'ppt', 'pptx', 'txt'
                            ],
                            withData: true,
                          );
                          if (result != null && result.files.isNotEmpty) {
                            setDialogState(() {
                              pickedFile = result.files.first;
                              fileError = null;
                              if (nameCtrl.text.trim().isEmpty || nameCtrl.text == 'Staff Document') {
                                nameCtrl.text = pickedFile!.name.split('.').first;
                              }
                            });
                          }
                        } catch (_) {}
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: pickedFile != null
                                ? const Color(0xFF16A34A)
                                : (fileError != null ? const Color(0xFFDC2626) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                            width: pickedFile != null ? 1.5 : 1.0,
                          ),
                          color: pickedFile != null
                              ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.2) : const Color(0xFFF0FDF4))
                              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              pickedFile != null ? Icons.check_circle_rounded : Icons.attach_file_rounded,
                              color: pickedFile != null ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                              size: 26,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pickedFile != null ? pickedFile!.name : 'Click to select document file (PDF, Image, Word, Excel, etc.)',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: pickedFile != null ? FontWeight.w600 : FontWeight.normal,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    pickedFile != null
                                        ? (pickedFile!.size >= 1024 * 1024
                                            ? '${(pickedFile!.size / (1024 * 1024)).toStringAsFixed(1)} MB'
                                            : '${(pickedFile!.size / 1024).toStringAsFixed(1)} KB')
                                        : 'Supported formats: PDF, Images (JPG, PNG, WEBP), Office Docs (DOCX, XLSX), Max 20MB',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: pickedFile != null ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (pickedFile != null)
                              TextButton(
                                onPressed: () => setDialogState(() => pickedFile = null),
                                child: const Text('Remove', style: TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (fileError != null) ...[
                      const SizedBox(height: 4),
                      Text(fileError!, style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
                    ],
                    const SizedBox(height: 12),

                    // Document Name
                    Text('Document Title *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. Identity Verification (Aadhaar / Passport)',
                        isDense: true,
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Document Type
                    Text('Document Category *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: docType,
                      isExpanded: true,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: docTypeOptions.map((opt) {
                        return DropdownMenuItem<String>(
                          value: opt['key'],
                          child: Text(opt['label']!, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            docType = val;
                            final selected = docTypeOptions.firstWhere((o) => o['key'] == val);
                            nameCtrl.text = selected['label']!;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Verification Status
                    Text('Initial Verification Status *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'VERIFIED', child: Text('VERIFIED (Approved Compliance)')),
                        DropdownMenuItem(value: 'SIGNED', child: Text('SIGNED (Official Order)')),
                        DropdownMenuItem(value: 'ACKNOWLEDGED', child: Text('ACKNOWLEDGED (Undertaking)')),
                        DropdownMenuItem(value: 'PENDING', child: Text('PENDING (Needs Review)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => status = val);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Notes
                    Text('Verification Notes / Remarks', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'e.g. Verified against HRMS official staff file',
                        isDense: true,
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final title = nameCtrl.text.trim();
                        if (pickedFile == null) {
                          setDialogState(() => fileError = 'Please select a document file to upload');
                          return;
                        }
                        if (title.isEmpty) return;

                        setDialogState(() => isSubmitting = true);
                        final ext = pickedFile!.name.split('.').last.toLowerCase();
                        final String mime;
                        switch (ext) {
                          case 'pdf': mime = 'application/pdf'; break;
                          case 'jpg':
                          case 'jpeg': mime = 'image/jpeg'; break;
                          case 'png': mime = 'image/png'; break;
                          case 'webp': mime = 'image/webp'; break;
                          case 'gif': mime = 'image/gif'; break;
                          case 'bmp': mime = 'image/bmp'; break;
                          case 'svg': mime = 'image/svg+xml'; break;
                          case 'doc': mime = 'application/msword'; break;
                          case 'docx': mime = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'; break;
                          case 'xls': mime = 'application/vnd.ms-excel'; break;
                          case 'xlsx': mime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'; break;
                          case 'csv': mime = 'text/csv'; break;
                          case 'ppt': mime = 'application/vnd.ms-powerpoint'; break;
                          case 'pptx': mime = 'application/vnd.openxmlformats-officedocument.presentationml.presentation'; break;
                          case 'txt': mime = 'text/plain'; break;
                          default: mime = 'application/octet-stream'; break;
                        }

                        await notifier.uploadStaffDocument(
                          staffId: detail.assignmentId,
                          documentName: title,
                          documentType: docType,
                          fileBytes: pickedFile!.bytes,
                          fileName: pickedFile!.name,
                          fileSizeBytes: pickedFile!.size,
                          mimeType: mime,
                          verificationStatus: status,
                          notes: notesCtrl.text.trim(),
                        );
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: HostelSmoothSpinner(size: 16, strokeWidth: 2, color: Colors.white))
                    : const Text('Upload & Save', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showVerifyStaffDocumentDialog(
    BuildContext context,
    HostelNotifier notifier,
    HostelStaffDetail360 detail,
    HostelStaffDocument doc,
    bool isDark,
  ) {
    String status = doc.verificationStatus;
    final notesCtrl = TextEditingController(text: doc.notes ?? '');
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: [
                const Icon(Icons.verified_user_outlined, color: Color(0xFF16A34A), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Verify Staff Document',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.documentName,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(height: 12),
                  Text('Update Verification Status *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'VERIFIED', child: Text('VERIFIED (Approved)')),
                      DropdownMenuItem(value: 'SIGNED', child: Text('SIGNED (Countersigned Order)')),
                      DropdownMenuItem(value: 'ACKNOWLEDGED', child: Text('ACKNOWLEDGED (Formal Pledge)')),
                      DropdownMenuItem(value: 'PENDING', child: Text('PENDING (Awaiting Verification)')),
                      DropdownMenuItem(value: 'REJECTED', child: Text('REJECTED (Non-compliant)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => status = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  Text('Verification Remarks / Notes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Enter compliance or verification notes...',
                      isDense: true,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        setDialogState(() => isSubmitting = true);
                        await notifier.verifyStaffDocument(
                          staffId: detail.assignmentId,
                          documentId: doc.id,
                          verificationStatus: status,
                          notes: notesCtrl.text.trim(),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                child: isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: HostelSmoothSpinner(size: 16, strokeWidth: 2, color: Colors.white))
                    : const Text('Save Verification', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showRecordStaffLeaveDialog(
    BuildContext context,
    HostelNotifier notifier,
    HostelStaffDetail360 detail,
    bool isDark,
  ) {
    String leaveType = 'Casual Leave';
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 2));
    final reasonCtrl = TextEditingController(text: 'Authorized hostel duty leave with scheduled substitute coverage');
    final substituteCtrl = TextEditingController(text: 'Rajesh Sharma (Backup Warden)');
    final contactCtrl = TextEditingController(text: detail.contact.isNotEmpty ? detail.contact : '+91 98765 43210');
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final days = (endDate.difference(startDate).inDays + 1).clamp(1, 90);

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: [
                const Icon(Icons.event_note_rounded, color: Color(0xFF2563EB), size: 22),
                const SizedBox(width: 8),
                Text(
                  'Record Staff Leave & Relief',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Staff: ${detail.fullName} (${detail.role} · ${detail.hostelName})', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),

                    // Leave Type
                    Text('Leave Type *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: leaveType,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Casual Leave', child: Text('Casual Leave')),
                        DropdownMenuItem(value: 'Sick Leave', child: Text('Sick Leave')),
                        DropdownMenuItem(value: 'Emergency Duty Relief', child: Text('Emergency Duty Relief')),
                        DropdownMenuItem(value: 'Planned Off', child: Text('Planned Weekly Off')),
                        DropdownMenuItem(value: 'Annual Leave', child: Text('Annual Leave')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => leaveType = val);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Date range picker row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Start Date *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: ctx,
                                    initialDate: startDate,
                                    firstDate: DateTime(2024),
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) {
                                    setDialogState(() {
                                      startDate = picked;
                                      if (endDate.isBefore(startDate)) {
                                        endDate = startDate;
                                      }
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('${startDate.day}/${startDate.month}/${startDate.year}', style: const TextStyle(fontSize: 12)),
                                      const Icon(Icons.calendar_today, size: 14, color: Color(0xFF64748B)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('End Date *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: ctx,
                                    initialDate: endDate,
                                    firstDate: startDate,
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) {
                                    setDialogState(() => endDate = picked);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('${endDate.day}/${endDate.month}/${endDate.year}', style: const TextStyle(fontSize: 12)),
                                      const Icon(Icons.calendar_today, size: 14, color: Color(0xFF64748B)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Total Duration: $days Days', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                    
                    // Check for overlap against existing staff leaves
                    Builder(
                      builder: (_) {
                        final overlappingLeave = detail.leaves.cast<HostelStaffLeave?>().firstWhere(
                          (l) {
                            if (l == null) return false;
                            if (l.status == 'REJECTED' || l.status == 'CANCELLED') return false;
                            final s = DateTime.tryParse(l.rawStartDate.isNotEmpty ? l.rawStartDate : l.startDate);
                            final e = DateTime.tryParse(l.rawEndDate.isNotEmpty ? l.rawEndDate : l.endDate);
                            if (s == null || e == null) return false;
                            return !(endDate.isBefore(s) || startDate.isAfter(e));
                          },
                          orElse: () => null,
                        );

                        if (overlappingLeave != null) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFCA5A5)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFDC2626)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Selected dates overlap with existing leave: ${overlappingLeave.leaveType} (${overlappingLeave.startDate} - ${overlappingLeave.endDate}). Overlapping leaves are not allowed.',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF991B1B)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    const SizedBox(height: 12),

                    // Substitute Staff
                    Text('Backup Warden / Substitute Staff *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: substituteCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. Rajesh Sharma (Backup Warden)',
                        isDense: true,
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Reason
                    Text('Reason / Justification *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: reasonCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Enter reason for duty absence...',
                        isDense: true,
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final reason = reasonCtrl.text.trim();
                        if (reason.isEmpty) return;

                        final hasOverlap = detail.leaves.any((l) {
                          if (l.status == 'REJECTED' || l.status == 'CANCELLED') return false;
                          final s = DateTime.tryParse(l.rawStartDate.isNotEmpty ? l.rawStartDate : l.startDate);
                          final e = DateTime.tryParse(l.rawEndDate.isNotEmpty ? l.rawEndDate : l.endDate);
                          if (s == null || e == null) return false;
                          return !(endDate.isBefore(s) || startDate.isAfter(e));
                        });

                        if (hasOverlap) {
                          return;
                        }

                        setDialogState(() => isSubmitting = true);
                        final sDate = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
                        final eDate = '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';

                        await notifier.recordStaffLeave(
                          staffId: detail.assignmentId,
                          leaveType: leaveType,
                          startDate: sDate,
                          endDate: eDate,
                          reason: reason,
                          substituteStaffName: substituteCtrl.text.trim(),
                          emergencyContact: contactCtrl.text.trim(),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                child: isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: HostelSmoothSpinner(size: 16, strokeWidth: 2, color: Colors.white))
                    : const Text('Record Leave', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1E293B))),
        ],
      ),
    );
  }
}
