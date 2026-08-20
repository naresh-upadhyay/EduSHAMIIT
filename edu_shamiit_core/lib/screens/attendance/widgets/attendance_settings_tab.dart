import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/attendance_models.dart';
import '../providers/attendance_provider.dart';

class AttendanceSettingsTab extends ConsumerStatefulWidget {
  const AttendanceSettingsTab({Key? key}) : super(key: key);

  @override
  ConsumerState<AttendanceSettingsTab> createState() => _AttendanceSettingsTabState();
}

class _AttendanceSettingsTabState extends ConsumerState<AttendanceSettingsTab> {
  late bool _allowLate;
  late int _lateCutoffMinutes;
  late bool _requireAbsentRemark;
  late bool _requireLateRemark;
  late bool _autoMarkApprovedLeave;
  late int _lockAfterHours;
  late bool _allowTeacherOverride;
  late bool _enableNotifications;
  bool _initialized = false;

  void _syncFromState(AttendanceSettingsModel s) {
    _allowLate = s.allowLate;
    _lateCutoffMinutes = s.lateCutoffMinutes;
    _requireAbsentRemark = s.requireAbsentRemark;
    _requireLateRemark = s.requireLateRemark;
    _autoMarkApprovedLeave = s.autoMarkApprovedLeave;
    _lockAfterHours = s.lockAfterHours;
    _allowTeacherOverride = s.allowTeacherOverrideLocked;
    _enableNotifications = s.enableNotifications;
    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceProvider);
    final notifier = ref.read(attendanceProvider.notifier);
    final theme = Theme.of(context);

    if (!_initialized) {
      _syncFromState(state.settings);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Attendance System Rules & Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            'Configure school-wide attendance rules, late cutoff thresholds, lock durations, and automated parent notifications.',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 20),

          // Settings Container
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                _buildSwitchTile(
                  'Allow Late Attendance Marking',
                  'Permits marking students/staff as Late entries after regular start time.',
                  _allowLate,
                  (val) => setState(() => _allowLate = val),
                  theme,
                ),
                const Divider(height: 24),
                _buildSliderTile(
                  'Late Entry Cutoff (Minutes)',
                  'Minutes after period start time when attendance can be marked as Late.',
                  _lateCutoffMinutes,
                  (val) => setState(() => _lateCutoffMinutes = val),
                  theme,
                ),
                const Divider(height: 24),
                _buildSwitchTile(
                  'Require Remark for Absent Students',
                  'Mandates a justification or doctor note when marking a student Absent.',
                  _requireAbsentRemark,
                  (val) => setState(() => _requireAbsentRemark = val),
                  theme,
                ),
                const Divider(height: 24),
                _buildSwitchTile(
                  'Require Remark for Late Entries',
                  'Mandates a reason when marking a student or employee Late.',
                  _requireLateRemark,
                  (val) => setState(() => _requireLateRemark = val),
                  theme,
                ),
                const Divider(height: 24),
                _buildSwitchTile(
                  'Auto-Mark Approved Leave',
                  'Approved leave applications are automatically synced to daily attendance rosters as On Leave (O).',
                  _autoMarkApprovedLeave,
                  (val) => setState(() => _autoMarkApprovedLeave = val),
                  theme,
                ),
                const Divider(height: 24),
                _buildSwitchTile(
                  'Allow Teachers to Override Locked Records',
                  'If disabled, only School Admins & Principals can override locked attendance with a reason.',
                  _allowTeacherOverride,
                  (val) => setState(() => _allowTeacherOverride = val),
                  theme,
                ),
                const Divider(height: 24),
                _buildSwitchTile(
                  'Enable Automated Notifications to Parents',
                  'Send immediate push/SMS alerts to parents when their ward is marked Absent or Late.',
                  _enableNotifications,
                  (val) => setState(() => _enableNotifications = val),
                  theme,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Save Button
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: state.isSaving
                    ? null
                    : () {
                        final updated = state.settings.copyWith(
                          allowLate: _allowLate,
                          lateCutoffMinutes: _lateCutoffMinutes,
                          requireAbsentRemark: _requireAbsentRemark,
                          requireLateRemark: _requireLateRemark,
                          autoMarkApprovedLeave: _autoMarkApprovedLeave,
                          lockAfterHours: _lockAfterHours,
                          allowTeacherOverrideLocked: _allowTeacherOverride,
                          enableNotifications: _enableNotifications,
                        );
                        notifier.updateSettings(updated);
                      },
                icon: state.isSaving
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 16),
                label: Text(state.isSaving ? 'Saving...' : 'Save Configuration'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, ValueChanged<bool> onChanged, ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11)),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _buildSliderTile(String title, String subtitle, int value, ValueChanged<int> onChanged, ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11)),
            ],
          ),
        ),
        Container(
          width: 100,
          alignment: Alignment.centerRight,
          child: Text('$value min', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF4F46E5))),
        ),
      ],
    );
  }
}
