import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../constants/app_fonts.dart';
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
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Text(
            'Bulk Attendance Operations',
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Perform class-wide updates, mass status overwrites, locking/unlocking, and rapid batch exports.',
            style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12),
          ),
          const SizedBox(height: 20),

          // 1. Bulk Status Assignment Card
          _buildCard(
            icon: Icons.bolt_rounded,
            iconColor: const Color(0xFF4F46E5),
            iconBgColor: const Color(0xFFEEF2FF),
            title: '1. Bulk Mark Entire Class Status',
            subtitle: 'Quickly set all students in the selected class and section to a specific status in one batch.',
            isDark: isDark,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Target Status: ',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<AttendanceStatus>(
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
                                  Text(st.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedTargetStatus = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _remarksController,
                    style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'Optional bulk remarks (e.g. Rainy Day / Field Trip / Sports Tournament)',
                      hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                      ),
                    ),
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
                  label: const Text('Apply to All Students in Class', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 2. Bulk Lock / Unlock Card
          _buildCard(
            icon: Icons.lock_outline_rounded,
            iconColor: const Color(0xFFF59E0B),
            iconBgColor: const Color(0xFFFFFBEB),
            title: '2. Mass Lock / Unlock Records',
            subtitle: 'Freeze attendance records across the selected class or allow teacher revisions.',
            isDark: isDark,
            content: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    final allIds = state.roster.map((s) => s.studentId).toList();
                    notifier.executeBulkOperation(
                      operation: 'LOCK',
                      studentIds: allIds,
                    );
                  },
                  icon: const Icon(Icons.lock_rounded, size: 15),
                  label: const Text('Lock Entire Class', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    final allIds = state.roster.map((s) => s.studentId).toList();
                    notifier.executeBulkOperation(
                      operation: 'UNLOCK',
                      studentIds: allIds,
                    );
                  },
                  icon: const Icon(Icons.lock_open_rounded, size: 15),
                  label: const Text('Unlock Entire Class', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                    side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 3. Export CSV Card
          _buildCard(
            icon: Icons.file_download_outlined,
            iconColor: const Color(0xFF10B981),
            iconBgColor: const Color(0xFFECFDF5),
            title: '3. Export Attendance CSV & Spreadsheets',
            subtitle: 'Download complete, formatted attendance logs for administrative auditing and official records.',
            isDark: isDark,
            content: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    notifier.exportAttendanceCsv();
                  },
                  icon: const Icon(Icons.download_rounded, size: 15),
                  label: const Text('Download Class CSV', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF10B981),
                    backgroundColor: const Color(0xFFECFDF5),
                    side: const BorderSide(color: Color(0xFFBBF7D0)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required Widget content,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? iconColor.withValues(alpha: 0.15) : iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }
}
