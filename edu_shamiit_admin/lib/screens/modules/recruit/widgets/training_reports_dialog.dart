import 'package:flutter/material.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import '../../../../core/file_download_helper.dart';

class TrainingReportsDialog extends StatefulWidget {
  const TrainingReportsDialog({super.key});

  @override
  State<TrainingReportsDialog> createState() => _TrainingReportsDialogState();
}

class _TrainingReportsDialogState extends State<TrainingReportsDialog> {
  final ApiService _api = ApiService();
  String? _downloadingType;

  Future<void> _exportReport(String type) async {
    setState(() => _downloadingType = type);
    try {
      final res = await _api.getString('/training/reports/$type');
      if (mounted) {
        downloadFile(res, 'training_${type}_report_${DateTime.now().millisecondsSinceEpoch}.csv');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully downloaded $type report (${res.length} bytes).'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting report: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingType = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final reportTypes = [
      {
        'id': 'programs',
        'title': 'Training Programs Master Ledger',
        'subtitle': 'All courses, trainers, duration, enrollments, completion rates, and status.',
        'icon': Icons.table_chart_outlined,
        'color': const Color(0xFF4F46E5),
      },
      {
        'id': 'participants',
        'title': 'Participant Enrollment & Attendance',
        'subtitle': 'Detailed roster of employee enrollments, session attendance, and scores.',
        'icon': Icons.people_outline,
        'color': const Color(0xFF0284C7),
      },
      {
        'id': 'certificates',
        'title': 'Certificates & Expiry Registry',
        'subtitle': 'Verified digital credentials, issue dates, expiry periods, and validity status.',
        'icon': Icons.workspace_premium_outlined,
        'color': const Color(0xFF10B981),
      },
    ];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 640,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF13182C) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                        child: const Icon(Icons.analytics_outlined, color: Color(0xFF4F46E5), size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'HR Training & Learning Reports',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Outfit',
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Export institutional CSV audit data and participation analytics.',
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
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Report Cards
            ...reportTypes.map((r) {
              final id = r['id'] as String;
              final isExporting = _downloadingType == id;
              final color = r['color'] as Color;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(r['icon'] as IconData, color: color, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r['title'] as String,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            r['subtitle'] as String,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: isExporting ? null : () => _exportReport(id),
                      icon: isExporting
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.download_rounded, size: 14, color: Colors.white),
                      label: Text(
                        isExporting ? 'Exporting...' : 'Export CSV',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
