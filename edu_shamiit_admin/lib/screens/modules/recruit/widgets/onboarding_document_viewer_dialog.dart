import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:edu_shamiit_core/config/app_config.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingDocumentViewerDialog extends StatefulWidget {
  final Map<String, dynamic> document;
  final VoidCallback onDocumentUpdated;

  const OnboardingDocumentViewerDialog({
    super.key,
    required this.document,
    required this.onDocumentUpdated,
  });

  @override
  State<OnboardingDocumentViewerDialog> createState() => _OnboardingDocumentViewerDialogState();
}

class _OnboardingDocumentViewerDialogState extends State<OnboardingDocumentViewerDialog> {
  final ApiService _api = ApiService();

  late Map<String, dynamic> _doc;
  bool _isLoading = false;
  bool _isUploading = false;

  // File picker state
  Uint8List? _pickedBytes;
  String? _pickedFileName;
  int _pickedFileSize = 0;
  bool _autoVerify = true;
  final TextEditingController _remarksController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _doc = Map<String, dynamic>.from(widget.document);
    _fetchLatestDoc();
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _fetchLatestDoc() async {
    final docId = _doc['id'];
    if (docId == null) return;
    try {
      final res = await _api.get('/onboarding/documents/$docId', useCache: false);
      if (res['success'] == true && res['data'] != null) {
        if (mounted) {
          setState(() {
            _doc = res['data'] as Map<String, dynamic>;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _pickedFileName = file.name;
          _pickedBytes = file.bytes;
          _pickedFileSize = file.size;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting file: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  Future<void> _uploadDocument() async {
    final docId = _doc['id']?.toString();
    if (docId == null) return;

    if (_pickedBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a file to upload first.'),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final schoolId = prefs.getString('school_id') ?? '11111111-1111-1111-1111-111111111111';

      final uri = Uri.parse('${AppConfig.apiBaseUrl}/onboarding/documents/$docId/upload');
      final request = http.MultipartRequest('POST', uri);

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.headers['x-school-id'] = schoolId;

      request.fields['remarks'] = _remarksController.text.trim();
      request.fields['auto_verify'] = _autoVerify ? 'true' : 'false';

      if (_pickedBytes != null && _pickedFileName != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            _pickedBytes!,
            filename: _pickedFileName!,
          ),
        );
      } else {
        request.fields['file_name'] = '${_doc['document_name'] ?? 'document'}.pdf';
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Document successfully uploaded${_autoVerify ? ' and verified' : ''}!'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
          widget.onDocumentUpdated();
          await _fetchLatestDoc();
          setState(() {
            _pickedBytes = null;
            _pickedFileName = null;
            _isUploading = false;
          });
        }
      } else {
        throw Exception('Server returned ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  Future<void> _verifyDocument() async {
    final docId = _doc['id']?.toString();
    if (docId == null) return;

    setState(() => _isLoading = true);
    try {
      final res = await _api.post('/onboarding/documents/$docId/verify', {
        'remarks': 'Verified by HR',
      });
      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document verified and approved!'), backgroundColor: Color(0xFF10B981)),
          );
          widget.onDocumentUpdated();
          await _fetchLatestDoc();
          setState(() => _isLoading = false);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification failed: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  Future<void> _rejectDocument() async {
    final docId = _doc['id']?.toString();
    if (docId == null) return;

    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Document'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please specify the reason for rejection:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g. Incomplete details, signature missing, blurry scan',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            child: const Text('Reject Document'),
          ),
        ],
      ),
    );

    if (confirm != true || reasonController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final res = await _api.post('/onboarding/documents/$docId/reject', {
        'reason': reasonController.text.trim(),
      });
      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document has been rejected.'), backgroundColor: Color(0xFFEF4444)),
          );
          widget.onDocumentUpdated();
          await _fetchLatestDoc();
          setState(() => _isLoading = false);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rejection failed: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  Future<void> _openDocumentDownload() async {
    final docId = _doc['id']?.toString();
    if (docId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final schoolId = prefs.getString('school_id') ?? '11111111-1111-1111-1111-111111111111';

      final downloadUrl = Uri.parse(
        '${AppConfig.apiBaseUrl}/onboarding/documents/$docId/download?token=$token&school_id=$schoolId',
      );

      if (await canLaunchUrl(downloadUrl)) {
        await launchUrl(downloadUrl, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open document viewer.'), backgroundColor: Color(0xFFEF4444)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening document: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final docName = _doc['document_name'] ?? 'Document';
    final candidateName = _doc['candidate_name'] ?? 'Candidate';
    final onboardingCode = _doc['onboarding_code'] ?? 'EMP';
    final department = _doc['department'] ?? 'General';
    final status = _doc['status'] ?? 'Pending';
    final isMandatory = _doc['is_mandatory'] == true;
    final isVerified = status == 'Verified';
    final isRejected = status == 'Rejected';
    final isUploaded = status == 'Uploaded';

    final fileName = _doc['file_name'] ?? '$docName.pdf';
    final uploadedAt = _doc['uploaded_at'];
    final verifiedBy = _doc['verified_by_name'];
    final rejectionReason = _doc['rejection_reason'];
    final remarks = _doc['remarks'];

    Color statusBg;
    Color statusFg;
    if (isVerified) {
      statusBg = const Color(0xFF10B981).withValues(alpha: 0.12);
      statusFg = const Color(0xFF10B981);
    } else if (isRejected) {
      statusBg = const Color(0xFFEF4444).withValues(alpha: 0.12);
      statusFg = const Color(0xFFEF4444);
    } else if (isUploaded) {
      statusBg = const Color(0xFF3B82F6).withValues(alpha: 0.12);
      statusFg = const Color(0xFF3B82F6);
    } else {
      statusBg = const Color(0xFFF59E0B).withValues(alpha: 0.12);
      statusFg = const Color(0xFFF59E0B);
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 820,
        constraints: const BoxConstraints(maxHeight: 780),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF13182C) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.description_outlined, color: Color(0xFF4F46E5), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                docName,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Outfit',
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isMandatory ? const Color(0xFFEF4444).withValues(alpha: 0.1) : const Color(0xFF64748B).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isMandatory ? 'Mandatory' : 'Optional',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isMandatory ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(4)),
                              child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusFg)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$candidateName ($onboardingCode) • Department: $department',
                          style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Document Preview & File Status Section
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  fileName.toLowerCase().endsWith('.pdf')
                                      ? Icons.picture_as_pdf_outlined
                                      : Icons.insert_drive_file_outlined,
                                  color: const Color(0xFF4F46E5),
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fileName,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      uploadedAt != null
                                          ? 'Uploaded on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(uploadedAt.toString()))}'
                                          : (status == 'Pending' ? 'No document file uploaded yet' : 'Uploaded by HR'),
                                      style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                              if (status != 'Pending') ...[
                                ElevatedButton.icon(
                                  onPressed: _openDocumentDownload,
                                  icon: const Icon(Icons.open_in_new_rounded, size: 15),
                                  label: const Text('View / Preview'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4F46E5),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: _openDocumentDownload,
                                  icon: const Icon(Icons.download_rounded, size: 15),
                                  label: const Text('Download'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ],
                            ],
                          ),

                          if (status == 'Pending') ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, size: 18, color: Color(0xFFF59E0B)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'This document has not been uploaded by the candidate yet. HR can obtain the document directly from the candidate and upload it below to verify compliance.',
                                      style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          if (rejectionReason != null && rejectionReason.toString().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Rejection Reason:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                                        const SizedBox(height: 2),
                                        Text('$rejectionReason', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B))),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          if (verifiedBy != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Verified by $verifiedBy on ${_doc['verified_at'] != null ? DateFormat('dd MMM yyyy').format(DateTime.parse(_doc['verified_at'].toString())) : 'Compliance Check'}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                            ),
                          ],
                          if (remarks != null && remarks.toString().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Remarks: $remarks',
                              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // HR Upload & Replace Section
                    Text(
                      status == 'Pending' ? 'Upload Document on Behalf of Candidate' : 'Replace / Upload New Version',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'HR administrators can directly upload documents received via email, paper, or in-person verification.',
                      style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 14),

                    // File Selector Box
                    InkWell(
                      onTap: _pickFile,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _pickedBytes != null ? const Color(0xFF4F46E5) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            width: _pickedBytes != null ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _pickedBytes != null ? Icons.check_circle_outline_rounded : Icons.cloud_upload_outlined,
                                color: const Color(0xFF4F46E5),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _pickedFileName != null ? _pickedFileName! : 'Click to select document file from computer',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: _pickedFileName != null ? FontWeight.bold : FontWeight.w500,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _pickedFileSize > 0
                                        ? '${(_pickedFileSize / 1024).toStringAsFixed(1)} KB'
                                        : 'Supports PDF, JPG, PNG, DOC, DOCX up to 25MB',
                                    style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _pickFile,
                              icon: const Icon(Icons.folder_open_rounded, size: 16),
                              label: Text(_pickedBytes != null ? 'Change File' : 'Browse File'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Remarks field
                    TextField(
                      controller: _remarksController,
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        labelText: 'HR Verification Remarks / Notes (Optional)',
                        hintText: 'e.g. Received original verified copy during joining formalities',
                        hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Auto-verify checkbox
                    CheckboxListTile(
                      value: _autoVerify,
                      onChanged: (val) => setState(() => _autoVerify = val ?? true),
                      title: const Text('Mark as Verified & Approved immediately', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Sets document status to Verified upon upload', style: TextStyle(fontSize: 11)),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 12),

                    // Upload Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: ElevatedButton.icon(
                        onPressed: _isUploading ? null : _uploadDocument,
                        icon: _isUploading
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.cloud_upload_rounded, size: 18),
                        label: Text(
                          _isUploading ? 'Uploading Document...' : 'Upload Document for ${candidateName.split(' ').first}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Actions Bar
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: const Text('Back to Documents List'),
                  ),
                  Row(
                    children: [
                      if (!isVerified)
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _verifyDocument,
                          icon: const Icon(Icons.check_circle_rounded, size: 16),
                          label: const Text('Approve & Verify'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      if (!isRejected) ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : _rejectDocument,
                          icon: const Icon(Icons.cancel_outlined, size: 16, color: Color(0xFFEF4444)),
                          label: const Text('Reject', style: TextStyle(color: Color(0xFFEF4444))),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFEF4444)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ],
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
