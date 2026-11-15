import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../config/app_config.dart';
import '../../../constants/app_fonts.dart';
import '../../../models/document_model.dart';

class DocumentGridCard extends StatelessWidget {
  final DocumentModel document;
  final bool isSelected;
  final bool isBulkSelected;
  final VoidCallback onTap;
  final VoidCallback onPreview;
  final VoidCallback? onOpenInTab;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  final VoidCallback onToggleStar;
  final VoidCallback onVersions;
  final VoidCallback onDelete;
  final VoidCallback? onRestore;
  final ValueChanged<bool?> onSelectCheckbox;
  final bool isDark;

  const DocumentGridCard({
    super.key,
    required this.document,
    required this.isSelected,
    required this.isBulkSelected,
    required this.onTap,
    required this.onPreview,
    this.onOpenInTab,
    required this.onDownload,
    required this.onShare,
    required this.onToggleStar,
    required this.onVersions,
    required this.onDelete,
    this.onRestore,
    required this.onSelectCheckbox,
    this.isDark = false,
  });

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final m = months[dt.month - 1];
    final day = dt.day < 10 ? '0${dt.day}' : '${dt.day}';
    return '$m $day, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark
        ? (isSelected ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFF1E293B))
        : (isSelected ? const Color(0xFFF0F7FF) : Colors.white);

    final borderCol = isSelected
        ? const Color(0xFF2563EB)
        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));

    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderCol, width: isSelected ? 2 : 1),
          boxShadow: [
            BoxShadow(
              color: isSelected ? const Color(0xFF2563EB).withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.02),
              blurRadius: isSelected ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ── Top Row: File Type Badge & Actions ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // File Type Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: document.fileTypeBadgeColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    document.fileType,
                    style: const TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (document.isStarred)
                      const Padding(
                        padding: EdgeInsets.only(right: 2),
                        child: Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
                      ),
                    // Multi-select Checkbox
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: Checkbox(
                        value: isBulkSelected,
                        onChanged: onSelectCheckbox,
                        activeColor: const Color(0xFF2563EB),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // More Menu
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded, size: 18, color: textMuted),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Actions',
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      onSelected: (val) {
                        switch (val) {
                          case 'preview': onPreview(); break;
                          case 'open_in_tab': onOpenInTab?.call(); break;
                          case 'collab_editor': onOpenInTab?.call(); break;
                          case 'copy_link':
                            final liveUrl = '${AppConfig.baseUrl}/api/documents/${document.id}/editor';
                            Clipboard.setData(ClipboardData(text: liveUrl));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Live Collaborative Editor link copied to clipboard!'),
                                duration: Duration(seconds: 2),
                                backgroundColor: Color(0xFF1E293B),
                              ),
                            );
                            break;
                          case 'download': onDownload(); break;
                          case 'share': onShare(); break;
                          case 'star': onToggleStar(); break;
                          case 'versions': onVersions(); break;
                          case 'restore': onRestore?.call(); break;
                          case 'delete': onDelete(); break;
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'preview',
                          child: Row(children: [Icon(Icons.visibility_outlined, size: 16), SizedBox(width: 8), Text('Preview')]),
                        ),
                        if (onOpenInTab != null)
                          PopupMenuItem(
                            value: 'open_in_tab',
                            child: Row(children: [
                              Icon(
                                (document.fileType == 'PPTX' || document.fileType == 'PPT')
                                    ? Icons.slideshow_rounded
                                    : (document.fileType == 'XLSX' || document.fileType == 'XLS' || document.fileType == 'CSV' || document.fileType == 'DOCX' || document.fileType == 'DOC')
                                        ? Icons.edit_note_rounded
                                        : Icons.open_in_new_rounded,
                                size: 16,
                                color: (document.fileType == 'PPTX' || document.fileType == 'PPT')
                                    ? const Color(0xFFF59E0B)
                                    : ((document.fileType == 'XLSX' || document.fileType == 'XLS' || document.fileType == 'CSV' || document.fileType == 'DOCX' || document.fileType == 'DOC')
                                        ? const Color(0xFF2563EB)
                                        : null),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                (document.fileType == 'PPTX' || document.fileType == 'PPT')
                                    ? 'Open Collaborative Slides'
                                    : (document.fileType == 'XLSX' || document.fileType == 'XLS' || document.fileType == 'CSV')
                                        ? 'Open Collaborative Sheet'
                                        : (document.fileType == 'DOCX' || document.fileType == 'DOC')
                                            ? 'Open Collaborative Doc'
                                            : 'Open in New Tab',
                                style: (document.fileType == 'PPTX' || document.fileType == 'PPT')
                                    ? const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.w600)
                                    : ((document.fileType == 'XLSX' || document.fileType == 'XLS' || document.fileType == 'CSV' || document.fileType == 'DOCX' || document.fileType == 'DOC')
                                        ? const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w600)
                                        : null),
                              ),
                            ]),
                          ),
                        if (document.fileType == 'XLSX' || document.fileType == 'XLS' || document.fileType == 'CSV' || document.fileType == 'DOCX' || document.fileType == 'DOC' || document.fileType == 'PPTX' || document.fileType == 'PPT')
                          const PopupMenuItem(
                            value: 'copy_link',
                            child: Row(children: [
                              Icon(Icons.link_rounded, size: 16),
                              SizedBox(width: 8),
                              Text('Copy Live Editor Link'),
                            ]),
                          ),
                        if (document.allowDownload)
                          const PopupMenuItem(
                            value: 'download',
                            child: Row(children: [Icon(Icons.download_rounded, size: 16), SizedBox(width: 8), Text('Download')]),
                          ),
                        if (document.canShare)
                          const PopupMenuItem(
                            value: 'share',
                            child: Row(children: [Icon(Icons.share_outlined, size: 16), SizedBox(width: 8), Text('Share')]),
                          ),
                        PopupMenuItem(
                          value: 'star',
                          child: Row(children: [
                            Icon(document.isStarred ? Icons.star_border_rounded : Icons.star_rounded, size: 16),
                            const SizedBox(width: 8),
                            Text(document.isStarred ? 'Unstar' : 'Star')
                          ]),
                        ),
                        const PopupMenuItem(
                          value: 'versions',
                          child: Row(children: [Icon(Icons.history_rounded, size: 16), SizedBox(width: 8), Text('Version History')]),
                        ),
                        if (document.isDeleted && onRestore != null) ...[
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
                        if (document.canDelete) ...[
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(children: [
                              Icon(document.isDeleted ? Icons.delete_forever_rounded : Icons.delete_outline_rounded, size: 16, color: Colors.red),
                              const SizedBox(width: 8),
                              Text(document.isDeleted ? 'Delete Permanently' : 'Move to Trash', style: const TextStyle(color: Colors.red))
                            ]),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 8),

            // ── Document Title ──
            Text(
              document.title,
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: textPrimary,
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 4),

            // ── Metadata: Extension & Size ──
            Text(
              '${document.fileType} • ${document.fileSizeLabel.isNotEmpty ? document.fileSizeLabel : "2.4 MB"}',
              style: TextStyle(
                fontFamily: AppFonts.body,
                fontSize: 11,
                color: textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 8),

            // ── Bottom Row: Calendar icon + Date ──
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 12, color: textMuted),
                const SizedBox(width: 5),
                Text(
                  _formatDate(document.createdAt),
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 11,
                    color: textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
