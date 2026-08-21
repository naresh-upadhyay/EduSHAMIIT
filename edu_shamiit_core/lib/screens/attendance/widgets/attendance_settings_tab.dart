import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../constants/app_fonts.dart';
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
    final isDark = theme.brightness == Brightness.dark;

    if (!_initialized) {
      _syncFromState(state.settings);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attendance System Rules & Configuration',
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Configure school-wide attendance rules, late cutoff thresholds, lock durations, and automated parent notifications.',
            style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12),
          ),
          const SizedBox(height: 20),

          // Settings Container
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(14),
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
              children: [
                _buildSwitchTile(
                  'Allow Late Attendance Marking',
                  'Permits marking students and staff as Late entries after session start time.',
                  _allowLate,
                  (val) => setState(() => _allowLate = val),
                  isDark,
                ),
                Divider(height: 24, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                _buildSliderTile(
                  'Late Entry Cutoff: $_lateCutoffMinutes Minutes',
                  'Grace period in minutes after schedule start time when attendance can be marked as Late.',
                  _lateCutoffMinutes,
                  (val) => setState(() => _lateCutoffMinutes = val),
                  isDark,
                ),
                Divider(height: 24, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                _buildSwitchTile(
                  'Require Remark for Absent Students',
                  'Mandates a justification or reason note when marking any student Absent.',
                  _requireAbsentRemark,
                  (val) => setState(() => _requireAbsentRemark = val),
                  isDark,
                ),
                Divider(height: 24, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                _buildSwitchTile(
                  'Require Remark for Late Entries',
                  'Mandates a reason note when marking a student or staff member Late.',
                  _requireLateRemark,
                  (val) => setState(() => _requireLateRemark = val),
                  isDark,
                ),
                Divider(height: 24, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                _buildSwitchTile(
                  'Auto-Mark Approved Leave',
                  'Approved leave applications are automatically synchronized into daily attendance rosters as On Leave (O).',
                  _autoMarkApprovedLeave,
                  (val) => setState(() => _autoMarkApprovedLeave = val),
                  isDark,
                ),
                Divider(height: 24, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                _buildSwitchTile(
                  'Allow Teachers to Override Locked Records',
                  'If disabled, only Super Admins, Directors, and Principals can override locked attendance.',
                  _allowTeacherOverride,
                  (val) => setState(() => _allowTeacherOverride = val),
                  isDark,
                ),
                Divider(height: 24, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                _buildSwitchTile(
                  'Enable Automated Notifications to Parents',
                  'Send immediate SMS / WhatsApp / Push alerts to parents when their child is marked Absent or Late.',
                  _enableNotifications,
                  (val) => setState(() => _enableNotifications = val),
                  isDark,
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
                label: Text(state.isSaving ? 'Saving...' : 'Save Settings', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
    bool isDark,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF4F46E5),
        ),
      ],
    );
  }

  Widget _buildSliderTile(
    String title,
    String subtitle,
    int value,
    ValueChanged<int> onChanged,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$value mins',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF4F46E5)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        ),
        Slider(
          value: value.toDouble(),
          min: 5,
          max: 60,
          divisions: 11,
          label: '$value mins',
          activeColor: const Color(0xFF4F46E5),
          onChanged: (val) => onChanged(val.round()),
        ),
      ],
    );
  }
}
