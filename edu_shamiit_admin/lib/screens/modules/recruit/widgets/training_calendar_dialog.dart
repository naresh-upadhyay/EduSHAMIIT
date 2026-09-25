import 'package:flutter/material.dart';
import 'package:edu_shamiit_core/services/api_service.dart';

class TrainingCalendarDialog extends StatefulWidget {
  final VoidCallback? onSessionChanged;

  const TrainingCalendarDialog({super.key, this.onSessionChanged});

  @override
  State<TrainingCalendarDialog> createState() => _TrainingCalendarDialogState();
}

class _TrainingCalendarDialogState extends State<TrainingCalendarDialog> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  List<dynamic> _sessions = [];
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  static const _monthShortNames = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
  ];

  @override
  void initState() {
    super.initState();
    _fetchSessions();
  }

  Future<void> _fetchSessions() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get('/training/sessions', useCache: false);
      if (res['success'] == true) {
        setState(() {
          _sessions = (res['data'] as List<dynamic>?) ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filteredSessions = _sessions.where((s) {
      final dateStr = s['session_date']?.toString();
      if (dateStr == null) return false;
      final d = DateTime.tryParse(dateStr.split('T').first);
      if (d == null) return false;
      return d.year == _currentMonth.year && d.month == _currentMonth.month;
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 820,
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
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.calendar_month_rounded, color: Color(0xFF4F46E5), size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Training Calendar & Timetable',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Outfit'),
                            ),
                            Text(
                              'Institutional workshops, induction sessions, and compliance schedules',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Month Navigation & Legend
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 10,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      tooltip: 'Previous Month',
                      onPressed: () {
                        setState(() {
                          _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
                        });
                      },
                    ),
                    Text(
                      '${_monthNames[_currentMonth.month - 1]} ${_currentMonth.year}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      tooltip: 'Next Month',
                      onPressed: () {
                        setState(() {
                          _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
                        });
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Today', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    _buildLegendItem('Scheduled', const Color(0xFF4F46E5)),
                    _buildLegendItem('In Progress', const Color(0xFF0284C7)),
                    _buildLegendItem('Completed', const Color(0xFF10B981)),
                    _buildLegendItem('Upcoming', const Color(0xFFF59E0B)),
                    _buildLegendItem('Holiday', const Color(0xFFEF4444)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Sessions List in Agenda format (Filtered by selected month)
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredSessions.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.event_busy_outlined, size: 40, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                Text(
                                  'No training sessions scheduled for ${_monthNames[_currentMonth.month - 1]} ${_currentMonth.year}.',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredSessions.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (ctx, i) {
                              final s = filteredSessions[i];
                            final title = s['session_title'] ?? 'Training Session';
                            final progTitle = s['program_title'] ?? '';
                            final trainer = s['trainer_name'] ?? 'Faculty Lead';
                            final date = (s['session_date'] ?? DateTime.now().toIso8601String().split('T').first).toString();
                            final parsedDate = DateTime.tryParse(date.split('T').first) ?? DateTime.now();
                            final dayStr = parsedDate.day.toString().padLeft(2, '0');
                            final monthStr = _monthShortNames[parsedDate.month - 1];
                            final time = '${s['start_time'] ?? '10:00'} - ${s['end_time'] ?? '12:00'}';
                            final mode = s['mode'] ?? 'Offline';
                            final location = s['location_or_link'] ?? 'Main Campus';
                            final stat = (s['status'] ?? 'Scheduled').toString();

                            Color statColor = const Color(0xFF4F46E5);
                            if (stat.toUpperCase() == 'COMPLETED') statColor = const Color(0xFF10B981);
                            if (stat.toUpperCase() == 'IN_PROGRESS') statColor = const Color(0xFF0284C7);
                            if (stat.toUpperCase() == 'UPCOMING') statColor = const Color(0xFFF59E0B);

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  // Date Box
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          dayStr,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF4F46E5),
                                          ),
                                        ),
                                        Text(monthStr, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$progTitle • Trainer: $trainer • Mode: $mode ($location)',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Timing & Status
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        time,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: statColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: statColor.withValues(alpha: 0.3)),
                                        ),
                                        child: Text(
                                          stat,
                                          style: TextStyle(
                                            color: statColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
