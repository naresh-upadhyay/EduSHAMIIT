import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import 'onboarding_document_viewer_dialog.dart';

class OnboardingDocumentsDialog extends StatefulWidget {
  final VoidCallback onDataChanged;
  final String initialStatus;

  const OnboardingDocumentsDialog({
    super.key,
    required this.onDataChanged,
    this.initialStatus = 'All',
  });

  @override
  State<OnboardingDocumentsDialog> createState() => _OnboardingDocumentsDialogState();
}

class _OnboardingDocumentsDialogState extends State<OnboardingDocumentsDialog> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;

  late String _selectedStatus;
  String _searchQuery = '';
  final int _pageSize = 15;

  List<dynamic> _docs = [];
  Map<String, dynamic> _pagination = {
    'page': 1,
    'page_size': 15,
    'total_records': 0,
    'total_pages': 1,
  };

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.initialStatus;
    _fetchDocuments(page: 1);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchDocuments({int page = 1}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final query = <String, dynamic>{
      'page': page,
      'page_size': _pageSize,
    };

    if (_searchQuery.trim().isNotEmpty) {
      query['search'] = _searchQuery.trim();
    }
    if (_selectedStatus != 'All') {
      query['status'] = _selectedStatus;
    }

    try {
      final res = await _api.get('/onboarding/documents/all', query: query, useCache: false);
      if (res['success'] == true) {
        setState(() {
          _docs = res['data'] as List<dynamic>? ?? [];
          _pagination = res['pagination'] as Map<String, dynamic>? ?? _pagination;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = res['detail'] ?? 'Failed to load documents.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('ApiException: ', '');
        _isLoading = false;
      });
    }
  }

  void _openViewer(Map<String, dynamic> doc) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => OnboardingDocumentViewerDialog(
        document: doc,
        onDocumentUpdated: () {
          _fetchDocuments(page: _pagination['page'] ?? 1);
          widget.onDataChanged();
        },
      ),
    );
  }

  Future<void> _verifyDoc(String docId, String docName) async {
    final remarksCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Verify Document: $docName'),
        content: TextField(
          controller: remarksCtrl,
          decoration: const InputDecoration(
            labelText: 'Remarks (Optional)',
            hintText: 'e.g. Scanned copy verified against original',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve & Verify', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await _api.post('/onboarding/documents/$docId/verify', {
        'remarks': remarksCtrl.text.trim().isNotEmpty ? remarksCtrl.text.trim() : null,
      });
      if (res['success'] == true) {
        _fetchDocuments(page: _pagination['page'] ?? 1);
        widget.onDataChanged();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to verify document: $e'), backgroundColor: const Color(0xFFEF4444)),
      );
    }
  }

  Future<void> _rejectDoc(String docId, String docName) async {
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reject Document: $docName'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            labelText: 'Mandatory Rejection Reason *',
            hintText: 'e.g. Incomplete scan, missing signature',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () {
              if (reasonCtrl.text.trim().length < 3) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Confirm Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await _api.post('/onboarding/documents/$docId/reject', {
        'reason': reasonCtrl.text.trim(),
      });
      if (res['success'] == true) {
        _fetchDocuments(page: _pagination['page'] ?? 1);
        widget.onDataChanged();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reject document: $e'), backgroundColor: const Color(0xFFEF4444)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final totalRecords = (_pagination['total_records'] as num?)?.toInt() ?? 0;
    final totalPages = (_pagination['total_pages'] as num?)?.toInt() ?? 1;
    final currentPage = (_pagination['page'] as num?)?.toInt() ?? 1;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.88,
        height: MediaQuery.of(context).size.height * 0.88,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header
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
                        child: const Icon(Icons.file_copy_outlined, color: Color(0xFF4F46E5), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Onboarding Documents & Verification Center',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Outfit',
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '$totalRecords Documents',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Review candidate uploads, verify credentials, and manage statutory compliance requirements.',
                              style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                          ],
                        ),
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
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Toolbar: Search + Status + Refresh
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: 'Search document name, candidate, or employee code...',
                        hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (val) {
                        _searchQuery = val;
                        _fetchDocuments(page: 1);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Status Filter
                Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: AppSearchableDropdown<String>.fromMenuItems(
                      value: _selectedStatus,
                      dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      items: ['All', 'Pending', 'Uploaded', 'Verified', 'Rejected']
                          .map((st) => DropdownMenuItem(value: st, child: Text(st == 'All' ? 'All Status' : st)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedStatus = val);
                          _fetchDocuments(page: 1);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Refresh Button
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  tooltip: 'Refresh',
                  onPressed: () => _fetchDocuments(page: currentPage),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Table Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _docs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _errorMessage != null ? Icons.error_outline_rounded : Icons.description_outlined,
                                size: 44,
                                color: _errorMessage != null ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _errorMessage ?? 'No documents found matching the criteria.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _errorMessage != null ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                                ),
                              ),
                              if (_errorMessage != null) ...[
                                const SizedBox(height: 14),
                                ElevatedButton.icon(
                                  onPressed: () => _fetchDocuments(page: currentPage),
                                  icon: const Icon(Icons.refresh_rounded, size: 16),
                                  label: const Text('Retry'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4F46E5),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 750),
                              child: DataTable(
                              columnSpacing: 16,
                              horizontalMargin: 8,
                              headingRowHeight: 40,
                              dataRowMinHeight: 48,
                              dataRowMaxHeight: 54,
                              columns: const [
                                DataColumn(label: Text('Document Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                DataColumn(label: Text('Candidate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                DataColumn(label: Text('Department', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                DataColumn(label: Text('Requirement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                DataColumn(label: Text('Verified By', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              ],
                              rows: _docs.map((d) {
                                final status = d['status'] ?? 'Pending';
                                final isVerified = status == 'Verified';
                                final isRejected = status == 'Rejected';
                                final isMandatory = d['is_mandatory'] == true;

                                Color statusBg;
                                Color statusFg;
                                if (isVerified) {
                                  statusBg = const Color(0xFF10B981).withValues(alpha: 0.1);
                                  statusFg = const Color(0xFF10B981);
                                } else if (isRejected) {
                                  statusBg = const Color(0xFFEF4444).withValues(alpha: 0.1);
                                  statusFg = const Color(0xFFEF4444);
                                } else if (status == 'Uploaded') {
                                  statusBg = const Color(0xFF3B82F6).withValues(alpha: 0.1);
                                  statusFg = const Color(0xFF3B82F6);
                                } else {
                                  statusBg = const Color(0xFFF59E0B).withValues(alpha: 0.1);
                                  statusFg = const Color(0xFFF59E0B);
                                }

                                return DataRow(
                                  cells: [
                                    DataCell(
                                      InkWell(
                                        onTap: () => _openViewer(d),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                d['file_url'] != null ? Icons.description_rounded : Icons.insert_drive_file_outlined,
                                                size: 16,
                                                color: const Color(0xFF4F46E5),
                                              ),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  d['document_name'] ?? 'Document',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                    color: Color(0xFF4F46E5),
                                                    decoration: TextDecoration.underline,
                                                    decorationColor: Color(0xFF818CF8),
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        '${d['candidate_name'] ?? 'Candidate'} (${d['onboarding_code'] ?? 'EMP'})',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    DataCell(Text(d['department'] ?? 'Academics', style: const TextStyle(fontSize: 12))),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isMandatory
                                              ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                                              : const Color(0xFF64748B).withValues(alpha: 0.1),
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
                                    ),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                                        child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusFg)),
                                      ),
                                    ),
                                    DataCell(Text(d['verified_by_name'] ?? '—', style: const TextStyle(fontSize: 12))),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF4F46E5)),
                                            tooltip: 'View & Preview Document',
                                            onPressed: () => _openViewer(d),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.upload_file_rounded, size: 18, color: Color(0xFF0EA5E9)),
                                            tooltip: 'Upload Document (HR on behalf of Candidate)',
                                            onPressed: () => _openViewer(d),
                                          ),
                                          if (!isVerified)
                                            IconButton(
                                              icon: const Icon(Icons.check_circle_outline_rounded, size: 18, color: Color(0xFF10B981)),
                                              tooltip: 'Quick Approve & Verify',
                                              onPressed: () => _verifyDoc(d['id'].toString(), d['document_name'] ?? 'Doc'),
                                            ),
                                          if (!isRejected)
                                            IconButton(
                                              icon: const Icon(Icons.cancel_outlined, size: 18, color: Color(0xFFEF4444)),
                                              tooltip: 'Reject Document',
                                              onPressed: () => _rejectDoc(d['id'].toString(), d['document_name'] ?? 'Doc'),
                                            ),
                                        ],
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

            // Pagination
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${totalRecords == 0 ? 0 : (currentPage - 1) * _pageSize + 1} to ${(currentPage * _pageSize).clamp(0, totalRecords)} of $totalRecords documents',
                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: currentPage > 1 ? () => _fetchDocuments(page: currentPage - 1) : null,
                    ),
                    Text(
                      '$currentPage of $totalPages',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: currentPage < totalPages ? () => _fetchDocuments(page: currentPage + 1) : null,
                    ),
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
