import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_config.dart';
import '../../constants/app_fonts.dart';
import '../../models/document_model.dart';
import '../../providers/documents_provider.dart';
import '../../utils/download_helper.dart';
import '../../utils/nav_helper.dart';
import 'widgets/document_kpi_cards.dart';
import 'widgets/folder_tree_panel.dart';
import 'widgets/document_grid_card.dart';
import 'widgets/document_preview_panel.dart';
import 'widgets/document_dialogs.dart';

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  final _searchController = TextEditingController();
  Timer? _searchDebounceTimer;

  static const _tabs = [
    {'id': 'all', 'label': 'All Documents', 'icon': Icons.folder_copy_outlined},
    {'id': 'my_documents', 'label': 'My Documents', 'icon': Icons.person_outline_rounded},
    {'id': 'shared_with_me', 'label': 'Shared with Me', 'icon': Icons.people_alt_outlined},
    {'id': 'recent', 'label': 'Recent', 'icon': Icons.history_rounded},
    {'id': 'starred', 'label': 'Starred', 'icon': Icons.star_outline_rounded},
    {'id': 'trash', 'label': 'Trash', 'icon': Icons.delete_outline_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      _searchDebounceTimer?.cancel();
      _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          ref.read(documentsProvider.notifier).setSearchQuery(_searchController.text.trim());
        }
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(documentsProvider.notifier).init();
    });
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _showUploadDialog(BuildContext context, DocumentsState state) {
    showDialog(
      context: context,
      builder: (ctx) => DocumentUploadDialog(
        folders: state.allFoldersFlat,
        initialFolderId: state.activeFolderId,
        onUpload: ref.read(documentsProvider.notifier).uploadDocument,
      ),
    );
  }

  void _showNewFolderDialog(BuildContext context, DocumentsState state) {
    showDialog(
      context: context,
      builder: (ctx) => CreateFolderDialog(
        folders: state.allFoldersFlat,
        initialParentId: state.activeFolderId,
        onCreate: ref.read(documentsProvider.notifier).createFolder,
      ),
    );
  }

  void _showShareDialog(BuildContext context, DocumentModel doc, DocumentsState state) {
    ref.read(documentsProvider.notifier).loadDocumentDetails(doc.id);
    showDialog(
      context: context,
      builder: (ctx) => ShareDocumentDialog(
        document: doc,
        currentShares: state.shares,
        onSearchUsers: ref.read(documentsProvider.notifier).searchUsers,
        onShare: ref.read(documentsProvider.notifier).shareDocument,
        onRevoke: ref.read(documentsProvider.notifier).revokeShare,
      ),
    );
  }

  void _showVersionHistoryDialog(BuildContext context, DocumentModel doc, DocumentsState state) {
    showDialog(
      context: context,
      builder: (ctx) => VersionHistoryDialog(
        document: doc,
        versions: state.versions,
        onUploadVersion: ref.read(documentsProvider.notifier).uploadNewVersion,
        onRestoreVersion: ref.read(documentsProvider.notifier).restoreVersion,
      ),
    );
  }

  void _showRequestDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => DocumentRequestDialog(
        onSubmit: ref.read(documentsProvider.notifier).createDocumentRequest,
      ),
    );
  }

  void _showRequestsManagerDialog(BuildContext context, DocumentsState state) {
    showDialog(
      context: context,
      builder: (ctx) => DocumentRequestsManagerDialog(
        requests: state.requests,
        availableDocuments: state.documents,
        onRefresh: ({status}) => ref.read(documentsProvider.notifier).loadRequests(status: status),
        onUpdateStatus: (reqId, {required status, responseNotes}) =>
            ref.read(documentsProvider.notifier).updateRequestStatus(reqId, status: status, responseNotes: responseNotes),
        onFulfill: (reqId, {required documentId, responseNotes}) =>
            ref.read(documentsProvider.notifier).fulfillRequest(reqId, documentId: documentId, responseNotes: responseNotes),
        isDark: Theme.of(context).brightness == Brightness.dark,
      ),
    );
  }

  void _confirmEmptyTrash(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Empty Trash Completely?'),
        content: const Text(
          'Are you sure you want to permanently delete all items in the Trash? This action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(documentsProvider.notifier).emptyTrash();
            },
            child: const Text('Empty Trash Now'),
          ),
        ],
      ),
    );
  }

  void _downloadDocument(DocumentModel doc) {
    final downloadUrl = doc.fileUrl != null && doc.fileUrl!.startsWith('http')
        ? doc.fileUrl!
        : '/api/documents/${doc.id}/download';
    getDownloadHelper().downloadFile(downloadUrl, doc.fileName ?? '${doc.title}.pdf');
  }

  bool _isCollaborativeDoc(DocumentModel doc) {
    final type = doc.fileType.toUpperCase();
    return type == 'XLSX' ||
        type == 'XLS' ||
        type == 'CSV' ||
        type == 'SHEET' ||
        type == 'DOCX' ||
        type == 'DOC' ||
        type == 'PPTX' ||
        type == 'PPT' ||
        type == 'TXT' ||
        type == 'MD' ||
        type == 'RTF';
  }

  Future<void> _openCollaborativeEditor(DocumentModel doc) async {
    String? token;
    try {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('auth_token');
    } catch (_) {}

    try {
      final data = await ref.read(documentsProvider.notifier).getLiveEditorUrl(doc.id);
      String? editorPath = data?['live_url'] as String? ?? data?['editor_url'] as String?;
      if (editorPath == null || editorPath.isEmpty) {
        editorPath = '/api/documents/${doc.id}/editor';
      }
      String fullUrl = editorPath.startsWith('http') ? editorPath : '${AppConfig.baseUrl}$editorPath';
      if (token != null && token.isNotEmpty && !fullUrl.contains('token=')) {
        final sep = fullUrl.contains('?') ? '&' : '?';
        fullUrl = '$fullUrl${sep}token=$token';
      }
      final uri = Uri.parse(fullUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    // Fallback directly to AppConfig.baseUrl/api/documents/{id}/editor
    try {
      var directUrl = '${AppConfig.baseUrl}/api/documents/${doc.id}/editor';
      if (token != null && token.isNotEmpty) {
        directUrl += '?token=$token';
      }
      final uri = Uri.parse(directUrl);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      _downloadDocument(doc);
    }
  }

  Future<void> _openInTab(DocumentModel doc) async {
    if (_isCollaborativeDoc(doc)) {
      await _openCollaborativeEditor(doc);
      return;
    }

    final rawUrl = doc.fileUrl != null && doc.fileUrl!.startsWith('http')
        ? doc.fileUrl!
        : '${AppConfig.baseUrl}/api/documents/${doc.id}/preview';
    try {
      final uri = Uri.parse(rawUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        getDownloadHelper().downloadFile(rawUrl, doc.fileName ?? '${doc.title}.pdf');
      }
    } catch (_) {
      getDownloadHelper().downloadFile(rawUrl, doc.fileName ?? '${doc.title}.pdf');
    }
  }

  Future<void> _openLiveEditor(DocumentModel doc, [String service = 'collaborative']) async {
    await _openCollaborativeEditor(doc);
  }

  void _openFullscreenPreview(BuildContext context, DocumentModel doc) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final isImage = doc.fileType == 'JPG' || doc.fileType == 'PNG' || doc.fileType == 'JPEG';
    final isOffice = _isCollaborativeDoc(doc);

    showDialog(
      context: context,
      useSafeArea: false,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: cardBg,
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            foregroundColor: textPrimary,
            elevation: 1,
            title: Row(
              children: [
                Icon(doc.fileTypeIcon, color: doc.fileTypeBadgeColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        doc.title,
                        style: TextStyle(fontFamily: AppFonts.heading, fontSize: 15, fontWeight: FontWeight.w800, color: textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${doc.fileType} • ${doc.fileSizeLabel} • Uploaded by ${doc.ownerName}',
                        style: TextStyle(fontSize: 11, color: textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              if (isOffice) ...[
                TextButton.icon(
                  icon: const Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFF2563EB)),
                  label: const Text('Open Collaborative Editor', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w700)),
                  onPressed: () => _openCollaborativeEditor(doc),
                ),
                const SizedBox(width: 4),
              ],
              IconButton(
                icon: const Icon(Icons.open_in_new_rounded),
                tooltip: 'Open in New Tab',
                onPressed: () => _openInTab(doc),
              ),
              if (doc.allowDownload)
                IconButton(
                  icon: const Icon(Icons.download_rounded),
                  tooltip: 'Download',
                  onPressed: () => _downloadDocument(doc),
                ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Close',
                onPressed: () => Navigator.of(ctx).pop(),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Center(
            child: isImage && doc.fileUrl != null && doc.fileUrl!.startsWith('http')
                ? InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 5.0,
                    child: Image.network(
                      doc.fileUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => _buildFullscreenDocFallback(doc, textPrimary, textMuted, isDark, borderCol),
                    ),
                  )
                : _buildFullscreenDocFallback(doc, textPrimary, textMuted, isDark, borderCol),
          ),
        ),
      ),
    );
  }

  Widget _buildFullscreenDocFallback(DocumentModel doc, Color textPrimary, Color textMuted, bool isDark, Color borderCol) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 650),
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: doc.fileTypeBadgeColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(doc.fileTypeIcon, size: 54, color: doc.fileTypeBadgeColor),
          ),
          const SizedBox(height: 16),
          Text(
            doc.title,
            style: TextStyle(fontFamily: AppFonts.heading, fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            '${doc.fileType} Document • ${doc.fileSizeLabel} • Category: ${doc.category.shortLabel}',
            style: TextStyle(fontSize: 12, color: textMuted),
          ),
          if (doc.description != null && doc.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              doc.description!,
              style: TextStyle(fontSize: 13, color: textPrimary),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 20),
          Divider(color: borderCol),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              if (_isCollaborativeDoc(doc))
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                  onPressed: () => _openCollaborativeEditor(doc),
                  icon: Icon(
                    (doc.fileType == 'PPTX' || doc.fileType == 'PPT')
                        ? Icons.slideshow_rounded
                        : (doc.fileType == 'XLSX' || doc.fileType == 'XLS' || doc.fileType == 'CSV')
                            ? Icons.table_chart_rounded
                            : Icons.edit_note_rounded,
                    size: 16,
                  ),
                  label: Text(
                    (doc.fileType == 'PPTX' || doc.fileType == 'PPT')
                        ? 'Open Collaborative Slides'
                        : (doc.fileType == 'XLSX' || doc.fileType == 'XLS' || doc.fileType == 'CSV')
                            ? 'Open Collaborative Sheet'
                            : 'Open Collaborative Document',
                  ),
                ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                onPressed: () => _openInTab(doc),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Open in New Browser Tab'),
              ),
              if (doc.allowDownload)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF2563EB))),
                  onPressed: () => _downloadDocument(doc),
                  icon: const Icon(Icons.download_rounded, size: 16, color: Color(0xFF2563EB)),
                  label: const Text('Download File', style: TextStyle(color: Color(0xFF2563EB))),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, DocumentModel doc) {
    final isPermanent = doc.isDeleted;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isPermanent ? 'Permanently Delete Document?' : 'Move Document to Trash?'),
        content: Text(
          isPermanent
              ? 'Are you sure you want to permanently delete "${doc.title}"? This action cannot be undone.'
              : 'Move "${doc.title}" to Trash? You can restore it later if needed.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(documentsProvider.notifier).deleteDocument(doc.id, permanent: isPermanent);
            },
            child: Text(isPermanent ? 'Delete Forever' : 'Move to Trash'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(documentsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    // Listen for snackbar notifications
    ref.listen<DocumentsState>(documentsProvider, (prev, next) {
      if (next.successMessage != null && next.successMessage != prev?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next.successMessage!),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
        ref.read(documentsProvider.notifier).clearMessages();
      }
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next.error!),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
        ref.read(documentsProvider.notifier).clearMessages();
      }
    });

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── 1. TOP HEADER BAR ───
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: cardBg,
                border: Border(bottom: BorderSide(color: borderCol, width: 1)),
              ),
              child: Row(
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(Icons.arrow_back_rounded, color: textPrimary, size: 22),
                    onPressed: () => safeGoBack(context, dashboardFallback(context)),
                    tooltip: 'Go Back',
                  ),
                  const SizedBox(width: 14),
                  // Header Icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.cloud_upload_outlined, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  // Title & Subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Documents',
                          style: TextStyle(
                            fontFamily: AppFonts.heading,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Store, manage and share important documents securely',
                          style: TextStyle(
                            fontFamily: AppFonts.body,
                            fontSize: 12,
                            color: textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Actions
                  IconButton(
                    icon: Icon(Icons.sync_rounded, color: textMuted, size: 20),
                    tooltip: 'Sync All Cross-Module Documents',
                    onPressed: () => ref.read(documentsProvider.notifier).syncCrossModule(),
                  ),
                  IconButton(
                    icon: Icon(Icons.assignment_outlined, color: textMuted, size: 20),
                    tooltip: 'Request Document',
                    onPressed: () => _showRequestDialog(context),
                  ),
                  IconButton(
                    icon: Icon(Icons.inventory_2_outlined, color: textMuted, size: 20),
                    tooltip: 'Review Document Requests',
                    onPressed: () => _showRequestsManagerDialog(context, state),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh_rounded, color: textMuted, size: 20),
                    tooltip: 'Refresh Repository',
                    onPressed: () => ref.read(documentsProvider.notifier).init(),
                  ),
                  const SizedBox(width: 8),

                  if (state.activeTab == 'trash') ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFDC2626), width: 1.2),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _confirmEmptyTrash(context),
                      icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                      label: const Text('Empty Trash', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Upload Document Button (Royal Blue)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 1,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _showUploadDialog(context, state),
                    icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                    label: const Text(
                      'Upload Document',
                      style: TextStyle(
                        fontFamily: AppFonts.heading,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ─── 2. KPI METRICS CARDS ROW ───
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: DocumentKpiCards(stats: state.stats, isDark: isDark),
            ),

            // ─── 3. HORIZONTAL TABS SWITCHER (6 TABS) ───
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: cardBg,
                border: Border(bottom: BorderSide(color: borderCol, width: 1)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: _tabs.map((tab) {
                    final tabId = tab['id'] as String;
                    final isTabActive = state.activeTab == tabId;
                    return InkWell(
                      onTap: () => ref.read(documentsProvider.notifier).selectTab(tabId),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: isTabActive ? const Color(0xFF2563EB) : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              tab['icon'] as IconData,
                              size: 16,
                              color: isTabActive ? const Color(0xFF2563EB) : textMuted,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              tab['label'] as String,
                              style: TextStyle(
                                fontFamily: AppFonts.heading,
                                fontSize: 13,
                                fontWeight: isTabActive ? FontWeight.w700 : FontWeight.w500,
                                color: isTabActive ? const Color(0xFF2563EB) : textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // ─── 4. MAIN 3-COLUMN WORKSPACE ───
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 1150;

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── LEFT PANEL: Folder Tree ──
                        if (!constraints.maxWidth.isNegative && constraints.maxWidth >= 700) ...[
                          FolderTreePanel(
                            folders: state.folders,
                            activeFolderId: state.activeFolderId,
                            totalDocuments: state.stats.totalDocuments > 0 ? state.stats.totalDocuments : state.totalRecords,
                            stats: state.stats,
                            onFolderSelected: (fId) => ref.read(documentsProvider.notifier).selectFolder(fId),
                            onNewFolder: () => _showNewFolderDialog(context, state),
                            onDeleteFolder: (folder) => ref.read(documentsProvider.notifier).deleteFolder(folder.id),
                            isDark: isDark,
                          ),
                          const SizedBox(width: 14),
                        ],

                        // ── CENTER PANEL: Documents Ledger / Grid / Table ──
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Mobile Folder Selector Bar (when Left Panel is hidden)
                              if (constraints.maxWidth < 700) ...[
                                Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    children: [
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          side: BorderSide(color: borderCol),
                                          backgroundColor: cardBg,
                                        ),
                                        icon: const Icon(Icons.folder_open_rounded, size: 16, color: Color(0xFF2563EB)),
                                        label: Text(
                                          state.activeFolderId != null
                                              ? '📁 ${state.allFoldersFlat.where((f) => f.id == state.activeFolderId).map((f) => f.name).firstOrNull ?? "Selected Folder"}'
                                              : '📁 All Folders',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                                        ),
                                        onPressed: () {
                                          showModalBottomSheet(
                                            context: context,
                                            isScrollControlled: true,
                                            backgroundColor: Colors.transparent,
                                            builder: (ctx) => Container(
                                              height: MediaQuery.of(context).size.height * 0.75,
                                              decoration: BoxDecoration(
                                                color: cardBg,
                                                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                              ),
                                              child: FolderTreePanel(
                                                folders: state.folders,
                                                activeFolderId: state.activeFolderId,
                                                totalDocuments: state.stats.totalDocuments > 0 ? state.stats.totalDocuments : state.totalRecords,
                                                stats: state.stats,
                                                onFolderSelected: (fId) {
                                                  Navigator.of(ctx).pop();
                                                  ref.read(documentsProvider.notifier).selectFolder(fId);
                                                },
                                                onNewFolder: () {
                                                  Navigator.of(ctx).pop();
                                                  _showNewFolderDialog(context, state);
                                                },
                                                onDeleteFolder: (f) {
                                                  Navigator.of(ctx).pop();
                                                  ref.read(documentsProvider.notifier).deleteFolder(f.id);
                                                },
                                                isDark: isDark,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Bulk Action Toolbar (if selected)
                              BulkActionBar(
                                selectedCount: state.selectedDocumentIds.length,
                                isTrashTab: state.activeTab == 'trash',
                                onBulkMove: () {
                                  String? targetFolderId;
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => StatefulBuilder(
                                      builder: (ctx, setDialogState) => AlertDialog(
                                        title: const Text('Move Selected Documents'),
                                        content: AppSearchableDropdownFormField<String?>.fromMenuItems(
                                          decoration: const InputDecoration(labelText: 'Target Folder', border: OutlineInputBorder()),
                                          items: [
                                            const DropdownMenuItem(value: null, child: Text('📁 Root Directory')),
                                            ...state.allFoldersFlat.map((f) => DropdownMenuItem(value: f.id, child: Text('📁 ${f.name}'))),
                                          ],
                                          onChanged: (dest) {
                                            setDialogState(() => targetFolderId = dest);
                                          },
                                        ),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                                            onPressed: () {
                                              Navigator.of(ctx).pop();
                                              ref.read(documentsProvider.notifier).bulkMove(targetFolderId);
                                            },
                                            child: const Text('Confirm Move'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                                onBulkStar: () => ref.read(documentsProvider.notifier).bulkStar(star: true),
                                onBulkDownload: () => ref.read(documentsProvider.notifier).downloadBulkZip(),
                                onBulkTrash: () => ref.read(documentsProvider.notifier).bulkDelete(),
                                onBulkRestore: () => ref.read(documentsProvider.notifier).bulkRestore(),
                                onClear: () => ref.read(documentsProvider.notifier).clearSelection(),
                              ),

                              // Center Toolbar (Search, Type Filter, Dept Filter, View Mode)
                              _buildCenterToolbar(context, state, cardBg, borderCol, textPrimary, textMuted),

                              const SizedBox(height: 12),

                              // Document Content (Grid or Table)
                              Expanded(
                                child: state.isLoading
                                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                                    : state.documents.isEmpty
                                        ? _buildEmptyState(context, state, textPrimary, textMuted)
                                        : state.isGridView
                                            ? _buildGridView(context, state, isDark, isWide)
                                            : _buildTableView(context, state, cardBg, borderCol, textPrimary, textMuted, isWide),
                              ),

                              const SizedBox(height: 12),

                              // Bottom Pagination Controls
                              _buildPaginationBar(context, state, cardBg, borderCol, textPrimary, textMuted),
                            ],
                          ),
                        ),

                        // ── RIGHT PANEL: Document Preview & Details (on Wide Screens) ──
                        if (isWide) ...[
                          const SizedBox(width: 14),
                          DocumentPreviewPanel(
                            document: state.selectedDocument,
                            onDownload: () => state.selectedDocument != null ? _downloadDocument(state.selectedDocument!) : null,
                            onShare: () => state.selectedDocument != null ? _showShareDialog(context, state.selectedDocument!, state) : null,
                            onFullscreen: () => state.selectedDocument != null ? _openFullscreenPreview(context, state.selectedDocument!) : null,
                            onExternalOpen: () => state.selectedDocument != null ? _openInTab(state.selectedDocument!) : null,
                            onOpenGoogleDocs: () => state.selectedDocument != null ? _openLiveEditor(state.selectedDocument!, 'google') : null,
                            onOpenOfficeOnline: () => state.selectedDocument != null ? _openLiveEditor(state.selectedDocument!, 'office') : null,
                            onRestore: () => state.selectedDocument != null ? ref.read(documentsProvider.notifier).restoreDocument(state.selectedDocument!.id) : null,
                            onPermanentDelete: () => state.selectedDocument != null ? _confirmDelete(context, state.selectedDocument!) : null,
                            onApprovalAction: (status, comments) => state.selectedDocument != null
                                ? ref.read(documentsProvider.notifier).reviewApproval(state.selectedDocument!.id, status: status, comments: comments)
                                : null,
                            isDark: isDark,
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Center Toolbar Widget (Responsive with zero overflow) ───
  Widget _buildCenterToolbar(
    BuildContext context,
    DocumentsState state,
    Color cardBg,
    Color borderCol,
    Color textPrimary,
    Color textMuted,
  ) {
    return LayoutBuilder(
      builder: (context, box) {
        final isTight = box.maxWidth < 650;

        final searchField = SizedBox(
          height: 38,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search in Documents...',
              hintStyle: TextStyle(fontFamily: AppFonts.body, fontSize: 12.5, color: textMuted),
              prefixIcon: Icon(Icons.search_rounded, size: 18, color: textMuted),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        _searchController.clear();
                        ref.read(documentsProvider.notifier).setSearchQuery('');
                        setState(() {});
                      },
                    )
                  : null,
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderCol)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderCol)),
            ),
            style: TextStyle(fontFamily: AppFonts.body, fontSize: 12.5, color: textPrimary),
            onSubmitted: (q) => ref.read(documentsProvider.notifier).setSearchQuery(q),
          ),
        );

        final isDark = Theme.of(context).brightness == Brightness.dark;

        final viewModeSwitcher = Container(
          height: 36,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.grid_view_rounded, size: 18, color: state.isGridView ? const Color(0xFF2563EB) : textMuted),
                tooltip: 'Grid View',
                padding: const EdgeInsets.symmetric(horizontal: 8),
                constraints: const BoxConstraints(),
                onPressed: () {
                  if (!state.isGridView) ref.read(documentsProvider.notifier).toggleViewMode();
                },
              ),
              IconButton(
                icon: Icon(Icons.view_list_rounded, size: 20, color: !state.isGridView ? const Color(0xFF2563EB) : textMuted),
                tooltip: 'Table View',
                padding: const EdgeInsets.symmetric(horizontal: 8),
                constraints: const BoxConstraints(),
                onPressed: () {
                  if (state.isGridView) ref.read(documentsProvider.notifier).toggleViewMode();
                },
              ),
            ],
          ),
        );

        final typesDropdown = SizedBox(
          height: 38,
          width: 110,
          child: AppSearchableDropdownFormField<String>.fromMenuItems(
            isExpanded: true,
            initialValue: state.selectedFileType,
            isDense: true,
            dropdownColor: cardBg,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderCol)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderCol)),
            ),
            style: TextStyle(fontFamily: AppFonts.body, fontSize: 12, color: textPrimary),
            items: const [
              DropdownMenuItem(value: 'All', child: Text('All Types', overflow: TextOverflow.ellipsis)),
              DropdownMenuItem(value: 'PDF', child: Text('PDF', overflow: TextOverflow.ellipsis)),
              DropdownMenuItem(value: 'DOCX', child: Text('DOCX', overflow: TextOverflow.ellipsis)),
              DropdownMenuItem(value: 'XLSX', child: Text('XLSX', overflow: TextOverflow.ellipsis)),
              DropdownMenuItem(value: 'JPG', child: Text('JPG / PNG', overflow: TextOverflow.ellipsis)),
              DropdownMenuItem(value: 'PPTX', child: Text('PPTX', overflow: TextOverflow.ellipsis)),
              DropdownMenuItem(value: 'TXT', child: Text('TXT', overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (val) => ref.read(documentsProvider.notifier).setFileTypeFilter(val ?? 'All'),
          ),
        );

        final deptDropdown = SizedBox(
          height: 38,
          width: 135,
          child: AppSearchableDropdownFormField<String>.fromMenuItems(
            isExpanded: true,
            initialValue: state.selectedDepartment,
            isDense: true,
            dropdownColor: cardBg,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderCol)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderCol)),
            ),
            style: TextStyle(fontFamily: AppFonts.body, fontSize: 12, color: textPrimary),
            items: const [
              DropdownMenuItem(value: 'All', child: Text('All Departments', overflow: TextOverflow.ellipsis)),
              DropdownMenuItem(value: 'Academics', child: Text('Academics', overflow: TextOverflow.ellipsis)),
              DropdownMenuItem(value: 'Administration', child: Text('Administration', overflow: TextOverflow.ellipsis)),
              DropdownMenuItem(value: 'Finance', child: Text('Finance', overflow: TextOverflow.ellipsis)),
              DropdownMenuItem(value: 'Examination', child: Text('Examination', overflow: TextOverflow.ellipsis)),
              DropdownMenuItem(value: 'HR Management', child: Text('HR Management', overflow: TextOverflow.ellipsis)),
              DropdownMenuItem(value: 'Hostel', child: Text('Hostel', overflow: TextOverflow.ellipsis)),
              DropdownMenuItem(value: 'Transport', child: Text('Transport', overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (val) => ref.read(documentsProvider.notifier).setDepartmentFilter(val ?? 'All'),
          ),
        );

        final usersDropdown = SizedBox(
          height: 38,
          width: 135,
          child: AppSearchableDropdownFormField<String?>.fromMenuItems(
            isExpanded: true,
            initialValue: (state.selectedOwnerId == 'All' || state.selectedOwnerId.isEmpty) ? null : state.selectedOwnerId,
            isDense: true,
            dropdownColor: cardBg,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderCol)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderCol)),
            ),
            style: TextStyle(fontFamily: AppFonts.body, fontSize: 12, color: textPrimary),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Authors', overflow: TextOverflow.ellipsis)),
              ...state.schoolUsers.map((u) => DropdownMenuItem<String?>(
                    value: u['id']?.toString(),
                    child: Text(u['full_name']?.toString() ?? u['name']?.toString() ?? 'User', overflow: TextOverflow.ellipsis),
                  )),
            ],
            onChanged: (val) => ref.read(documentsProvider.notifier).setOwnerFilter(val),
          ),
        );

        if (isTight) {
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderCol, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: searchField),
                    const SizedBox(width: 8),
                    viewModeSwitcher,
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: typesDropdown),
                    const SizedBox(width: 8),
                    Expanded(child: deptDropdown),
                  ],
                ),
                const SizedBox(height: 8),
                usersDropdown,
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderCol, width: 1),
          ),
          child: Row(
            children: [
              Expanded(child: searchField),
              const SizedBox(width: 8),
              typesDropdown,
              const SizedBox(width: 8),
              deptDropdown,
              const SizedBox(width: 8),
              usersDropdown,
              const SizedBox(width: 8),
              viewModeSwitcher,
            ],
          ),
        );
      },
    );
  }

  void _openPreviewSheet(BuildContext context, DocumentModel doc, DocumentsState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(16),
        child: DocumentPreviewPanel(
          document: doc,
          onDownload: () => _downloadDocument(doc),
          onShare: () {
            Navigator.of(ctx).pop();
            _showShareDialog(context, doc, state);
          },
          onFullscreen: () {
            Navigator.of(ctx).pop();
            _openFullscreenPreview(context, doc);
          },
          onExternalOpen: () => _openInTab(doc),
          onOpenGoogleDocs: () => _openLiveEditor(doc, 'google'),
          onOpenOfficeOnline: () => _openLiveEditor(doc, 'office'),
          onRestore: () {
            Navigator.of(ctx).pop();
            ref.read(documentsProvider.notifier).restoreDocument(doc.id);
          },
          onPermanentDelete: () {
            Navigator.of(ctx).pop();
            _confirmDelete(context, doc);
          },
          onApprovalAction: (status, comments) {
            Navigator.of(ctx).pop();
            ref.read(documentsProvider.notifier).reviewApproval(doc.id, status: status, comments: comments);
          },
          isDark: Theme.of(context).brightness == Brightness.dark,
        ),
      ),
    );
  }

  // ─── Grid View Builder ───
  Widget _buildGridView(BuildContext context, DocumentsState state, bool isDark, bool isWide) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 4;
        double aspect = 1.25;
        if (constraints.maxWidth < 600) {
          crossAxisCount = 1;
          aspect = 2.0;
        } else if (constraints.maxWidth < 800) {
          crossAxisCount = 2;
          aspect = 1.25;
        } else if (constraints.maxWidth < 1100) {
          crossAxisCount = 3;
          aspect = 1.25;
        }

        return GridView.builder(
          physics: const BouncingScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: aspect,
          ),
          itemCount: state.documents.length,
          itemBuilder: (ctx, idx) {
            final doc = state.documents[idx];
            final isSelected = state.selectedDocument?.id == doc.id;
            final isBulkSelected = state.selectedDocumentIds.contains(doc.id);

            return DocumentGridCard(
              document: doc,
              isSelected: isSelected,
              isBulkSelected: isBulkSelected,
              onTap: () {
                ref.read(documentsProvider.notifier).selectDocument(doc);
                if (!isWide) _openPreviewSheet(context, doc, state);
              },
              onPreview: () {
                ref.read(documentsProvider.notifier).selectDocument(doc);
                if (!isWide) _openPreviewSheet(context, doc, state);
              },
              onOpenInTab: () => _openInTab(doc),
              onDownload: () => _downloadDocument(doc),
              onShare: () => _showShareDialog(context, doc, state),
              onToggleStar: () => ref.read(documentsProvider.notifier).toggleFavorite(doc.id),
              onVersions: () => _showVersionHistoryDialog(context, doc, state),
              onRestore: () => ref.read(documentsProvider.notifier).restoreDocument(doc.id),
              onDelete: () => _confirmDelete(context, doc),
              onSelectCheckbox: (_) => ref.read(documentsProvider.notifier).toggleDocumentSelection(doc.id),
              isDark: isDark,
            );
          },
        );
      },
    );
  }

  // ─── Table View Builder ───
  Widget _buildTableView(
    BuildContext context,
    DocumentsState state,
    Color cardBg,
    Color borderCol,
    Color textPrimary,
    Color textMuted,
    bool isWide,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderCol, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
              headingTextStyle: TextStyle(
                fontFamily: AppFonts.heading,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                color: textPrimary,
              ),
              dataTextStyle: TextStyle(
                fontFamily: AppFonts.body,
                fontSize: 12,
                color: textPrimary,
              ),
              sortColumnIndex: (state.sortBy == 'name' ? 1 : (state.sortBy == 'owner' ? 4 : (state.sortBy == 'size' ? 5 : null))),
              sortAscending: state.sortOrder == 'asc',
              dataRowColor: WidgetStateProperty.resolveWith<Color?>((states) {
                if (states.contains(WidgetState.selected)) {
                  return isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFEFF6FF);
                }
                return isDark ? const Color(0xFF0F172A) : Colors.white;
              }),
              border: TableBorder(horizontalInside: BorderSide(color: borderCol, width: 0.5)),
              columns: [
                DataColumn(
                  label: SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: state.documents.isNotEmpty && state.selectedDocumentIds.length == state.documents.length,
                      onChanged: (_) => ref.read(documentsProvider.notifier).toggleSelectAll(),
                      activeColor: const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text('Document Name', style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
                  onSort: (_, asc) => ref.read(documentsProvider.notifier).setSort('name', order: asc ? 'asc' : 'desc'),
                ),
                DataColumn(label: Text('File Type', style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary))),
                DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary))),
                DataColumn(
                  label: Text('Owner', style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
                  onSort: (_, asc) => ref.read(documentsProvider.notifier).setSort('owner', order: asc ? 'asc' : 'desc'),
                ),
                DataColumn(
                  label: Text('File Size', style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
                  onSort: (_, asc) => ref.read(documentsProvider.notifier).setSort('file_size', order: asc ? 'asc' : 'desc'),
                ),
                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary))),
                DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary))),
              ],
              rows: state.documents.map((doc) {
                final isSelected = state.selectedDocument?.id == doc.id;
                return DataRow(
                  selected: isSelected,
                  onSelectChanged: (_) {
                    ref.read(documentsProvider.notifier).selectDocument(doc);
                    if (!isWide) _openPreviewSheet(context, doc, state);
                  },
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          value: state.selectedDocumentIds.contains(doc.id),
                          onChanged: (_) => ref.read(documentsProvider.notifier).toggleDocumentSelection(doc.id),
                          activeColor: const Color(0xFF2563EB),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(doc.fileTypeIcon, color: doc.fileTypeBadgeColor, size: 18),
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 220),
                            child: Text(
                              doc.title,
                              style: TextStyle(fontFamily: AppFonts.heading, fontWeight: FontWeight.w700, color: textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (doc.isStarred) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.star_rounded, size: 15, color: Color(0xFFF59E0B)),
                          ],
                        ],
                      ),
                    ),
                    DataCell(Text(doc.fileType, style: TextStyle(color: textPrimary, fontSize: 12))),
                    DataCell(Text(doc.category.shortLabel, style: TextStyle(color: textPrimary, fontSize: 12))),
                    DataCell(Text(doc.ownerName, style: TextStyle(color: textPrimary, fontSize: 12))),
                    DataCell(Text(doc.fileSizeLabel, style: TextStyle(color: textPrimary, fontSize: 12))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          doc.approvalStatus,
                          style: TextStyle(
                            color: isDark ? const Color(0xFF34D399) : const Color(0xFF16A34A),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (doc.allowDownload)
                            IconButton(
                              icon: const Icon(Icons.download_rounded, size: 16),
                              tooltip: 'Download',
                              onPressed: () => _downloadDocument(doc),
                            ),
                          IconButton(
                            icon: Icon(
                              _isCollaborativeDoc(doc)
                                  ? ((doc.fileType == 'PPTX' || doc.fileType == 'PPT')
                                      ? Icons.slideshow_rounded
                                      : (doc.fileType == 'XLSX' || doc.fileType == 'XLS' || doc.fileType == 'CSV')
                                          ? Icons.table_chart_rounded
                                          : Icons.edit_note_rounded)
                                  : Icons.open_in_new_rounded,
                              size: 16,
                              color: _isCollaborativeDoc(doc)
                                  ? ((doc.fileType == 'PPTX' || doc.fileType == 'PPT')
                                      ? const Color(0xFFF59E0B)
                                      : const Color(0xFF2563EB))
                                  : textMuted,
                            ),
                            tooltip: _isCollaborativeDoc(doc)
                                ? ((doc.fileType == 'PPTX' || doc.fileType == 'PPT')
                                    ? 'Open Collaborative Slides in Tab'
                                    : (doc.fileType == 'XLSX' || doc.fileType == 'XLS' || doc.fileType == 'CSV')
                                        ? 'Open Collaborative Sheet in Tab'
                                        : 'Open Collaborative Document in Tab')
                                : 'Open in Tab',
                            onPressed: () => _openInTab(doc),
                          ),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert_rounded, size: 18, color: textMuted),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'All Actions',
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            onSelected: (val) {
                              switch (val) {
                                case 'preview':
                                  ref.read(documentsProvider.notifier).selectDocument(doc);
                                  if (!isWide) _openPreviewSheet(context, doc, state);
                                  break;
                                case 'open_tab':
                                  _openInTab(doc);
                                  break;
                                case 'collab_editor':
                                  _openCollaborativeEditor(doc);
                                  break;
                                case 'copy_link':
                                  final liveUrl = '${AppConfig.baseUrl}/api/documents/${doc.id}/editor';
                                  Clipboard.setData(ClipboardData(text: liveUrl));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Live Collaborative Editor link copied to clipboard!'),
                                      duration: Duration(seconds: 2),
                                      backgroundColor: Color(0xFF1E293B),
                                    ),
                                  );
                                  break;
                                case 'download':
                                  _downloadDocument(doc);
                                  break;
                                case 'share':
                                  _showShareDialog(context, doc, state);
                                  break;
                                case 'star':
                                  ref.read(documentsProvider.notifier).toggleFavorite(doc.id);
                                  break;
                                case 'versions':
                                  _showVersionHistoryDialog(context, doc, state);
                                  break;
                                case 'restore':
                                  ref.read(documentsProvider.notifier).restoreDocument(doc.id);
                                  break;
                                case 'delete':
                                  _confirmDelete(context, doc);
                                  break;
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'preview',
                                child: Row(children: [Icon(Icons.visibility_outlined, size: 16), SizedBox(width: 8), Text('Preview')]),
                              ),
                              PopupMenuItem(
                                value: 'open_tab',
                                child: Row(children: [
                                  Icon(
                                    _isCollaborativeDoc(doc)
                                        ? ((doc.fileType == 'PPTX' || doc.fileType == 'PPT')
                                            ? Icons.slideshow_rounded
                                            : (doc.fileType == 'XLSX' || doc.fileType == 'XLS' || doc.fileType == 'CSV')
                                                ? Icons.table_chart_rounded
                                                : Icons.edit_note_rounded)
                                        : Icons.open_in_new_rounded,
                                    size: 16,
                                    color: _isCollaborativeDoc(doc)
                                        ? ((doc.fileType == 'PPTX' || doc.fileType == 'PPT')
                                            ? const Color(0xFFF59E0B)
                                            : const Color(0xFF2563EB))
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isCollaborativeDoc(doc)
                                        ? ((doc.fileType == 'PPTX' || doc.fileType == 'PPT')
                                            ? 'Open Collaborative Slides'
                                            : (doc.fileType == 'XLSX' || doc.fileType == 'XLS' || doc.fileType == 'CSV')
                                                ? 'Open Collaborative Sheet'
                                                : 'Open Collaborative Doc')
                                        : 'Open in New Tab',
                                    style: _isCollaborativeDoc(doc)
                                        ? TextStyle(
                                            color: (doc.fileType == 'PPTX' || doc.fileType == 'PPT')
                                                ? const Color(0xFFF59E0B)
                                                : const Color(0xFF2563EB),
                                            fontWeight: FontWeight.w600,
                                          )
                                        : null,
                                  ),
                                ]),
                              ),
                              if (_isCollaborativeDoc(doc))
                                const PopupMenuItem(
                                  value: 'copy_link',
                                  child: Row(children: [
                                    Icon(Icons.link_rounded, size: 16),
                                    SizedBox(width: 8),
                                    Text('Copy Live Editor Link'),
                                  ]),
                                ),
                              if (doc.allowDownload)
                                const PopupMenuItem(
                                  value: 'download',
                                  child: Row(children: [Icon(Icons.download_rounded, size: 16), SizedBox(width: 8), Text('Download')]),
                                ),
                              if (doc.canShare)
                                const PopupMenuItem(
                                  value: 'share',
                                  child: Row(children: [Icon(Icons.share_outlined, size: 16), SizedBox(width: 8), Text('Share')]),
                                ),
                              PopupMenuItem(
                                value: 'star',
                                child: Row(children: [
                                  Icon(doc.isStarred ? Icons.star_border_rounded : Icons.star_rounded, size: 16),
                                  const SizedBox(width: 8),
                                  Text(doc.isStarred ? 'Unstar' : 'Star'),
                                ]),
                              ),
                              const PopupMenuItem(
                                value: 'versions',
                                child: Row(children: [Icon(Icons.history_rounded, size: 16), SizedBox(width: 8), Text('Version History')]),
                              ),
                              if (doc.isDeleted) ...[
                                const PopupMenuDivider(),
                                const PopupMenuItem(
                                  value: 'restore',
                                  child: Row(children: [
                                    Icon(Icons.restore_from_trash_rounded, size: 16, color: Color(0xFF16A34A)),
                                    SizedBox(width: 8),
                                    Text('Restore Document', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w600)),
                                  ]),
                                ),
                              ],
                              if (doc.canDelete) ...[
                                const PopupMenuDivider(),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(children: [
                                    Icon(doc.isDeleted ? Icons.delete_forever_rounded : Icons.delete_outline_rounded, size: 16, color: Colors.red),
                                    const SizedBox(width: 8),
                                    Text(doc.isDeleted ? 'Delete Permanently' : 'Move to Trash', style: const TextStyle(color: Colors.red)),
                                  ]),
                                ),
                              ],
                            ],
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
    );
  }

  // ─── Empty State Widget ───
  Widget _buildEmptyState(
    BuildContext context,
    DocumentsState state,
    Color textPrimary,
    Color textMuted,
  ) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: Color(0xFFEFF6FF), shape: BoxShape.circle),
            child: const Icon(Icons.folder_open_rounded, size: 48, color: Color(0xFF2563EB)),
          ),
          const SizedBox(height: 16),
          Text(
            state.activeTab == 'trash' ? 'Trash is Empty' : 'No Documents Found',
            style: TextStyle(fontFamily: AppFonts.heading, fontSize: 16, fontWeight: FontWeight.w800, color: textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            state.activeTab == 'trash'
                ? 'Deleted documents will appear here before permanent cleanup.'
                : 'Upload or generate documents to start managing institutional files.',
            style: TextStyle(fontFamily: AppFonts.body, fontSize: 12, color: textMuted),
          ),
          const SizedBox(height: 16),
          if (state.activeTab != 'trash')
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              onPressed: () => _showUploadDialog(context, state),
              icon: const Icon(Icons.cloud_upload_rounded, size: 16),
              label: const Text('Upload Document'),
            ),
        ],
      ),
    );
  }

  List<int> _computePageNumbers(int current, int total) {
    if (total <= 5) return List.generate(total, (i) => i + 1);
    int start = (current - 2).clamp(1, total - 4);
    int end = (start + 4).clamp(5, total);
    if (end - start < 4) start = (end - 4).clamp(1, total);
    return List.generate(end - start + 1, (i) => start + i);
  }

  // ─── Bottom Pagination Bar (Deterministic across all pages) ───
  Widget _buildPaginationBar(
    BuildContext context,
    DocumentsState state,
    Color cardBg,
    Color borderCol,
    Color textPrimary,
    Color textMuted,
  ) {
    final startIdx = state.totalRecords > 0 ? ((state.currentPage - 1) * state.pageSize) + 1 : 0;
    final endIdx = (state.currentPage * state.pageSize) > state.totalRecords ? state.totalRecords : (state.currentPage * state.pageSize);
    final visiblePages = _computePageNumbers(state.currentPage, state.totalPages);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderCol, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Range label
          Text(
            'Showing $startIdx - $endIdx of ${state.totalRecords} documents',
            style: TextStyle(fontFamily: AppFonts.body, fontSize: 12, color: textMuted, fontWeight: FontWeight.w500),
          ),

          // Page Buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.keyboard_double_arrow_left_rounded, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: state.currentPage > 1
                    ? () => ref.read(documentsProvider.notifier).loadDocuments(page: state.currentPage - 1)
                    : null,
              ),
              if (visiblePages.isNotEmpty && visiblePages.first > 1) ...[
                InkWell(
                  onTap: () => ref.read(documentsProvider.notifier).loadDocuments(page: 1),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: state.currentPage == 1 ? const Color(0xFF2563EB) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: state.currentPage == 1 ? null : Border.all(color: borderCol),
                    ),
                    child: Center(
                      child: Text(
                        '1',
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: state.currentPage == 1 ? Colors.white : textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
                if (visiblePages.first > 2)
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 3), child: Text('...')),
              ],
              ...visiblePages.map((p) {
                final isCurrent = state.currentPage == p;
                return InkWell(
                  onTap: () => ref.read(documentsProvider.notifier).loadDocuments(page: p),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isCurrent ? const Color(0xFF2563EB) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: isCurrent ? null : Border.all(color: borderCol),
                    ),
                    child: Center(
                      child: Text(
                        '$p',
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isCurrent ? Colors.white : textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              }),
              if (visiblePages.isNotEmpty && visiblePages.last < state.totalPages) ...[
                if (visiblePages.last < state.totalPages - 1)
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 3), child: Text('...')),
                InkWell(
                  onTap: () => ref.read(documentsProvider.notifier).loadDocuments(page: state.totalPages),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: state.currentPage == state.totalPages ? const Color(0xFF2563EB) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: state.currentPage == state.totalPages ? null : Border.all(color: borderCol),
                    ),
                    child: Center(
                      child: Text(
                        '${state.totalPages}',
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: state.currentPage == state.totalPages ? Colors.white : textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              IconButton(
                icon: const Icon(Icons.keyboard_double_arrow_right_rounded, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: state.currentPage < state.totalPages
                    ? () => ref.read(documentsProvider.notifier).loadDocuments(page: state.currentPage + 1)
                    : null,
              ),
            ],
          ),

          // Items per page
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Items per page: ', style: TextStyle(fontFamily: AppFonts.body, fontSize: 11.5, color: textMuted)),
              AppSearchableDropdown<int>.fromMenuItems(
                value: state.pageSize,
                isDense: true,
                dropdownColor: cardBg,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 8, child: Text('8')),
                  DropdownMenuItem(value: 12, child: Text('12')),
                  DropdownMenuItem(value: 24, child: Text('24')),
                  DropdownMenuItem(value: 48, child: Text('48')),
                  DropdownMenuItem(value: 96, child: Text('96')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    ref.read(documentsProvider.notifier).setPageSize(val);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
