import 'package:flutter/material.dart';
import 'package:edu_shamiit_core/services/api_service.dart';

class RecordAttendanceDialog extends StatefulWidget {
  final String sessionId;
  final String sessionTitle;
  final String? sessionDate;
  final String? sessionTime;
  final VoidCallback onAttendanceSaved;

  const RecordAttendanceDialog({
    super.key,
    required this.sessionId,
    required this.sessionTitle,
    this.sessionDate,
    this.sessionTime,
    required this.onAttendanceSaved,
  });

  @override
  State<RecordAttendanceDialog> createState() => _RecordAttendanceDialogState();
}

class _RecordAttendanceDialogState extends State<RecordAttendanceDialog> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  bool _isSubmitting = false;

  List<dynamic> _roster = [];
  final Map<String, String> _statuses = {};
  final Map<String, TextEditingController> _remarksControllers = {};

  @override
  void initState() {
    super.initState();
    _fetchRoster();
  }

  @override
  void dispose() {
    for (var c in _remarksControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchRoster() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get('/training/sessions/${widget.sessionId}/attendance', useCache: false);
      if (res['success'] == true) {
        final data = (res['data'] as List<dynamic>?) ?? [];
        setState(() {
          _roster = data;
          for (var item in _roster) {
            final eid = item['enrollment_id'].toString();
            final currStat = (item['attendance_status'] ?? 'PENDING').toString().toUpperCase();
            _statuses[eid] = currStat == 'PENDING' ? 'PRESENT' : currStat;
            _remarksControllers[eid] = TextEditingController(text: item['remarks'] ?? '');
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _markAll(String status) {
    setState(() {
      for (var item in _roster) {
        final eid = item['enrollment_id'].toString();
        _statuses[eid] = status;
      }
    });
  }

  Future<void> _submitAttendance() async {
    setState(() => _isSubmitting = true);
    try {
      final records = _roster.map((item) {
        final eid = item['enrollment_id'].toString();
        return {
          'enrollment_id': eid,
          'attendance_status': _statuses[eid] ?? 'PRESENT',
          'remarks': _remarksControllers[eid]?.text.trim() ?? '',
        };
      }).toList();

      final res = await _api.post('/training/sessions/${widget.sessionId}/attendance', {'records': records});
      if (res['success'] == true) {
        widget.onAttendanceSaved();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Attendance records updated successfully!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving attendance: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 800,
        height: 640,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF13182C) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.how_to_reg_rounded, color: Color(0xFF10B981), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Record Session Attendance',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Outfit',
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${widget.sessionTitle} • ${widget.sessionDate ?? ''} ${widget.sessionTime ?? ''}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
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
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Bulk Quick Actions Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_roster.length} Participants Enrolled',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _markAll('PRESENT'),
                          icon: const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF10B981)),
                          label: const Text('Mark All Present', style: TextStyle(fontSize: 12, color: Color(0xFF10B981))),
                          style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _markAll('ABSENT'),
                          icon: const Icon(Icons.cancel_outlined, size: 14, color: Color(0xFFEF4444)),
                          label: const Text('Mark All Absent', style: TextStyle(fontSize: 12, color: Color(0xFFEF4444))),
                          style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),

            // Roster Table / List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _roster.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.people_outline, size: 40, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              const Text('No participants assigned to this training yet.', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _roster.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final item = _roster[i];
                            final eid = item['enrollment_id'].toString();
                            final name = item['employee_name'] ?? 'Staff Member';
                            final code = item['employee_code'] ?? 'Emp--';
                            final dept = item['department'] ?? 'Academics';
                            final currentStat = _statuses[eid] ?? 'PRESENT';

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                    child: Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : 'E',
                                      style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                        Text('$code • $dept', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                      ],
                                    ),
                                  ),
                                  // Status Buttons (Present, Absent, Late, Excused)
                                  Wrap(
                                    spacing: 4,
                                    children: [
                                      _buildStatusChip(eid, 'PRESENT', 'Present', const Color(0xFF10B981), currentStat),
                                      _buildStatusChip(eid, 'ABSENT', 'Absent', const Color(0xFFEF4444), currentStat),
                                      _buildStatusChip(eid, 'LATE', 'Late', const Color(0xFFF59E0B), currentStat),
                                      _buildStatusChip(eid, 'EXCUSED', 'Excused', const Color(0xFF6B7280), currentStat),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  // Remarks Field
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: _remarksControllers[eid],
                                      decoration: const InputDecoration(
                                        hintText: 'Remarks / note...',
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        border: OutlineInputBorder(),
                                      ),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),

            // Actions Footer
            const Divider(height: 1),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isSubmitting || _roster.isEmpty ? null : _submitAttendance,
                  icon: _isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                  label: const Text('Save Attendance', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String enrollmentId, String statusValue, String label, Color color, String currentStatus) {
    final isSelected = currentStatus == statusValue;
    return InkWell(
      onTap: () => setState(() => _statuses[enrollmentId] = statusValue),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? color : color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}
