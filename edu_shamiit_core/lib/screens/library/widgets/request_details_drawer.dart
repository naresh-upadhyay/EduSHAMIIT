import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/request_models.dart';
import '../providers/request_provider.dart';
import 'dialogs/process_request_dialog.dart';

class RequestDetailsDrawer extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const RequestDetailsDrawer({
    super.key,
    required this.onClose,
  });

  @override

  ConsumerState<RequestDetailsDrawer> createState() => _RequestDetailsDrawerState();
}

class _RequestDetailsDrawerState extends ConsumerState<RequestDetailsDrawer> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _commentController = TextEditingController();
  bool _isInternalComment = false;
  bool _isUploadingAttachment = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadDrawerAttachment(String requestId) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'docx', 'doc', 'xlsx', 'txt'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) return;

      setState(() => _isUploadingAttachment = true);
      final notifier = ref.read(requestProvider.notifier);
      await notifier.uploadAttachment(
        requestId: requestId,
        bytes: bytes,
        filename: file.name,
      );

      setState(() => _isUploadingAttachment = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File "${file.name}" uploaded and linked successfully!'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploadingAttachment = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload attachment: ${e.toString().replaceAll('Exception:', '').trim()}'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData _getFileIcon(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'png':
      case 'jpg':
      case 'jpeg':
        return Icons.image_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'xlsx':
      case 'xls':
        return Icons.table_chart_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _getFileColor(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return const Color(0xFFDC2626);
      case 'png':
      case 'jpg':
      case 'jpeg':
        return const Color(0xFF2563EB);
      case 'doc':
      case 'docx':
        return const Color(0xFF0284C7);
      case 'xlsx':
      case 'xls':
        return const Color(0xFF16A34A);
      default:
        return const Color(0xFF64748B);
    }
  }


  @override
  Widget build(BuildContext context) {
    final state = ref.watch(requestProvider);
    final notifier = ref.read(requestProvider.notifier);
    final detail = state.selectedRequestDetail;

    return Container(
      width: 480,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          _buildHeader(context, detail, state.isDetailLoading),

          if (state.isDetailLoading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (detail == null)
            Expanded(
              child: Center(
                child: Text(
                  state.detailErrorMessage ?? 'Select a request to view details',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ),
            )
          else ...[
            // Tab Bar (Details, Timeline, Comments, Attachments)
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: const Color(0xFF1E293B),
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                indicatorColor: const Color(0xFF2563EB),
                indicatorWeight: 3,
                tabs: [
                  const Tab(text: 'Overview'),
                  Tab(text: 'Timeline (${detail.timeline.length})'),
                  Tab(text: 'Comments (${detail.comments.length})'),
                  Tab(text: 'Attachments (${detail.attachments.length})'),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(context, detail.request, notifier),
                  _buildTimelineTab(detail.timeline),
                  _buildCommentsTab(context, detail.request.id, detail.comments, notifier),
                  _buildAttachmentsTab(context, detail.request.id, detail.attachments, notifier),
                ],
              ),
            ),

            // Bottom Context-aware Action Bar
            _buildBottomActionBar(context, detail.request, notifier),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, RequestDetailModel? detail, bool isLoading) {
    final item = detail?.request;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border(bottom: BorderSide(color: Colors.grey.shade800)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      item?.requestNumber ?? 'Request Details',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    if (item != null) ...[
                      const SizedBox(width: 10),
                      _buildHeaderStatusPill(item.status),
                    ],
                  ],
                ),
                if (item != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Close button
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStatusPill(String status) {
    Color bg;
    Color text;

    switch (status.toUpperCase()) {
      case 'NEW':
      case 'PENDING':
        bg = const Color(0xFF2563EB);
        text = Colors.white;
        break;
      case 'ACTIVE':
      case 'IN_PROGRESS':
        bg = const Color(0xFF7C3AED);
        text = Colors.white;
        break;
      case 'RESOLVED':
      case 'COMPLETED':
        bg = const Color(0xFF10B981);
        text = Colors.white;
        break;
      case 'REJECTED':
        bg = const Color(0xFFEF4444);
        text = Colors.white;
        break;
      default:
        bg = const Color(0xFF64748B);
        text = Colors.white;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: text),
      ),
    );
  }

  Widget _buildOverviewTab(
    BuildContext context,
    LibraryRequestItem req,
    RequestNotifier notifier,
  ) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Section 1: Item Details Card
        _buildSectionCard(
          title: 'Resource Details',
          icon: Icons.menu_book_rounded,
          children: [
            _buildDetailRow('Title', req.title),
            if (req.author != null) _buildDetailRow('Author', req.author!),
            if (req.isbn != null) _buildDetailRow('ISBN', req.isbn!),
            if (req.publisher != null) _buildDetailRow('Publisher', req.publisher!),
            if (req.edition != null) _buildDetailRow('Edition', req.edition!),
            _buildDetailRow('Language', req.language),
            _buildDetailRow('Request Type', req.requestType),
            _buildDetailRow('Preferred Format', req.preferredFormat),
            _buildDetailRow('Quantity Requested', req.quantity.toString()),
            _buildDetailRow('Priority', req.priority),
            if (req.requiredBy != null)
              _buildDetailRow('Required By', DateFormat('dd MMM yyyy').format(req.requiredBy!)),
          ],
        ),
        const SizedBox(height: 16),

        // Section 2: Requester Profile Card
        _buildSectionCard(
          title: 'Requested By',
          icon: Icons.person_rounded,
          children: [
            _buildDetailRow('Name', req.requesterName),
            _buildDetailRow('Role', req.requesterRole.toUpperCase()),
            _buildDetailRow('Class / Department', req.requesterClass),
            if (req.memberCode != null) _buildDetailRow('Member Code', req.memberCode!),
            _buildDetailRow('Request Date', dateFormat.format(req.createdAt)),
          ],
        ),
        const SizedBox(height: 16),

        // Section 3: Reason / Description / Rejection
        _buildSectionCard(
          title: 'Purpose & Notes',
          icon: Icons.notes_rounded,
          children: [
            if (req.reason != null && req.reason!.isNotEmpty)
              _buildDetailRow('Reason', req.reason!),
            if (req.description != null && req.description!.isNotEmpty)
              _buildDetailRow('Description', req.description!),
            if (req.rejectionReason != null && req.rejectionReason!.isNotEmpty)
              _buildDetailRow('Rejection Reason', req.rejectionReason!, isDanger: true),
            if (req.cancellationReason != null && req.cancellationReason!.isNotEmpty)
              _buildDetailRow('Cancellation Reason', req.cancellationReason!, isDanger: true),
          ],
        ),
        const SizedBox(height: 16),

        // Section 4: Assignment & Catalog Status
        _buildSectionCard(
          title: 'Processing Status',
          icon: Icons.assignment_turned_in_rounded,
          children: [
            _buildDetailRow('Assigned Librarian', req.assignedToName ?? 'Unassigned'),
            _buildDetailRow('Availability', req.availabilityStatus.replaceAll('_', ' ')),
            if (req.availableCopies != null)
              _buildDetailRow('Catalog Copies', '${req.availableCopies} available / ${req.totalCopies ?? 0} total'),
            if (req.rackLocation != null)
              _buildDetailRow('Rack Location', req.rackLocation!),
            if (req.shelfLocation != null)
              _buildDetailRow('Shelf Location', req.shelfLocation!),
            if (req.processedAt != null)
              _buildDetailRow('Processed At', dateFormat.format(req.processedAt!)),
          ],
        ),
      ],
    );
  }

  Widget _buildTimelineTab(List<RequestTimelineEvent> timeline) {
    if (timeline.isEmpty) {
      return const Center(child: Text('No audit timeline events recorded yet.'));
    }

    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: timeline.length,
      itemBuilder: (ctx, index) {
        final event = timeline[index];
        final isLast = index == timeline.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline line & dot
            Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.3), blurRadius: 4),
                    ],
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 50,
                    color: const Color(0xFFE2E8F0),
                  ),
              ],
            ),
            const SizedBox(width: 14),

            // Event description
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          event.toStatus.isNotEmpty ? 'Status: ${event.toStatus}' : event.action,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                        ),
                        Text(
                          dateFormat.format(event.createdAt),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Updated by ${event.changedByName}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    if (event.comment != null && event.comment!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          event.comment!,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCommentsTab(
    BuildContext context,
    String requestId,
    List<RequestComment> comments,
    RequestNotifier notifier,
  ) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return Column(
      children: [
        // Comments List
        Expanded(
          child: comments.isEmpty
              ? Center(
                  child: Text(
                    'No comments yet. Write a note below.',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: comments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, index) {
                    final c = comments[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.isInternal ? const Color(0xFFFEF9C3) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: c.isInternal ? const Color(0xFFFDE047) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    c.authorName,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                  ),
                                  if (c.isInternal) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFCA8A04),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('Internal Note', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
                                    ),
                                  ],
                                ],
                              ),
                              Text(dateFormat.format(c.createdAt), style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(c.comment, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                        ],
                      ),
                    );
                  },
                ),
        ),

        // Comment Input Box
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Checkbox(
                    value: _isInternalComment,
                    onChanged: (val) => setState(() => _isInternalComment = val ?? false),
                  ),
                  const Text('Internal staff note only', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Add a comment or internal note...',
                        hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      if (_commentController.text.trim().isEmpty) return;
                      await notifier.addComment(
                        requestId: requestId,
                        comment: _commentController.text.trim(),
                        isInternal: _isInternalComment,
                      );
                      _commentController.clear();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    child: const Text('Post', style: TextStyle(fontSize: 12, color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentsTab(
    BuildContext context,
    String requestId,
    List<RequestAttachment> attachments,
    RequestNotifier notifier,
  ) {
    return Column(
      children: [
        // Top Action Bar with Upload Button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${attachments.length} ${attachments.length == 1 ? 'Attachment' : 'Attachments'}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
              ),
              ElevatedButton.icon(
                onPressed: _isUploadingAttachment ? null : () => _pickAndUploadDrawerAttachment(requestId),
                icon: _isUploadingAttachment
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.upload_file_rounded, size: 16),
                label: Text(
                  _isUploadingAttachment ? 'Uploading...' : 'Upload File',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
        ),

        // Attachments Content or Dropzone
        Expanded(
          child: attachments.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEFF6FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.cloud_upload_rounded, size: 36, color: Color(0xFF2563EB)),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No attachments linked yet',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Upload PDFs, book references, requisition notes, or images directly from your system.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _isUploadingAttachment ? null : () => _pickAndUploadDrawerAttachment(requestId),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Browse & Upload File', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2563EB),
                            side: const BorderSide(color: Color(0xFF93C5FD)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: attachments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, index) {
                    final a = attachments[index];
                    final color = _getFileColor(a.fileName);
                    final icon = _getFileIcon(a.fileName);

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(icon, size: 22, color: color),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.fileName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      _formatFileSize(a.fileSize),
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                    ),
                                    if (a.uploadedByName.isNotEmpty) ...[
                                      Text(' • ', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                                      Text(
                                        'By ${a.uploadedByName}',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (a.fileUrl.isNotEmpty) ...[
                            IconButton(
                              tooltip: 'Open / Download',
                              icon: const Icon(Icons.open_in_new_rounded, size: 18, color: Color(0xFF2563EB)),
                              splashRadius: 16,
                              onPressed: () async {
                                final uri = Uri.parse(a.fileUrl);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              },
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }


  Widget _buildBottomActionBar(
    BuildContext context,
    LibraryRequestItem req,
    RequestNotifier notifier,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        children: [
          // Process / Change Status
          ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => ProcessRequestDialog(request: req),
              );
            },
            icon: const Icon(Icons.edit_note_rounded, size: 16, color: Colors.white),
            label: const Text('Process / Update Status', style: TextStyle(fontSize: 12, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 16, color: const Color(0xFF2563EB)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isDanger = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDanger ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
