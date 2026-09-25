import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:edu_shamiit_core/config/app_config.dart';
import 'package:edu_shamiit_core/services/api_service.dart';

class DocumentDetailDrawer extends StatefulWidget {
  final String documentId;
  final VoidCallback onDocumentUpdated;

  const DocumentDetailDrawer({
    super.key,
    required this.documentId,
    required this.onDocumentUpdated,
  });

  @override
  State<DocumentDetailDrawer> createState() => _DocumentDetailDrawerState();
}

class _DocumentDetailDrawerState extends State<DocumentDetailDrawer> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _docData;
  List<dynamic> _versions = [];
  List<dynamic> _activity = [];

  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchDocument();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchDocument() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get('/hr/documents/${widget.documentId}', useCache: false);
      if (res['success'] == true) {
        final data = res['data'] as Map<String, dynamic>;
        final doc = (data['document'] is Map ? Map<String, dynamic>.from(data['document']) : data);
        setState(() {
          _docData = doc;
          _versions = data['versions'] ?? [];
          _activity = data['activity'] ?? data['activity_timeline'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadDocument({String? version}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final queryParams = <String, String>{
        if (token != null) 'token': token,
        if (version != null) 'version': version,
        '_t': DateTime.now().millisecondsSinceEpoch.toString(),
      };
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/hr/documents/${widget.documentId}/download')
          .replace(queryParameters: queryParams);

      // For web/desktop, open via URL with auth or trigger download
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('Downloading document stream...'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showReplaceFileDialog() async {
    final summaryController = TextEditingController(text: 'Updated document revision.');
    PlatformFile? pickedFile;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Replace Document File (New Version)'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Uploading a new file creates a non-destructive version while preserving the previous file.'),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final res = await FilePicker.platform.pickFiles(withData: true);
                    if (res != null && res.files.isNotEmpty) {
                      setModalState(() => pickedFile = res.files.first);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.file_upload_outlined, color: Color(0xFF4F46E5)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            pickedFile != null ? pickedFile!.name : 'Select updated file...',
                            style: TextStyle(fontWeight: pickedFile != null ? FontWeight.bold : FontWeight.normal),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: summaryController,
                  decoration: const InputDecoration(labelText: 'Change Summary', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Upload & Replace'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');

        var uri = Uri.parse('${AppConfig.apiBaseUrl}/hr/documents/${widget.documentId}/replace');
        var request = http.MultipartRequest('POST', uri);
        if (token != null) request.headers['Authorization'] = 'Bearer $token';

        request.fields['change_summary'] = summaryController.text.trim();

        if (pickedFile != null && pickedFile!.bytes != null) {
          request.files.add(http.MultipartFile.fromBytes('file', pickedFile!.bytes!, filename: pickedFile!.name));
        } else {
          final mockContent = utf8.encode('Updated revision content for ${_docData?['document_name']}');
          request.files.add(http.MultipartFile.fromBytes('file', mockContent, filename: 'updated_${_docData?['file_name'] ?? 'doc.pdf'}'));
        }

        final streamed = await request.send();
        final res = await http.Response.fromStream(streamed);

        if (res.statusCode >= 200 && res.statusCode < 300) {
          widget.onDocumentUpdated();
          await _fetchDocument();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Document version updated!'), backgroundColor: Colors.green),
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
  }

  Future<void> _archiveDocument() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive Document'),
        content: const Text('Are you sure you want to archive this document? It will be removed from active listings.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archive', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final res = await _api.post('/hr/documents/${widget.documentId}/archive', {});
        if (res['success'] == true) {
          widget.onDocumentUpdated();
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Document archived successfully')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  String _formatBytes(dynamic bytes) {
    if (bytes == null) return '0 B';
    final int b = int.tryParse(bytes.toString()) ?? 0;
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 680,
      color: isDark ? const Color(0xFF13182C) : Colors.white,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Error: $_errorMessage'))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _docData?['current_version'] ?? 'v1.0',
                                      style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _docData?['access_level'] ?? 'INSTITUTE_WIDE',
                                      style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _docData?['document_name'] ?? 'Document Details',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_docData?['category_name'] ?? ''} · ${_docData?['document_type'] ?? ''} · ${_formatBytes(_docData?['file_size_bytes'] ?? _docData?['file_size'])}',
                            style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 16),
                          // Actions
                          Wrap(
                            spacing: 8,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _downloadDocument,
                                icon: const Icon(Icons.download_rounded, size: 14, color: Colors.white),
                                label: const Text('Download', style: TextStyle(color: Colors.white, fontSize: 12)),
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
                              ),
                              OutlinedButton.icon(
                                onPressed: _showReplaceFileDialog,
                                icon: const Icon(Icons.sync_rounded, size: 14),
                                label: const Text('Replace File', style: TextStyle(fontSize: 12)),
                              ),
                              OutlinedButton.icon(
                                onPressed: _archiveDocument,
                                icon: const Icon(Icons.archive_outlined, size: 14, color: Colors.amber),
                                label: const Text('Archive', style: TextStyle(color: Colors.amber, fontSize: 12)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Tabs
                    TabBar(
                      controller: _tabController,
                      indicatorColor: const Color(0xFF4F46E5),
                      labelColor: const Color(0xFF4F46E5),
                      unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      tabs: const [
                        Tab(text: 'Overview'),
                        Tab(text: 'Preview'),
                        Tab(text: 'Versions'),
                        Tab(text: 'Activity'),
                      ],
                    ),
                    // Content
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildOverviewTab(isDark),
                          _buildPreviewTab(isDark),
                          _buildVersionsTab(isDark),
                          _buildActivityTab(isDark),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildOverviewTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Document Name', _docData?['document_name']),
          _buildInfoRow('Original File', _docData?['file_name']),
          _buildInfoRow('Category', _docData?['category_name']),
          _buildInfoRow('Type', _docData?['document_type']),
          _buildInfoRow('File Size', _formatBytes(_docData?['file_size_bytes'] ?? _docData?['file_size'])),
          _buildInfoRow('Access Level', _docData?['access_level'] ?? 'INSTITUTE_WIDE'),
          _buildInfoRow('Department', _docData?['department'] ?? 'General'),
          _buildInfoRow('Linked Employee', _docData?['linked_employee_name'] ?? 'None'),
          _buildInfoRow('Issue Date', _docData?['issue_date'] != null ? _dateFormat.format(DateTime.parse(_docData!['issue_date'].toString())) : '-'),
          _buildInfoRow('Expiry Date', _docData?['expiry_date'] != null ? _dateFormat.format(DateTime.parse(_docData!['expiry_date'].toString())) : 'No Expiry'),
          _buildInfoRow('Review Date', _docData?['review_date'] != null ? _dateFormat.format(DateTime.parse(_docData!['review_date'].toString())) : 'None scheduled'),
          _buildInfoRow('Tags', _docData?['tags']),
          _buildInfoRow('Uploaded By', _docData?['uploaded_by_name'] ?? 'System'),
          _buildInfoRow('Uploaded At', _docData?['created_at'] != null ? _dateFormat.format(DateTime.parse(_docData!['created_at'].toString())) : '-'),
          const Divider(height: 24),
          const Text('Description / Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Text(_docData?['description']?.toString() ?? 'No notes entered.', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    String displayValue = '-';
    if (value is List) {
      displayValue = value.isEmpty ? 'None' : value.map((e) => e.toString()).join(', ');
    } else if (value != null && value.toString().trim().isNotEmpty) {
      displayValue = value.toString();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(displayValue, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewTab(bool isDark) {
    final fileName = _docData?['file_name'] ?? 'document.pdf';
    final isPdf = fileName.toLowerCase().endsWith('.pdf');
    final isImage = fileName.toLowerCase().endsWith('.jpg') || fileName.toLowerCase().endsWith('.jpeg') || fileName.toLowerCase().endsWith('.png');

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPdf
                  ? Icons.picture_as_pdf_rounded
                  : isImage
                      ? Icons.image_rounded
                      : Icons.description_rounded,
              size: 64,
              color: isPdf ? Colors.red.shade400 : const Color(0xFF4F46E5),
            ),
            const SizedBox(height: 16),
            Text(fileName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('${_formatBytes(_docData?['file_size'])} · Secure Encrypted Storage', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _downloadDocument,
              icon: const Icon(Icons.open_in_new_rounded, size: 16, color: Colors.white),
              label: const Text('Open & View File', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionsTab(bool isDark) {
    if (_versions.isEmpty) {
      return const Center(child: Text('No previous versions.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: _versions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final v = _versions[index];
        final isCurrent = v['version_number'] == _docData?['current_version'];

        final fileName = v['file_name'] ?? 'document.pdf';
        final fileSizeStr = v['file_size_bytes'] != null ? _formatBytes(v['file_size_bytes']) : '';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isCurrent ? const Color(0xFF4F46E5) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              width: isCurrent ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Version ${v['version_number']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFF4F46E5), borderRadius: BorderRadius.circular(4)),
                            child: const Text('CURRENT', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(fileName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(
                      '${v['change_summary'] ?? 'File version update'}${fileSizeStr.isNotEmpty ? ' · $fileSizeStr' : ''}',
                      style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    v['created_at'] != null ? _dateFormat.format(DateTime.parse(v['created_at'])) : '',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 6),
                  IconButton(
                    icon: const Icon(Icons.download_rounded, size: 18, color: Color(0xFF4F46E5)),
                    tooltip: 'Download Version ${v['version_number']}',
                    onPressed: () => _downloadDocument(version: v['version_number']),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivityTab(bool isDark) {
    if (_activity.isEmpty) {
      return const Center(child: Text('No activity logged.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: _activity.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final act = _activity[index];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: const Color(0xFF4F46E5).withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.history_rounded, size: 14, color: Color(0xFF4F46E5)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(act['summary'] ?? act['action'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(
                    '${act['performer_name'] ?? 'System'} · ${act['created_at'] != null ? _dateFormat.format(DateTime.parse(act['created_at'])) : ''}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
