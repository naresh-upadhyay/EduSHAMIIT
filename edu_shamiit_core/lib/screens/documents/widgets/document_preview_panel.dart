import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../config/app_config.dart';
import '../../../constants/app_fonts.dart';
import '../../../models/document_model.dart';

class DocumentPreviewPanel extends StatelessWidget {
  final DocumentModel? document;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  final VoidCallback onFullscreen;
  final VoidCallback onExternalOpen;
  final VoidCallback? onOpenGoogleDocs;
  final VoidCallback? onOpenOfficeOnline;
  final VoidCallback? onRestore;
  final VoidCallback? onPermanentDelete;
  final void Function(String status, String? comments)? onApprovalAction;
  final bool isDark;

  const DocumentPreviewPanel({
    super.key,
    required this.document,
    required this.onDownload,
    required this.onShare,
    required this.onFullscreen,
    required this.onExternalOpen,
    this.onOpenGoogleDocs,
    this.onOpenOfficeOnline,
    this.onRestore,
    this.onPermanentDelete,
    this.onApprovalAction,
    this.isDark = false,
  });

  String _formatDateTime(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final m = months[dt.month - 1];
    final day = dt.day < 10 ? '0${dt.day}' : '${dt.day}';
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final min = dt.minute < 10 ? '0${dt.minute}' : '${dt.minute}';
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$m $day, ${dt.year} $hour:$min $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    if (document == null) {
      return Container(
        width: 300,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderCol, width: 1),
        ),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.insert_drive_file_outlined, size: 48, color: textMuted),
              const SizedBox(height: 12),
              Text(
                'No Document Selected',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Click a document card to inspect its file preview and properties.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: AppFonts.body, fontSize: 12, color: textMuted),
              ),
            ],
          ),
        ),
      );
    }

    final doc = document!;

    return Container(
      width: 310,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCol, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Header: Document Preview & Quick Icons ───
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Document Preview',
                    style: TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.download_rounded,
                        size: 18,
                        color: doc.allowDownload ? textMuted : textMuted.withValues(alpha: 0.35),
                      ),
                      tooltip: doc.allowDownload ? 'Download' : 'Download restricted by owner',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      onPressed: doc.allowDownload ? onDownload : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      tooltip: 'Open in new tab / Live Viewer',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      color: textMuted,
                      onPressed: onExternalOpen,
                    ),
                    IconButton(
                      icon: const Icon(Icons.fullscreen_rounded, size: 20),
                      tooltip: 'Fullscreen preview',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      color: textMuted,
                      onPressed: onFullscreen,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: borderCol),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ─── Visual Preview Booklet / Card ───
                _buildVisualThumbnailCover(doc, textPrimary, textMuted, isDark, borderCol),

                // ─── Trashed Document Actions Banner ───
                if (doc.isDeleted) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Document is in Trash',
                                style: TextStyle(
                                  fontFamily: AppFonts.heading,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'You can restore this document to its original folder or remove it permanently.',
                          style: TextStyle(fontFamily: AppFonts.body, fontSize: 11, color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B)),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            if (onRestore != null)
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF16A34A),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.restore_from_trash_rounded, size: 15),
                                  label: const Text('Restore', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                                  onPressed: onRestore,
                                ),
                              ),
                            if (onRestore != null && onPermanentDelete != null) const SizedBox(width: 8),
                            if (onPermanentDelete != null)
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFEF4444),
                                    side: const BorderSide(color: Color(0xFFEF4444)),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.delete_forever_rounded, size: 15),
                                  label: const Text('Delete Forever', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                                  onPressed: onPermanentDelete,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // ─── Pending Approval Workflow Banner ───
                if (doc.approvalStatus == 'Pending' && onApprovalAction != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF451A03) : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.pending_actions_rounded, color: Color(0xFFD97706), size: 18),
                            SizedBox(width: 6),
                            Text(
                              'Approval Required',
                              style: TextStyle(
                                fontFamily: AppFonts.heading,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Review this document before publishing it to the institutional repository.',
                          style: TextStyle(fontFamily: AppFonts.body, fontSize: 11, color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E)),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF16A34A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.check_circle_outline_rounded, size: 15),
                                label: const Text('Approve', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                                onPressed: () => onApprovalAction!('Approved', null),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFDC2626),
                                  side: const BorderSide(color: Color(0xFFDC2626)),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.cancel_outlined, size: 15),
                                label: const Text('Reject', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                                onPressed: () => onApprovalAction!('Rejected', null),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // ─── Collaborative Office / Spreadsheet / Presentation Live Editor Banner ───
                if (doc.fileType == 'DOCX' || doc.fileType == 'DOC' || doc.fileType == 'XLSX' || doc.fileType == 'XLS' || doc.fileType == 'CSV' || doc.fileType == 'PPTX' || doc.fileType == 'PPT' || doc.fileType == 'TXT') ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (doc.fileType == 'PPTX' || doc.fileType == 'PPT')
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
                            : const Color(0xFF2563EB).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              (doc.fileType == 'PPTX' || doc.fileType == 'PPT')
                                  ? Icons.slideshow_rounded
                                  : (doc.fileType == 'XLSX' || doc.fileType == 'XLS' || doc.fileType == 'CSV')
                                      ? Icons.table_chart_rounded
                                      : Icons.description_rounded,
                              size: 18,
                              color: (doc.fileType == 'PPTX' || doc.fileType == 'PPT')
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF2563EB),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                (doc.fileType == 'PPTX' || doc.fileType == 'PPT')
                                    ? 'Collaborative Presentation'
                                    : (doc.fileType == 'XLSX' || doc.fileType == 'XLS' || doc.fileType == 'CSV')
                                        ? 'Collaborative Spreadsheet'
                                        : 'Collaborative Word Document',
                                style: TextStyle(
                                  fontFamily: AppFonts.heading,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: textPrimary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.circle, size: 6, color: Color(0xFF10B981)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Live Sync',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          (doc.fileType == 'PPTX' || doc.fileType == 'PPT')
                              ? 'Open interactive slide deck in a new tab. Present fullscreen, edit slides simultaneously, and sync notes live across the institute.'
                              : 'Open interactive live editor in a new tab. Multiple users can edit simultaneously with instant sync, auto-save & version history.',
                          style: TextStyle(fontSize: 10.5, color: textMuted),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: (doc.fileType == 'PPTX' || doc.fileType == 'PPT')
                                ? const Color(0xFFEA580C)
                                : const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: Icon(
                            (doc.fileType == 'PPTX' || doc.fileType == 'PPT')
                                ? Icons.slideshow_rounded
                                : Icons.edit_note_rounded,
                            size: 16,
                          ),
                          label: Text(
                            (doc.fileType == 'PPTX' || doc.fileType == 'PPT')
                                ? 'Open Slide Presentation'
                                : (doc.fileType == 'XLSX' || doc.fileType == 'XLS' || doc.fileType == 'CSV')
                                    ? 'Open Collaborative Sheet'
                                    : 'Open Collaborative Document',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                          ),
                          onPressed: onExternalOpen,
                        ),
                        const SizedBox(height: 6),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                            side: BorderSide(color: borderCol),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: Icon(Icons.link_rounded, size: 14, color: textMuted),
                          label: Text(
                            'Copy Live Share Link',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: textPrimary),
                          ),
                          onPressed: () {
                            final liveUrl = '${AppConfig.baseUrl}/api/documents/${doc.id}/editor';
                            Clipboard.setData(ClipboardData(text: liveUrl));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Live Collaborative Editor link copied to clipboard!'),
                                duration: Duration(seconds: 2),
                                backgroundColor: Color(0xFF1E293B),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 18),

                // ─── File Details Header ───
                Text(
                  'File Details',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 10),

                // ─── Detail Rows Table ───
                _buildDetailRow(
                  icon: Icons.description_outlined,
                  label: 'File Name',
                  value: doc.fileName ?? doc.title,
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                ),
                _buildDetailRow(
                  icon: Icons.category_outlined,
                  label: 'File Type',
                  value: doc.fileType,
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                ),
                _buildDetailRow(
                  icon: Icons.storage_outlined,
                  label: 'File Size',
                  value: doc.fileSizeLabel.isNotEmpty ? doc.fileSizeLabel : '2.4 MB',
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                ),
                _buildDetailRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Uploaded By',
                  value: doc.ownerName.isNotEmpty ? doc.ownerName : 'Admin',
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                ),
                _buildDetailRow(
                  icon: Icons.access_time_rounded,
                  label: 'Upload Date',
                  value: _formatDateTime(doc.createdAt),
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                ),
                _buildDetailRow(
                  icon: Icons.folder_outlined,
                  label: 'Location',
                  value: doc.folderName ?? doc.category.shortLabel,
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                ),
                _buildDetailRow(
                  icon: Icons.verified_outlined,
                  label: 'Approval',
                  value: doc.approvalStatus,
                  badgeColor: doc.approvalStatus == 'Approved'
                      ? const Color(0xFF16A34A)
                      : (doc.approvalStatus == 'Pending' ? const Color(0xFFD97706) : const Color(0xFFDC2626)),
                  badgeBg: doc.approvalStatus == 'Approved'
                      ? const Color(0xFFDCFCE7)
                      : (doc.approvalStatus == 'Pending' ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2)),
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                ),
                _buildDetailRow(
                  icon: Icons.history_rounded,
                  label: 'Version',
                  value: 'v${doc.versionNumber}.0',
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                ),
              ],
            ),
          ),

          Divider(height: 1, thickness: 1, color: borderCol),

          // ─── Bottom Actions (Share Document & Download) ───
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Share Document (Outlined)
                if (doc.canShare) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFF2563EB), width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: onShare,
                      icon: const Icon(Icons.share_outlined, size: 16),
                      label: const Text(
                        'Share Document',
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                // Download (Filled Royal Blue)
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: doc.allowDownload ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      foregroundColor: Colors.white,
                      elevation: doc.allowDownload ? 1 : 0,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: doc.allowDownload ? onDownload : null,
                    icon: Icon(doc.allowDownload ? Icons.download_rounded : Icons.lock_outline_rounded, size: 16),
                    label: Text(
                      doc.allowDownload ? 'Download' : 'Restricted',
                      style: const TextStyle(
                        fontFamily: AppFonts.heading,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualThumbnailCover(DocumentModel doc, Color textPrimary, Color textMuted, bool isDark, Color borderCol) {
    final isImage = (doc.fileType == 'JPG' || doc.fileType == 'PNG' || doc.fileType == 'JPEG') &&
        doc.fileUrl != null &&
        doc.fileUrl!.isNotEmpty;

    if (isImage) {
      return Container(
        height: 210,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderCol, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              doc.fileUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image_outlined, size: 40, color: textMuted),
                    const SizedBox(height: 6),
                    Text(
                      doc.fileName ?? doc.title,
                      style: TextStyle(fontFamily: AppFonts.body, fontSize: 11, color: textMuted),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Text(
                  doc.title,
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 210,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderCol, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Content Layout
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo & Header
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.school_rounded, color: Colors.white, size: 15),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EduSHAMIIT',
                          style: TextStyle(
                            fontFamily: AppFonts.heading,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          'School ERP',
                          style: TextStyle(
                            fontFamily: AppFonts.body,
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Main Document Title on Cover
                Text(
                  doc.title,
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                    height: 1.2,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),

                const Spacer(),

                // Campus building banner graphic
                Container(
                  height: 65,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF1E293B), const Color(0xFF334155)]
                          : const [Color(0xFFE0F2FE), Color(0xFFBAE6FD)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      doc.fileTypeIcon,
                      size: 34,
                      color: doc.fileTypeBadgeColor.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Blue ribbon accent on the right border matching Image 1
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 8,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF38BDF8)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? badgeColor,
    Color? badgeBg,
    required Color textPrimary,
    required Color textMuted,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: textMuted),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.body,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: textMuted,
              ),
            ),
          ),
          const Text(' : ', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5)),
          Expanded(
            child: badgeColor != null
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeBg ?? const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        value,
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: badgeColor,
                        ),
                      ),
                    ),
                  )
                : Text(
                    value,
                    style: TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        ],
      ),
    );
  }
}
