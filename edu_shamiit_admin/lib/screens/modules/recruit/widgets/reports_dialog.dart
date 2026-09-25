import 'package:flutter/material.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import '../../../../core/file_download_helper.dart';

class ReportsDialog extends StatefulWidget {
  const ReportsDialog({super.key});

  @override
  State<ReportsDialog> createState() => _ReportsDialogState();
}

class _ReportsDialogState extends State<ReportsDialog> {
  final ApiService _api = ApiService();

  String _selectedReport = 'policies';
  bool _isLoadingPreview = false;
  String? _csvPreview;

  final List<Map<String, String>> _reports = [
    {
      'id': 'policies',
      'title': 'Policy Register',
      'desc': 'Complete list of institutional policies, current version, review frequency and owner.'
    },
    {
      'id': 'documents',
      'title': 'Document Register',
      'desc': 'All uploaded HR documents, access permissions, department allocation and file size.'
    },
    {
      'id': 'expiring',
      'title': 'Expiring Documents Report',
      'desc': 'Documents due to expire or up for statutory compliance review within 90 days.'
    },
    {
      'id': 'compliance',
      'title': 'Acknowledgement Compliance Report',
      'desc': 'Employee sign-off completion metrics, pending acknowledgements and overdue staff list.'
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    setState(() {
      _isLoadingPreview = true;
      _csvPreview = null;
    });

    try {
      final csv = await _api.getString('/hr/reports/$_selectedReport');
      setState(() {
        _csvPreview = csv;
        _isLoadingPreview = false;
      });
    } catch (e) {
      setState(() {
        _csvPreview = 'Error loading report preview: $e';
        _isLoadingPreview = false;
      });
    }
  }

  Future<void> _downloadReport() async {
    try {
      final res = await _api.getString('/hr/reports/$_selectedReport');
      if (mounted) {
        downloadFile(res, 'hr_${_selectedReport}_report_${DateTime.now().millisecondsSinceEpoch}.csv');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report exported successfully (${res.length} bytes downloaded).'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download report: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 840,
        height: 660,
        padding: const EdgeInsets.all(28),
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
                        child: const Icon(Icons.assessment_outlined, color: Color(0xFF4F46E5), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'HR Compliance & Document Reports',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Export institutional compliance records, policy registers and audit registries.',
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
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const Divider(height: 24),
            Expanded(
              child: Row(
                children: [
                  // Left: Report Picker
                  Expanded(
                    flex: 4,
                    child: ListView.separated(
                      itemCount: _reports.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final r = _reports[index];
                        final isSelected = _selectedReport == r['id'];

                        return InkWell(
                          onTap: () {
                            setState(() => _selectedReport = r['id']!);
                            _loadPreview();
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF4F46E5).withValues(alpha: 0.08)
                                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF4F46E5)
                                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.table_chart_outlined,
                                      size: 16,
                                      color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        r['title']!,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isSelected ? const Color(0xFF4F46E5) : null,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  r['desc']!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  const VerticalDivider(width: 1),
                  const SizedBox(width: 16),
                  // Right: Live CSV Preview & Download
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text('Report Data Preview (First 50 Rows)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _downloadReport,
                              icon: const Icon(Icons.download_rounded, size: 14, color: Colors.white),
                              label: const Text('Export CSV', style: TextStyle(color: Colors.white, fontSize: 12)),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: _isLoadingPreview
                              ? const Center(child: CircularProgressIndicator())
                              : Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                  ),
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: SingleChildScrollView(
                                      child: SelectableText(
                                        _csvPreview ?? 'No preview data available.',
                                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.5),
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
