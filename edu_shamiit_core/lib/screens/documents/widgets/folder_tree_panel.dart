import 'package:flutter/material.dart';
import '../../../constants/app_fonts.dart';
import '../../../models/document_model.dart';

class FolderTreePanel extends StatefulWidget {
  final List<FolderModel> folders;
  final String? activeFolderId;
  final int totalDocuments;
  final DocumentStatsModel stats;
  final ValueChanged<String?> onFolderSelected;
  final VoidCallback onNewFolder;
  final ValueChanged<FolderModel>? onDeleteFolder;
  final bool isDark;

  const FolderTreePanel({
    super.key,
    required this.folders,
    required this.activeFolderId,
    required this.totalDocuments,
    required this.stats,
    required this.onFolderSelected,
    required this.onNewFolder,
    this.onDeleteFolder,
    this.isDark = false,
  });

  @override
  State<FolderTreePanel> createState() => _FolderTreePanelState();
}

class _FolderTreePanelState extends State<FolderTreePanel> {
  final Set<String> _expandedFolderIds = {};

  @override
  void initState() {
    super.initState();
    _expandAllFoldersWithChildren(widget.folders);
  }

  @override
  void didUpdateWidget(covariant FolderTreePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.folders != widget.folders) {
      _expandAllFoldersWithChildren(widget.folders);
    }
  }

  void _expandAllFoldersWithChildren(List<FolderModel> list) {
    for (final f in list) {
      if (f.children.isNotEmpty) {
        _expandedFolderIds.add(f.id);
        _expandAllFoldersWithChildren(f.children);
      }
    }
  }

  void _toggleExpand(String folderId) {
    setState(() {
      if (_expandedFolderIds.contains(folderId)) {
        _expandedFolderIds.remove(folderId);
      } else {
        _expandedFolderIds.add(folderId);
      }
    });
  }

  void _confirmDeleteFolder(BuildContext context, FolderModel folder) {
    final isEmpty = folder.documentCount == 0 && folder.children.isEmpty;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${folder.name}"?'),
        content: Text(
          isEmpty
              ? 'This folder is empty. Are you sure you want to delete it?'
              : 'This folder contains ${folder.documentCount} items. Deleting it will reassign its contents to the parent folder.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.onDeleteFolder?.call(folder);
            },
            child: const Text('Delete Folder'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = widget.isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderCol = widget.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = widget.isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCol, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Header: Folders & + New Folder ───
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Folders',
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
                const SizedBox(width: 6),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: widget.isDark ? const Color(0xFF334155) : const Color(0xFFEFF6FF),
                    foregroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: widget.onNewFolder,
                  icon: const Icon(Icons.add_rounded, size: 13),
                  label: const Text(
                    'New Folder',
                    style: TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

          // ─── Folder Tree Scrollable List ───
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              children: [
                // All Documents root item
                _buildFolderRow(
                  folder: null,
                  depth: 0,
                  name: 'All Documents',
                  count: widget.totalDocuments,
                  isSelected: widget.activeFolderId == null,
                  icon: Icons.folder_rounded,
                  iconColor: const Color(0xFF2563EB),
                  onTap: () => widget.onFolderSelected(null),
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                  isRootAll: true,
                ),
                const SizedBox(height: 4),

                // Dynamic Recursive Folders from Database
                ...widget.folders.map((folder) => _buildFolderNode(folder, 0, textPrimary, textMuted)),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

          // ─── Storage Usage Progress Gauge ───
          _buildStorageUsageFooter(textPrimary, textMuted),
        ],
      ),
    );
  }

  // ─── Recursive Node Builder (Supports Arbitrary Nesting Depth) ───
  Widget _buildFolderNode(FolderModel folder, int depth, Color textPrimary, Color textMuted) {
    final isExpanded = _expandedFolderIds.contains(folder.id);
    final isSelected = widget.activeFolderId == folder.id;
    final hasChildren = folder.children.isNotEmpty;

    // Distinguish folder colors by depth
    Color derivedColor = folder.color;
    if (depth == 1) {
      derivedColor = const Color(0xFFEAB308); // Amber yellow for subfolder
    } else if (depth >= 2) {
      derivedColor = const Color(0xFFF97316); // Orange for deep nested subfolder
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFolderRow(
          folder: folder,
          depth: depth,
          name: folder.name,
          count: folder.totalTreeCount > 0 ? folder.totalTreeCount : folder.documentCount,
          isSelected: isSelected,
          icon: folder.iconData,
          iconColor: derivedColor,
          hasChildren: hasChildren,
          isExpanded: isExpanded,
          onTap: () => widget.onFolderSelected(folder.id),
          onToggleExpand: hasChildren ? () => _toggleExpand(folder.id) : null,
          textPrimary: textPrimary,
          textMuted: textMuted,
        ),
        if (hasChildren && isExpanded)
          ...folder.children.map((child) => _buildFolderNode(child, depth + 1, textPrimary, textMuted)),
      ],
    );
  }

  Widget _buildFolderRow({
    required FolderModel? folder,
    int depth = 0,
    required String name,
    required int count,
    required bool isSelected,
    required IconData icon,
    required Color iconColor,
    bool hasChildren = false,
    bool isExpanded = false,
    bool isRootAll = false,
    required VoidCallback onTap,
    VoidCallback? onToggleExpand,
    required Color textPrimary,
    required Color textMuted,
  }) {
    final isEmpty = folder != null && count == 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 1.5),
        padding: EdgeInsets.only(
          left: 6.0 + (depth * 14.0),
          right: 6,
          top: depth > 0 ? 5 : 6.5,
          bottom: depth > 0 ? 5 : 6.5,
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: const Color(0xFFBFDBFE), width: 1) : null,
        ),
        child: Row(
          children: [
            // Expand/Collapse arrow
            if (hasChildren)
              GestureDetector(
                onTap: onToggleExpand,
                child: Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: Icon(
                    isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                    size: 16,
                    color: textMuted,
                  ),
                ),
              )
            else if (!isRootAll)
              const SizedBox(width: 14),

            Icon(
              icon,
              size: depth > 0 ? 15 : 17,
              color: isSelected ? const Color(0xFF2563EB) : iconColor,
            ),
            const SizedBox(width: 7),

            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: depth > 0 ? 11.5 : 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? const Color(0xFF2563EB) : textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Document Count Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : (widget.isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : textMuted,
                ),
              ),
            ),

            // Quick Delete Button for Empty Folders
            if (isEmpty && widget.onDeleteFolder != null) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: () => _confirmDeleteFolder(context, folder),
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFEF4444)),
                ),
              ),
            ],

            // Folder Context Options (More)
            if (folder != null && !isRootAll) ...[
              const SizedBox(width: 2),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                iconSize: 15,
                tooltip: 'Folder Options',
                constraints: const BoxConstraints(),
                icon: Icon(Icons.more_vert_rounded, size: 14, color: textMuted.withValues(alpha: 0.7)),
                onSelected: (action) {
                  if (action == 'new_subfolder') {
                    widget.onNewFolder();
                  } else if (action == 'delete') {
                    _confirmDeleteFolder(context, folder);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'new_subfolder',
                    height: 32,
                    child: Row(
                      children: [
                        Icon(Icons.create_new_folder_outlined, size: 15, color: Color(0xFF2563EB)),
                        SizedBox(width: 8),
                        Text('New Subfolder', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    height: 32,
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFDC2626)),
                        const SizedBox(width: 8),
                        Text(
                          isEmpty ? 'Delete Empty Folder' : 'Delete Folder',
                          style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Storage Usage Footer with Circular Progress ───
  Widget _buildStorageUsageFooter(Color textPrimary, Color textMuted) {
    final usedLabel = widget.stats.storageUsedLabel.isNotEmpty ? widget.stats.storageUsedLabel : '0 MB';
    final quotaLabel = widget.stats.storageQuotaLabel.isNotEmpty ? widget.stats.storageQuotaLabel : '5 GB';
    final pct = (widget.stats.storagePercentage / 100).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Storage Usage',
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Circular progress indicator
              SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: pct,
                      strokeWidth: 4,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0D9488)),
                    ),
                    Text(
                      '${widget.stats.storagePercentage}%',
                      style: TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      usedLabel,
                      style: TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      'of $quotaLabel',
                      style: TextStyle(
                        fontFamily: AppFonts.body,
                        fontSize: 10.5,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
