import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/models/document_model.dart';
import 'package:edu_shamiit_ai/core/providers/documents_provider.dart';
import 'package:edu_shamiit_ai/core/config/app_config.dart';
import 'package:edu_shamiit_ai/core/providers/auth_provider.dart';
import 'package:edu_shamiit_ai/core/providers/role_provider.dart';
import 'package:edu_shamiit_ai/shared/widgets/azure_grid.dart';
import 'package:edu_shamiit_ai/core/utils/download_helper_stub.dart'
    if (dart.library.js) 'package:edu_shamiit_ai/core/utils/download_helper_web.dart'
    if (dart.library.io) 'package:edu_shamiit_ai/core/utils/download_helper_mobile.dart';

// ─── Color constants ─────────────────────────────────────────────────────────
const _kPrimary = Color(0xFF4F46E5);
const _kSurface = Color(0xFFF8FAFC);
const _kCardBg = Color(0xFFFFFFFF);
const _kText = Color(0xFF0F172A);
const _kSubText = Color(0xFF64748B);
const _kBorder = Color(0xFFE2E8F0);

// Category tab accent colours
const _kCatColors = {
  'ai_generated': Color(0xFF7C3AED),
  'my_uploads': Color(0xFF0EA5E9),
  'teacher_shared': Color(0xFF10B981),
  'chat_shared': Color(0xFFF59E0B),
  'school_notice': Color(0xFFEF4444),
};

Color _catColor(DocumentCategory cat) => _kCatColors[cat.value] ?? _kPrimary;

// ─── Main screen ─────────────────────────────────────────────────────────────

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();

  static const _tabs = [null, ...DocumentCategory.values];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(documentsProvider.notifier).loadDocuments();
    });
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final cat = _tabs[_tabController.index];
    ref.read(documentsProvider.notifier).setCategory(cat);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  IconData _fileIcon(DocumentModel doc) {
    final ext = doc.extension.toLowerCase();
    if (['pdf'].contains(ext)) return Icons.picture_as_pdf_rounded;
    if (['doc', 'docx'].contains(ext)) return Icons.description_rounded;
    if (['xls', 'xlsx', 'csv'].contains(ext)) return Icons.table_chart_rounded;
    if (['ppt', 'pptx'].contains(ext)) return Icons.slideshow_rounded;
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
      return Icons.image_rounded;
    }
    if (['mp4', 'mov', 'avi'].contains(ext)) return Icons.video_file_rounded;
    if (doc.isAiTextDoc) return Icons.smart_toy_rounded;
    return Icons.insert_drive_file_rounded;
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(documentsProvider);

    // Show snackbars on state messages
    ref.listen<DocumentsState>(documentsProvider, (prev, next) {
      if (next.successMessage != null &&
          next.successMessage != prev?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next.successMessage!),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        ref.read(documentsProvider.notifier).clearMessages();
      }
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next.error!),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        ref.read(documentsProvider.notifier).clearMessages();
      }
    });

    return Scaffold(
      backgroundColor: _kSurface,
      body: Column(
        children: [
          _Header(
            onBack: () {
              final auth = ref.read(authProvider);
              final isTeacher = auth.role.value == 'teacher';
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(
                    isTeacher ? '/teacher/dashboard' : '/student/dashboard');
              }
            },
          ),
          _TabBar(
            controller: _tabController,
            state: state,
          ),
          Expanded(
            child: state.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _kPrimary),
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    child: AzureGrid<DocumentModel>(
                      title: 'Documents Ledger',
                      items: state.documents,
                      onRefresh: () =>
                          ref.read(documentsProvider.notifier).loadDocuments(),
                      extraCommandActions: [
                        IconButton(
                          icon: const Icon(Icons.upload_rounded,
                              color: _kPrimary),
                          tooltip: 'Upload Document',
                          onPressed: _showUploadSheet,
                        ),
                      ],
                      searchMatcher: (item) =>
                          '${item.title} ${item.fileName ?? ""} ${item.description ?? ""} ${item.category.label}',
                      filters: [
                        AzureGridFilter<DocumentModel>(
                          label: 'Category',
                          options: DocumentCategory.values
                              .map((e) => e.label)
                              .toList(),
                          filterFn: (item, option) =>
                              item.category.label == option,
                        ),
                      ],
                      columns: [
                        AzureGridColumn<DocumentModel>(
                          label: 'Title & Description',
                          width: 250,
                          compare: (a, b) => a.title.compareTo(b.title),
                          cellBuilder: (item) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                item.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (item.description != null &&
                                  item.description!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  item.description!,
                                  style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 10),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        AzureGridColumn<DocumentModel>(
                          label: 'File Name',
                          width: 180,
                          compare: (a, b) =>
                              (a.fileName ?? '').compareTo(b.fileName ?? ''),
                          cellBuilder: (item) => Row(
                            children: [
                              Icon(_fileIcon(item),
                                  size: 14, color: _catColor(item.category)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  item.fileName ?? '-',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AzureGridColumn<DocumentModel>(
                          label: 'Category',
                          width: 130,
                          compare: (a, b) =>
                              a.category.label.compareTo(b.category.label),
                          cellBuilder: (item) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _catColor(item.category)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.category.shortLabel,
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: _catColor(item.category),
                              ),
                            ),
                          ),
                        ),
                        AzureGridColumn<DocumentModel>(
                          label: 'Size',
                          width: 90,
                          compare: (a, b) =>
                              a.fileSizeLabel.compareTo(b.fileSizeLabel),
                          cellBuilder: (item) => Text(item.fileSizeLabel.isEmpty
                              ? '-'
                              : item.fileSizeLabel),
                        ),
                        AzureGridColumn<DocumentModel>(
                          label: 'Created At',
                          width: 120,
                          compare: (a, b) => a.createdAt.compareTo(b.createdAt),
                          cellBuilder: (item) =>
                              Text(_formatDate(item.createdAt)),
                        ),
                        AzureGridColumn<DocumentModel>(
                          label: 'Actions',
                          width: 120,
                          cellBuilder: (item) => Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.download_rounded,
                                    size: 16, color: _kPrimary),
                                onPressed: () => _downloadDocument(item),
                                tooltip: 'Download',
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 16, color: Color(0xFFEF4444)),
                                onPressed: () => _deleteDocument(item),
                                tooltip: 'Delete',
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                              ),
                            ],
                          ),
                        ),
                      ],
                      mobileCardBuilder: (context, item) => _DocumentCard(
                        doc: item,
                        onDownload: _downloadDocument,
                        onDelete: _deleteDocument,
                      ),
                    ),
                  ),
          ),
          if (state.isUploading)
            Container(
              color: Colors.black26,
              padding: const EdgeInsets.all(16),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: _kPrimary),
                  SizedBox(width: 16),
                  Text('Uploading…',
                      style: TextStyle(fontFamily: AppFonts.body)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _downloadDocument(DocumentModel doc) async {
    try {
      final url = doc.fileUrl;
      if (url != null &&
          (url.contains('/live-classes/play/') || url.contains('/play/'))) {
        final uri = Uri.parse(url);
        final pathSegments = uri.pathSegments;
        final classId = pathSegments.isNotEmpty ? pathSegments.last : '';
        if (classId.isNotEmpty) {
          final auth = ref.read(authProvider);
          final isTeacher = auth.role.value == 'teacher';
          final targetRoute = isTeacher
              ? '/teacher/live-classes/play/$classId'
              : '/student/live-classes/play/$classId';
          context.go(targetRoute);
          return;
        }
      }
      final downloadUrl = doc.isFileBacked
          ? doc.fileUrl!
          : '${AppConfig.apiBaseUrl}/documents/${doc.id}/download';
      await getDownloadHelper()
          .downloadFile(downloadUrl, doc.fileName ?? 'document');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _deleteDocument(DocumentModel doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Document?',
            style: TextStyle(
                fontFamily: AppFonts.heading, fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to delete "${doc.title}"?',
            style: const TextStyle(fontFamily: AppFonts.body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _kSubText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(documentsProvider.notifier).deleteDocument(doc.id);
    }
  }

  void _showUploadSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _UploadSheet(
        onUpload: (bytes, filename, title, desc) async {
          Navigator.pop(ctx);
          await ref.read(documentsProvider.notifier).uploadDocument(
                bytes: bytes,
                filename: filename,
                title: title,
                description: desc,
              );
        },
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final VoidCallback onBack;

  const _Header({
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.fromLTRB(
          12, MediaQuery.of(context).padding.top + 16, 20, 16),
      child: Row(
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: onBack,
          ),
          const SizedBox(width: 8),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child:
                const Icon(Icons.folder_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Documents',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'All your documents in one place',
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tab bar ─────────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  final TabController controller;
  final DocumentsState state;

  const _TabBar({required this.controller, required this.state});

  @override
  Widget build(BuildContext context) {
    final tabs = [null, ...DocumentCategory.values];
    return Container(
      color: _kCardBg,
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelStyle: const TextStyle(
            fontFamily: AppFonts.heading,
            fontWeight: FontWeight.w700,
            fontSize: 12),
        unselectedLabelStyle: const TextStyle(
            fontFamily: AppFonts.body,
            fontWeight: FontWeight.w500,
            fontSize: 12),
        labelColor: _kPrimary,
        unselectedLabelColor: _kSubText,
        indicatorColor: _kPrimary,
        indicatorWeight: 3,
        dividerColor: _kBorder,
        tabs: tabs.map((cat) {
          final count =
              cat == null ? state.documents.length : state.countFor(cat);
          final label = cat == null ? '📁 All' : cat.label;
          return Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: cat == null ? _kPrimary : _catColor(cat),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        fontFamily: AppFonts.heading,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Document Grid ───────────────────────────────────────────────────────────

class _DocumentGrid extends StatelessWidget {
  final List<DocumentModel> documents;
  final void Function(DocumentModel) onDownload;
  final void Function(DocumentModel) onDelete;

  const _DocumentGrid({
    required this.documents,
    required this.onDownload,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 700;
    return RefreshIndicator(
      color: _kPrimary,
      onRefresh: () async {},
      child: isWide
          ? GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 340,
                mainAxisExtent: 200,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: documents.length,
              itemBuilder: (ctx, i) => _DocumentCard(
                doc: documents[i],
                onDownload: onDownload,
                onDelete: onDelete,
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: documents.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) => _DocumentCard(
                doc: documents[i],
                onDownload: onDownload,
                onDelete: onDelete,
              ),
            ),
    );
  }
}

// ─── Document Card ────────────────────────────────────────────────────────────

class _DocumentCard extends StatefulWidget {
  final DocumentModel doc;
  final void Function(DocumentModel) onDownload;
  final void Function(DocumentModel) onDelete;

  const _DocumentCard({
    required this.doc,
    required this.onDownload,
    required this.onDelete,
  });

  @override
  State<_DocumentCard> createState() => _DocumentCardState();
}

class _DocumentCardState extends State<_DocumentCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 120), vsync: this);
    _scaleAnim = Tween(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _ext {
    if (widget.doc.isAiTextDoc) return 'AI';
    return widget.doc.extension;
  }

  Color get _accentColor => _catColor(widget.doc.category);

  IconData get _fileIcon {
    final ext = widget.doc.extension.toLowerCase();
    if (['pdf'].contains(ext)) return Icons.picture_as_pdf_rounded;
    if (['doc', 'docx'].contains(ext)) return Icons.description_rounded;
    if (['xls', 'xlsx', 'csv'].contains(ext)) return Icons.table_chart_rounded;
    if (['ppt', 'pptx'].contains(ext)) return Icons.slideshow_rounded;
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
      return Icons.image_rounded;
    }
    if (['mp4', 'mov', 'avi'].contains(ext)) return Icons.video_file_rounded;
    if (widget.doc.isAiTextDoc) return Icons.smart_toy_rounded;
    return Icons.insert_drive_file_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.doc;
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onDownload(doc);
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) =>
            Transform.scale(scale: _scaleAnim.value, child: child),
        child: Container(
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top coloured band with file icon
              Container(
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _accentColor.withValues(alpha: 0.12),
                      _accentColor.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_fileIcon, color: _accentColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _accentColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _ext,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              fontFamily: AppFonts.heading,
                            ),
                          ),
                        ),
                        if (doc.fileSizeLabel.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            doc.fileSizeLabel,
                            style: TextStyle(
                              color: _accentColor,
                              fontSize: 11,
                              fontFamily: AppFonts.body,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const Spacer(),
                    // Category chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _kBorder),
                      ),
                      child: Text(
                        doc.category.shortLabel,
                        style: TextStyle(
                          color: _accentColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          fontFamily: AppFonts.heading,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppFonts.heading,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: _kText,
                        ),
                      ),
                      if (doc.description != null &&
                          doc.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          doc.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppFonts.body,
                            fontSize: 11,
                            color: _kSubText,
                          ),
                        ),
                      ],
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(Icons.schedule_rounded,
                              size: 12, color: _kSubText),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(doc.createdAt),
                            style: const TextStyle(
                              fontFamily: AppFonts.body,
                              fontSize: 11,
                              color: _kSubText,
                            ),
                          ),
                          const Spacer(),
                          // Download button
                          _IconBtn(
                            icon: Icons.download_rounded,
                            color: _kPrimary,
                            tooltip: 'Download',
                            onTap: () => widget.onDownload(doc),
                          ),
                          const SizedBox(width: 6),
                          // Delete button (owner only — we show it; backend enforces)
                          _IconBtn(
                            icon: Icons.delete_outline_rounded,
                            color: const Color(0xFFEF4444),
                            tooltip: 'Delete',
                            onTap: () => widget.onDelete(doc),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final DocumentCategory? category;
  final VoidCallback onUpload;

  const _EmptyState({required this.onUpload}) : category = null;

  @override
  Widget build(BuildContext context) {
    final label = category?.label ?? 'documents';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(Icons.folder_open_rounded,
                size: 48, color: _kPrimary),
          ),
          const SizedBox(height: 20),
          Text(
            'No $label yet',
            style: const TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _kText,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Documents will appear here once they\nare saved or shared with you.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: AppFonts.body,
                fontSize: 14,
                color: _kSubText,
                height: 1.5),
          ),
          if (category == null || category == DocumentCategory.myUploads) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onUpload,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: const Icon(Icons.upload_rounded,
                  color: Colors.white, size: 18),
              label: const Text(
                'Upload Document',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: AppFonts.heading,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Upload bottom sheet ──────────────────────────────────────────────────────

class _UploadSheet extends StatefulWidget {
  final Future<void> Function(
      List<int> bytes, String filename, String title, String desc) onUpload;

  const _UploadSheet({required this.onUpload});

  @override
  State<_UploadSheet> createState() => _UploadSheetState();
}

class _UploadSheetState extends State<_UploadSheet> {
  List<int>? _pickedBytes;
  String _pickedFileName = '';
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  bool _uploading = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _pickedBytes = result.files.single.bytes;
        _pickedFileName = result.files.single.name;
        if (_titleController.text.isEmpty) {
          _titleController.text =
              result.files.single.name.replaceAll(RegExp(r'\.[^.]+$'), '');
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Upload Document',
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _kText,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Upload PDFs, docs, images, or any file',
            style: TextStyle(
                fontFamily: AppFonts.body, fontSize: 13, color: _kSubText),
          ),
          const SizedBox(height: 20),
          // File picker
          GestureDetector(
            onTap: _pickFile,
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                color:
                    _pickedBytes != null ? const Color(0xFFEEF2FF) : _kSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _pickedBytes != null ? _kPrimary : _kBorder,
                  style: _pickedBytes != null
                      ? BorderStyle.solid
                      : BorderStyle.solid,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _pickedBytes != null
                        ? Icons.insert_drive_file_rounded
                        : Icons.upload_file_rounded,
                    color: _pickedBytes != null ? _kPrimary : _kSubText,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      _pickedBytes != null
                          ? _pickedFileName
                          : 'Tap to select a file',
                      style: TextStyle(
                        fontFamily: AppFonts.body,
                        fontSize: 14,
                        color: _pickedBytes != null ? _kPrimary : _kSubText,
                        fontWeight: _pickedBytes != null
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: _inputDec('Document Title', Icons.title_rounded),
            style: const TextStyle(fontFamily: AppFonts.body),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            decoration:
                _inputDec('Description (optional)', Icons.notes_rounded),
            style: const TextStyle(fontFamily: AppFonts.body),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _uploading || _pickedBytes == null
                  ? null
                  : () async {
                      if (_titleController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a title')),
                        );
                        return;
                      }
                      setState(() => _uploading = true);
                      await widget.onUpload(
                        _pickedBytes!,
                        _pickedFileName,
                        _titleController.text.trim(),
                        _descController.text.trim(),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                disabledBackgroundColor: _kBorder,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _uploading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Upload',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: AppFonts.heading,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDec(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
          fontFamily: AppFonts.body, fontSize: 14, color: _kSubText),
      prefixIcon: Icon(icon, size: 18, color: _kSubText),
      filled: true,
      fillColor: _kSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kPrimary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}
