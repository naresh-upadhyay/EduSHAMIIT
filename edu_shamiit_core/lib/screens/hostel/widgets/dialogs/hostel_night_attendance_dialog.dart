import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/hostel_provider.dart';

class HostelNightAttendanceDialog extends ConsumerStatefulWidget {
  const HostelNightAttendanceDialog({super.key});

  @override
  ConsumerState<HostelNightAttendanceDialog> createState() => _HostelNightAttendanceDialogState();
}

class _HostelNightAttendanceDialogState extends ConsumerState<HostelNightAttendanceDialog> {
  String? _selectedBuildingId;
  String? _selectedFloorId;
  final DateTime _attendanceDate = DateTime.now();
  final TextEditingController _remarksController = TextEditingController();

  List<Map<String, dynamic>> _students = [];
  final Map<String, String> _statuses = {}; // student_id -> status
  final Map<String, String> _remarks = {}; // student_id -> remark
  bool _isLoadingRoster = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final tree = ref.read(hostelProvider).structureTree;
    if (tree.isNotEmpty) {
      _selectedBuildingId = tree.first.id;
      if (tree.first.floors.isNotEmpty) {
        _selectedFloorId = tree.first.floors.first.id;
      }
    }
    _loadRoster();
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _loadRoster() async {
    setState(() => _isLoadingRoster = true);
    try {
      final list = await ref.read(hostelProvider.notifier).service.getStudentsForNightRoster(
        buildingId: _selectedBuildingId,
        floorId: _selectedFloorId,
        academicYear: ref.read(hostelProvider).selectedAcademicYear,
      );
      if (mounted) {
        setState(() {
          _students = list;
          _statuses.clear();
          for (final s in list) {
            final sid = s['student_id']?.toString() ?? '';
            _statuses[sid] = s['default_status']?.toString() ?? 'PRESENT';
          }
          _isLoadingRoster = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingRoster = false);
      }
    }
  }

  void _setStatus(String studentId, String status) {
    setState(() {
      _statuses[studentId] = status;
    });
  }

  int get _presentCount => _statuses.values.where((s) => s == 'PRESENT').length;
  int get _absentCount => _statuses.values.where((s) => s == 'ABSENT').length;
  int get _leaveCount => _statuses.values.where((s) => s == 'APPROVED_LEAVE').length;
  int get _infirmaryCount => _statuses.values.where((s) => s == 'INFIRMARY').length;

  Future<void> _submitAttendance() async {
    if (_students.isEmpty) return;
    setState(() => _isSubmitting = true);
    final notifier = ref.read(hostelProvider.notifier);

    final records = _students.map((s) {
      final sid = s['student_id']?.toString() ?? '';
      return {
        'student_id': sid,
        'admission_id': s['admission_id'],
        'room_id': s['room_id'],
        'bed_id': s['bed_id'],
        'status': _statuses[sid] ?? 'PRESENT',
        'remarks': _remarks[sid] ?? '',
      };
    }).toList();

    final payload = {
      'building_id': _selectedBuildingId,
      'floor_id': _selectedFloorId,
      'attendance_date': _attendanceDate.toIso8601String().split('T')[0],
      'academic_year': ref.read(hostelProvider).selectedAcademicYear,
      'records': records,
      'remarks': _remarksController.text.trim(),
    };

    final navigator = Navigator.of(context);
    try {
      final res = await notifier.service.submitNightAttendance(payload);
      if (mounted) {
        if (res['success'] == true) {
          navigator.pop();
          notifier.showSuccess('Night roll-call submitted successfully! ($_presentCount Present, $_absentCount Absent)');
        } else {
          notifier.showError(res['message']?.toString() ?? 'Failed to submit night attendance');
        }
      }
    } catch (e) {
      if (mounted) {
        notifier.showError('Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hostelProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final buildings = state.structureTree;

    final currentBuilding = buildings.firstWhere(
      (b) => b.id == _selectedBuildingId,
      orElse: () => buildings.isNotEmpty ? buildings.first : state.structureTree.first,
    );
    final floors = currentBuilding.floors;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 820,
        height: 720,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bedtime_rounded, color: Color(0xFF6366F1), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Night Curfew & Roll-Call Attendance',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Bed-by-bed hostel verification with automated absent alert tracking',
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

            // Filter Strip (Building, Floor, Date)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AppSearchableDropdownFormField<String>.fromMenuItems(
                      initialValue: _selectedBuildingId,
                      decoration: const InputDecoration(labelText: 'Building', isDense: true, border: InputBorder.none),
                      items: buildings.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedBuildingId = val;
                          _selectedFloorId = null;
                        });
                        _loadRoster();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppSearchableDropdownFormField<String>.fromMenuItems(
                      initialValue: _selectedFloorId,
                      decoration: const InputDecoration(labelText: 'Floor', isDense: true, border: InputBorder.none),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Floors')),
                        ...floors.map((f) => DropdownMenuItem(value: f.id, child: Text(f.name))),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedFloorId = val);
                        _loadRoster();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _loadRoster,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Refresh'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Summary Badges
            Row(
              children: [
                _buildSummaryBadge('Total: ${_students.length}', const Color(0xFF3B82F6), isDark),
                const SizedBox(width: 8),
                _buildSummaryBadge('Present: $_presentCount', const Color(0xFF16A34A), isDark),
                const SizedBox(width: 8),
                _buildSummaryBadge('Absent: $_absentCount', const Color(0xFFDC2626), isDark),
                const SizedBox(width: 8),
                _buildSummaryBadge('On Leave: $_leaveCount', const Color(0xFFD97706), isDark),
                const SizedBox(width: 8),
                _buildSummaryBadge('Infirmary: $_infirmaryCount', const Color(0xFF8B5CF6), isDark),
              ],
            ),
            const SizedBox(height: 14),

            // Student Roster List
            Expanded(
              child: _isLoadingRoster
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
                  : _students.isEmpty
                      ? const Center(
                          child: Text('No active students found on selected floor/building'),
                        )
                      : ListView.separated(
                          itemCount: _students.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final s = _students[index];
                            final sid = s['student_id']?.toString() ?? '';
                            final currentStatus = _statuses[sid] ?? 'PRESENT';

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                              child: Row(
                                children: [
                                  // Bed & Room Badge
                                  Container(
                                    width: 80,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF334155) : const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          s['room_number'] ?? 'Room',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                        ),
                                        Text(
                                          s['bed_number'] ?? 'Bed',
                                          style: const TextStyle(fontSize: 10, color: Color(0xFF2563EB)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Avatar + Name + Roll
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.12),
                                    child: Text(
                                      (s['student_name']?.toString().isNotEmpty == true)
                                          ? s['student_name'][0].toUpperCase()
                                          : 'S',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          s['student_name'] ?? 'Student',
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                        ),
                                        Text(
                                          'Adm: ${s['admission_number'] ?? '-'}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Status Toggle Buttons
                                  _buildStatusToggle(sid, 'PRESENT', 'Present', const Color(0xFF16A34A), currentStatus),
                                  const SizedBox(width: 6),
                                  _buildStatusToggle(sid, 'ABSENT', 'Absent', const Color(0xFFDC2626), currentStatus),
                                  const SizedBox(width: 6),
                                  _buildStatusToggle(sid, 'APPROVED_LEAVE', 'On Leave', const Color(0xFFD97706), currentStatus),
                                  const SizedBox(width: 6),
                                  _buildStatusToggle(sid, 'INFIRMARY', 'Sick Bay', const Color(0xFF8B5CF6), currentStatus),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            const SizedBox(height: 14),

            // Footer / Submit Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _remarksController,
                    decoration: const InputDecoration(
                      labelText: 'General Roll-Call Remarks (Optional)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                TextButton(
                  onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _isSubmitting || _students.isEmpty ? null : _submitAttendance,
                  icon: _isSubmitting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: const Text('Submit Roll-Call'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
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

  Widget _buildSummaryBadge(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _buildStatusToggle(String studentId, String targetStatus, String label, Color color, String currentStatus) {
    final isSelected = currentStatus == targetStatus;
    return InkWell(
      onTap: () => _setStatus(studentId, targetStatus),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFCBD5E1),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}
