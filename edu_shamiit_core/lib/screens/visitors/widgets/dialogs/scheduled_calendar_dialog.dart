import 'package:flutter/material.dart';
import '../../models/visitor_models.dart';

class ScheduledCalendarDialog extends StatefulWidget {
  final List<ScheduledAppointmentItem> appointments;
  final Function(ScheduledAppointmentItem)? onSelectAppointment;

  const ScheduledCalendarDialog({
    super.key,
    required this.appointments,
    this.onSelectAppointment,
  });

  @override
  State<ScheduledCalendarDialog> createState() => _ScheduledCalendarDialogState();
}

class _ScheduledCalendarDialogState extends State<ScheduledCalendarDialog> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isNarrow = screenWidth < 700;
    final dialogWidth = isNarrow ? screenWidth * 0.95 : 780.0;
    final dialogHeight = screenHeight < 650 ? screenHeight * 0.90 : 600.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: EdgeInsets.symmetric(horizontal: isNarrow ? 8 : 24, vertical: 16),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        padding: EdgeInsets.all(isNarrow ? 14 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.calendar_month_rounded, color: Color(0xFF2563EB), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scheduled Visitors Calendar',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Upcoming visitor appointments by date and location',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Appointments Agenda List
            Expanded(
              child: widget.appointments.isEmpty
                  ? const Center(child: Text('No scheduled appointments to display.'))
                  : ListView.separated(
                      itemCount: widget.appointments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final a = widget.appointments[idx];
                        final isBlocked = a.status.toLowerCase() == 'blocked' || a.status.toLowerCase() == 'blacklisted';
                        final isConfirmed = a.status.toLowerCase() == 'confirmed' || a.status.toLowerCase() == 'approved';
                        return InkWell(
                          onTap: () {
                            Navigator.of(context).pop();
                            widget.onSelectAppointment?.call(a);
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 85,
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        a.scheduledDate,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        a.scheduledStartAt.isNotEmpty ? a.scheduledStartAt : '10:00 AM',
                                        style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        a.visitorName,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 4,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.person_pin, size: 14, color: Color(0xFF64748B)),
                                              const SizedBox(width: 4),
                                              Text('Host: ${a.hostName}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                            ],
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.place_outlined, size: 14, color: Color(0xFF64748B)),
                                              const SizedBox(width: 4),
                                              Text(a.location, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isBlocked
                                        ? const Color(0xFFFEE2E2)
                                        : (isConfirmed ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7)),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    isBlocked ? 'Blocked' : (isConfirmed ? 'Confirmed' : 'Pending'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isBlocked
                                          ? const Color(0xFFDC2626)
                                          : (isConfirmed ? const Color(0xFF15803D) : const Color(0xFFD97706)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Icon(Icons.chevron_right, size: 20, color: Color(0xFF94A3B8)),
                              ],
                            ),
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
}
