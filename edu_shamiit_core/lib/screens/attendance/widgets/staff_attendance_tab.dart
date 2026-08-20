import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/attendance_models.dart';
import '../providers/attendance_provider.dart';

class StaffAttendanceTab extends ConsumerStatefulWidget {
  const StaffAttendanceTab({Key? key}) : super(key: key);

  @override
  ConsumerState<StaffAttendanceTab> createState() => _StaffAttendanceTabState();
}

class _StaffAttendanceTabState extends ConsumerState<StaffAttendanceTab> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
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
          // Filter Bar
          _buildFilterBar(state, notifier, theme),
          const SizedBox(height: 16),

          // Staff Table
          _buildStaffTable(state, notifier, theme),
          const SizedBox(height: 16),

          // Bottom Bar
          _buildBottomBar(state, notifier, theme),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildFilterBar(AttendanceState state, AttendanceNotifier notifier, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Date Navigator
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.dividerColor.withOpacity(0.12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 20),
                  onPressed: () => notifier.prevDay(),
                  tooltip: 'Previous Day',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                ),
                Text(
                  state.displayDateString,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, size: 20),
                  onPressed: () => notifier.nextDay(),
                  tooltip: 'Next Day',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                ),
              ],
            ),
          ),

          // Search Field
          SizedBox(
            width: 260,
            height: 38,
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                // Filter staff
              },
              decoration: InputDecoration(
                hintText: 'Search staff name, email, employee code...',
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                filled: true,
                fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffTable(AttendanceState state, AttendanceNotifier notifier, ThemeData theme) {
    if (state.staffRoster.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
        ),
        child: const Column(
          children: [
            Icon(Icons.badge_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('No staff or employee records found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
              child: const Row(
                children: [
                  SizedBox(width: 80, child: Text('Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 3, child: Text('Employee', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 2, child: Text('Department', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 3, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 2, child: Text('Check-In / Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 2, child: Text('Remarks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                ],
              ),
            ),
            const Divider(height: 1),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.staffRoster.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final emp = state.staffRoster[index];
                final currentStatus = state.draftStaffStatuses[emp.employeeId] ?? emp.status;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(emp.employeeCode.isNotEmpty ? emp.employeeCode : '-', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      ),
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 15,
                              backgroundColor: const Color(0xFF4F46E5).withOpacity(0.12),
                              backgroundImage: emp.avatarUrl != null ? NetworkImage(emp.avatarUrl!) : null,
                              child: emp.avatarUrl == null
                                  ? Text(
                                      emp.fullName.isNotEmpty ? emp.fullName[0].toUpperCase() : 'E',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(emp.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text(emp.designation, style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(emp.department, style: const TextStyle(fontSize: 12)),
                      ),
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            _buildStaffStatusBtn(emp, AttendanceStatus.present, currentStatus, notifier),
                            const SizedBox(width: 4),
                            _buildStaffStatusBtn(emp, AttendanceStatus.absent, currentStatus, notifier),
                            const SizedBox(width: 4),
                            _buildStaffStatusBtn(emp, AttendanceStatus.late, currentStatus, notifier),
                            const SizedBox(width: 4),
                            _buildStaffStatusBtn(emp, AttendanceStatus.onLeave, currentStatus, notifier),
                            const SizedBox(width: 4),
                            _buildStaffStatusBtn(emp, AttendanceStatus.workFromHome, currentStatus, notifier),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          emp.checkInTime != null ? '${emp.checkInTime} - ${emp.checkOutTime ?? "Pending"}' : 'Not logged',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          emp.remarks.isNotEmpty ? emp.remarks : '-',
                          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffStatusBtn(
    StaffAttendanceRowModel emp,
    AttendanceStatus status,
    AttendanceStatus currentStatus,
    AttendanceNotifier notifier,
  ) {
    final isSelected = currentStatus == status;

    return InkWell(
      onTap: () => notifier.updateStaffStatus(emp.employeeId, status),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? status.color : status.backgroundColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? status.color : status.borderColor),
        ),
        child: Text(
          status.code,
          style: TextStyle(
            color: isSelected ? Colors.white : status.color,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(AttendanceState state, AttendanceNotifier notifier, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ElevatedButton.icon(
          onPressed: state.isSaving ? null : () => notifier.saveStaffAttendance(),
          icon: state.isSaving
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_rounded, size: 16),
          label: Text(state.isSaving ? 'Saving...' : 'Save Staff Attendance'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
    );
  }
}
