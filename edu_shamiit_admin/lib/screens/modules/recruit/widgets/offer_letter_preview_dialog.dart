import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edu_shamiit_core/config/app_config.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import 'package:edu_shamiit_admin/core/file_download_helper.dart';

class OfferLetterPreviewDialog extends StatefulWidget {
  final Map<String, dynamic> offer;
  final String candidateName;
  final String candidateEmail;
  final String? applicationReference;
  final VoidCallback onOfferUpdated;

  const OfferLetterPreviewDialog({
    super.key,
    required this.offer,
    required this.candidateName,
    required this.candidateEmail,
    this.applicationReference,
    required this.onOfferUpdated,
  });

  @override
  State<OfferLetterPreviewDialog> createState() => _OfferLetterPreviewDialogState();
}

class _OfferLetterPreviewDialogState extends State<OfferLetterPreviewDialog> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  bool _isDownloadingPdf = false;

  Future<void> _downloadPdf() async {
    setState(() => _isDownloadingPdf = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/recruitment/offers/${widget.offer['id']}/pdf');

      final res = await http.get(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        final safeName = widget.candidateName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
        final fileName = 'Offer_Letter_$safeName.pdf';
        downloadBytes(res.bodyBytes, fileName, mimeType: 'application/pdf');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Offer letter PDF ($fileName) downloaded successfully!'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      } else {
        throw Exception('Failed to generate offer letter PDF (status: ${res.statusCode})');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download PDF: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloadingPdf = false);
    }
  }

  Future<void> _sendOffer() async {
    setState(() => _isLoading = true);
    try {
      await _apiService.post('/recruitment/offers/${widget.offer['id']}/send', {});
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Formal job offer letter successfully sent to ${widget.candidateEmail}!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        widget.onOfferUpdated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptOffer() async {
    setState(() => _isLoading = true);
    try {
      await _apiService.post('/recruitment/offers/${widget.offer['id']}/accept', {});
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Offer marked as Accepted! Candidate is ready to be Hired.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        widget.onOfferUpdated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _rejectOfferDialog() async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Mark Offer as Declined'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter the reason provided by candidate for declining the offer:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'e.g. Accepted competing offer, relocation constraints...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(c).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Confirm Decline', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _apiService.post('/recruitment/offers/${widget.offer['id']}/reject', {
          'reason': reasonController.text.trim(),
        });
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Offer has been marked as Declined/Rejected.'),
              backgroundColor: Color(0xFF64748B),
            ),
          );
          widget.onOfferUpdated();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444)),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _copyOfferText() {
    final off = widget.offer;
    final salary = double.tryParse(off['salary']?.toString() ?? '0') ?? 0.0;
    final annualCtc = salary * 12;
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    final buffer = StringBuffer();
    buffer.writeln('====================================================');
    buffer.writeln('           EDUSHAMIIT ACADEMY OF EXCELLENCE         ');
    buffer.writeln('              LETTER OF EMPLOYMENT OFFER            ');
    buffer.writeln('====================================================\n');
    buffer.writeln('Date: ${DateFormat('dd MMMM yyyy').format(DateTime.now())}');
    buffer.writeln('Reference: ${widget.applicationReference ?? 'EDU-REC-2026'}\n');
    buffer.writeln('To: ${widget.candidateName}');
    buffer.writeln('Email: ${widget.candidateEmail}\n');
    buffer.writeln('Dear ${widget.candidateName},\n');
    buffer.writeln('We are pleased to offer you the position of ${off['job_title'] ?? 'Staff Member'} at EduSHAMIIT.');
    buffer.writeln('Terms of Employment:');
    buffer.writeln(' - Position: ${off['job_title'] ?? 'Staff Member'}');
    buffer.writeln(' - Employment Type: ${off['employment_type'] ?? 'Full-time'}');
    buffer.writeln(' - Monthly Gross: ${formatter.format(salary)}');
    buffer.writeln(' - Annual CTC: ${formatter.format(annualCtc)}');
    buffer.writeln(' - Expected Joining: ${off['joining_date']}');
    buffer.writeln(' - Probation Duration: ${off['probation_period_months'] ?? 6} Months');
    if (off['benefits'] != null) buffer.writeln(' - Benefits: ${off['benefits']}');
    if (off['terms'] != null) buffer.writeln(' - Terms: ${off['terms']}');
    if (off['offer_expiry_date'] != null) buffer.writeln(' - Offer Validity: ${off['offer_expiry_date']}');
    buffer.writeln('\nAuthorized Signatory');
    buffer.writeln('EduSHAMIIT Human Resources Directorate');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Offer letter text copied to clipboard!'),
        backgroundColor: Color(0xFF4F46E5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final off = widget.offer;
    final status = off['status'] ?? 'Draft';
    final salary = double.tryParse(off['salary']?.toString() ?? '0') ?? 0.0;
    final annualCtc = salary * 12;
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    Color statusColor;
    if (status == 'Accepted') {
      statusColor = const Color(0xFF10B981);
    } else if (status == 'Sent') {
      statusColor = const Color(0xFF3B82F6);
    } else if (status == 'Rejected') {
      statusColor = const Color(0xFFEF4444);
    } else {
      statusColor = const Color(0xFFF59E0B);
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 720,
        constraints: const BoxConstraints(maxHeight: 780),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.description_outlined, color: statusColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Formal Employment Offer Letter',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Candidate: ${widget.candidateName} • ${widget.candidateEmail}',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Offer Letter Preview Sheet
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Letterhead
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.school_rounded, color: Colors.white, size: 24),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'EduSHAMIIT ACADEMY',
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                      ),
                                      Text(
                                        'Human Resources & Faculty Development Directorate',
                                        style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'REF: ${widget.applicationReference ?? "EDU-REC-2026"}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                              ),
                              Text(
                                DateFormat('dd MMMM yyyy').format(DateTime.now()),
                                style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Divider(),
                      const SizedBox(height: 14),

                      // Addressee
                      Text('To,', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : const Color(0xFF64748B))),
                      Text(widget.candidateName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(widget.candidateEmail, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      const SizedBox(height: 16),

                      // Subject Line
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'SUB: FORMAL APPOINTMENT OFFER - ${off['job_title'] ?? "POSITION"}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF4F46E5)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Salutation & Intro
                      Text(
                        'Dear ${widget.candidateName},',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Following your successful evaluations and discussions throughout our recruitment process, we are exceptionally delighted to extend this formal offer of employment for the position of ${off['job_title'] ?? "Staff Member"} at EduSHAMIIT.',
                        style: const TextStyle(fontSize: 12, height: 1.5),
                      ),
                      const SizedBox(height: 16),

                      // Remuneration & Terms Breakdown Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SUMMARY OF COMPENSATION & TERMS',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Monthly Compensation', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                      const SizedBox(height: 2),
                                      Text(
                                        formatter.format(salary),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF10B981)),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Annual CTC (Calculated)', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                      const SizedBox(height: 2),
                                      Text(
                                        formatter.format(annualCtc),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF4F46E5)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Text('Expected Joining Date: ${off['joining_date']}', style: const TextStyle(fontSize: 12)),
                                ),
                                Expanded(
                                  child: Text('Probation Period: ${off['probation_period_months'] ?? 6} Months', style: const TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: Text('Employment Type: ${off['employment_type'] ?? "Full-time"}', style: const TextStyle(fontSize: 12)),
                                ),
                                if (off['offer_expiry_date'] != null)
                                  Expanded(
                                    child: Text(
                                      'Valid Until: ${off['offer_expiry_date']}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                                    ),
                                  ),
                              ],
                            ),
                            if (off['benefits'] != null && off['benefits'].toString().trim().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text('Covered Benefits: ${off['benefits']}', style: const TextStyle(fontSize: 12, color: Color(0xFF059669))),
                            ],
                            if (off['terms'] != null && off['terms'].toString().trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text('Terms & Conditions: ${off['terms']}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Signoff
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Sincerely,', style: TextStyle(fontSize: 12)),
                              const SizedBox(height: 8),
                              const Text('Directorate of Human Resources', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              Text('EduSHAMIIT ERP System', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : const Color(0xFF64748B))),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 20),
                                SizedBox(height: 2),
                                Text('Digitally Certified', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Action Toolbar
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _copyOfferText,
                      icon: const Icon(Icons.copy_rounded, size: 14),
                      label: const Text('Copy Letter Text', style: TextStyle(fontSize: 12)),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isDownloadingPdf ? null : _downloadPdf,
                      icon: _isDownloadingPdf
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.picture_as_pdf_rounded, size: 14),
                      label: const Text('Download PDF', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    if (status == 'Draft') ...[
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _sendOffer,
                        icon: _isLoading
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.send_rounded, size: 14),
                        label: const Text('Send to Candidate via Email'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ] else if (status == 'Sent') ...[
                      OutlinedButton.icon(
                        onPressed: _isLoading ? null : _rejectOfferDialog,
                        icon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFFEF4444)),
                        label: const Text('Mark Declined', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _acceptOffer,
                        icon: _isLoading
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check_rounded, size: 14),
                        label: const Text('Mark Candidate Accepted'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ] else if (status == 'Accepted') ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Offer Accepted by Candidate',
                              style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
