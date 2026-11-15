import 'package:flutter/material.dart';

class DeviceAlertsSubview extends StatelessWidget {
  final List<Map<String, dynamic>> alerts;
  final VoidCallback onBackToDashboard;
  final Function(String id) onResolveAlert;

  const DeviceAlertsSubview({
    super.key,
    required this.alerts,
    required this.onBackToDashboard,
    required this.onResolveAlert,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: onBackToDashboard,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Device Health & Active Alerts',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'Real-time anomaly detection, hardware faults, high power warnings, and offline alerts',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        Expanded(
          child: alerts.isEmpty
              ? Center(
                  child: Text(
                    'No active alerts! All systems operating normally.',
                    style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                )
              : ListView.separated(
                  itemCount: alerts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final al = alerts[index];
                    final id = al['id'].toString();
                    final title = al['title'] ?? 'Alert';
                    final desc = al['description'] ?? '';
                    final sev = al['severity']?.toString() ?? 'medium';
                    final isResolved = al['is_resolved'] == true;

                    Color sevColor = const Color(0xFFEAB308);
                    if (sev == 'critical' || sev == 'high') {
                      sevColor = const Color(0xFFDC2626);
                    } else if (sev == 'low') {
                      sevColor = const Color(0xFF0284C7);
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isResolved ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)) : sevColor.withValues(alpha: 0.4),
                          width: isResolved ? 1 : 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: sevColor, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      title,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: sevColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        sev.toUpperCase(),
                                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: sevColor),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  desc,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isResolved)
                            ElevatedButton(
                              onPressed: () => onResolveAlert(id),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF16A34A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                minimumSize: const Size(60, 30),
                              ),
                              child: const Text('Resolve', style: TextStyle(fontSize: 11)),
                            )
                          else
                            const Text('Resolved', style: TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
