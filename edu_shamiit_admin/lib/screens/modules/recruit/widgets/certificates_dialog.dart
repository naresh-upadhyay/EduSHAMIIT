import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import 'package:edu_shamiit_core/config/app_config.dart';
import 'package:edu_shamiit_admin/core/file_download_helper.dart';

class CertificatesDialog extends StatefulWidget {
  final VoidCallback? onCertificateChanged;

  const CertificatesDialog({super.key, this.onCertificateChanged});

  @override
  State<CertificatesDialog> createState() => _CertificatesDialogState();
}

class _CertificatesDialogState extends State<CertificatesDialog> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  List<dynamic> _certificates = [];
  String _selectedTab = 'ALL';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchCertificates();
  }

  Future<void> _fetchCertificates() async {
    setState(() => _isLoading = true);
    try {
      final params = <String>[];
      if (_selectedTab != 'ALL') params.add('status=$_selectedTab');
      if (_searchQuery.isNotEmpty) params.add('search=$_searchQuery');
      final qStr = params.isNotEmpty ? '?${params.join('&')}' : '';

      final res = await _api.get('/training/certificates$qStr', useCache: false);
      if (res['success'] == true) {
        setState(() {
          _certificates = (res['data'] as List<dynamic>?) ?? [];
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadCertificatePdf(Map<String, dynamic> c) async {
    final cid = c['id'].toString();
    final certNo = c['certificate_number'] ?? 'CERT';
    final empName = c['employee_name'] ?? 'Staff';
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(
      SnackBar(content: Text('Downloading official certificate PDF for $empName...'), duration: const Duration(seconds: 1)),
    );

    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/training/certificates/$cid/pdf');
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? prefs.getString('token');
      final schoolId = prefs.getString('school_id') ?? prefs.getString('current_school_id');
      final headers = <String, String>{};
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
      if (schoolId != null && schoolId.isNotEmpty) headers['X-School-Id'] = schoolId;

      final res = await http.get(uri, headers: headers);
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        final safeName = empName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
        final fileName = 'Certificate_${certNo}_$safeName.pdf';
        downloadBytes(res.bodyBytes, fileName, mimeType: 'application/pdf');
        messenger.showSnackBar(
          SnackBar(content: Text('Downloaded certificate PDF: $fileName!'), backgroundColor: const Color(0xFF10B981)),
        );
      } else {
        throw Exception('Server returned status ${res.statusCode}');
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error downloading certificate: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _revokeCertificate(String id, String certNo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke Certificate'),
        content: Text('Are you sure you want to revoke certificate $certNo? This will mark the certificate as EXPIRED.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Revoke', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await _api.post('/training/certificates/$id/revoke', {});
      if (res['success'] == true) {
        _fetchCertificates();
        widget.onCertificateChanged?.call();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Certificate revoked successfully.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (screenWidth * 0.85).clamp(960.0, 1100.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: dialogWidth,
        height: 680,
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
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.workspace_premium_outlined, color: Color(0xFFF59E0B), size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Certificates & Expiring Certifications',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Outfit',
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Verified digital certificates issued for completed training programs.',
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
            const SizedBox(height: 12),

            // Controls Bar
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'ALL', label: Text('All')),
                    ButtonSegment(value: 'VALID', label: Text('Valid')),
                    ButtonSegment(value: 'EXPIRING_SOON', label: Text('Expiring Soon')),
                    ButtonSegment(value: 'EXPIRED', label: Text('Expired / Revoked')),
                  ],
                  selected: {_selectedTab},
                  onSelectionChanged: (val) {
                    setState(() => _selectedTab = val.first);
                    _fetchCertificates();
                  },
                ),
                SizedBox(
                  width: 260,
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search certificate # or name...',
                      prefixIcon: Icon(Icons.search_rounded, size: 18),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      _searchQuery = v.trim();
                      _fetchCertificates();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Certificates Table
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _certificates.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.workspace_premium_outlined, size: 40, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              const Text('No certificates found matching the filter.', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(
                                    isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                  ),
                                  headingRowHeight: 42,
                                  dataRowMinHeight: 50,
                                  dataRowMaxHeight: 56,
                                  columnSpacing: 16,
                                  horizontalMargin: 16,
                                  columns: const [
                                    DataColumn(label: SizedBox(width: 150, child: Text('Certificate #', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                                    DataColumn(label: SizedBox(width: 140, child: Text('Employee', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                                    DataColumn(label: SizedBox(width: 220, child: Text('Training Course', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                                    DataColumn(label: SizedBox(width: 100, child: Text('Issue Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                                    DataColumn(label: SizedBox(width: 100, child: Text('Expiry Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                                    DataColumn(label: SizedBox(width: 110, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                                    DataColumn(label: SizedBox(width: 90, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                                  ],
                                  rows: _certificates.map((c) {
                                    final certNo = c['certificate_number'] ?? 'CERT-TRN';
                                    final empName = c['employee_name'] ?? 'Staff Member';
                                    final progTitle = c['program_title'] ?? 'Training';
                                    final issueDate = c['issue_date'] ?? '-';
                                    final expiryDate = c['expiry_date'] ?? 'Permanent';
                                    final stat = (c['status'] ?? 'VALID').toString().toUpperCase();

                                    Color badgeColor = const Color(0xFF10B981);
                                    if (stat == 'EXPIRING_SOON') badgeColor = const Color(0xFFF59E0B);
                                    if (stat == 'EXPIRED' || stat == 'REVOKED') badgeColor = const Color(0xFFEF4444);

                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          SizedBox(
                                            width: 150,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.verified_outlined, size: 16, color: Color(0xFF4F46E5)),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    certNo,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 140,
                                            child: Text(
                                              empName,
                                              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 220,
                                            child: Text(
                                              progTitle,
                                              style: const TextStyle(fontSize: 12),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 100,
                                            child: Text(issueDate, style: const TextStyle(fontSize: 12)),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 100,
                                            child: Text(expiryDate, style: const TextStyle(fontSize: 12)),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 110,
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: badgeColor.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                                                ),
                                                child: Text(
                                                  stat.replaceAll('_', ' '),
                                                  style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 11),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 90,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.download_rounded, size: 18),
                                                  tooltip: 'Download Official PDF',
                                                  onPressed: () => _downloadCertificatePdf(c),
                                                ),
                                                if (stat == 'VALID')
                                                  IconButton(
                                                    icon: const Icon(Icons.block_rounded, size: 18, color: Colors.red),
                                                    tooltip: 'Revoke Certificate',
                                                    onPressed: () => _revokeCertificate(c['id'].toString(), certNo),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
