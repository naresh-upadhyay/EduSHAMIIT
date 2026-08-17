import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/notice_provider.dart';
import 'dialogs/bulk_upload_notice_dialog.dart';
import 'dialogs/create_edit_notice_dialog.dart';
import 'dialogs/notice_categories_dialog.dart';

class NoticeHeaderBar extends ConsumerWidget {
  final String userRole;
  final VoidCallback? onRefresh;

  const NoticeHeaderBar({
    super.key,
    required this.userRole,
    this.onRefresh,
  });

  bool get canCreateNotice {
    final r = userRole.toLowerCase();
    return r == 'super_admin' ||
        r == 'admin' ||
        r == 'principal' ||
        r == 'vice_principal' ||
        r == 'director' ||
        r == 'teacher' ||
        r == 'class_teacher' ||
        r == 'transport_manager' ||
        r == 'hr' ||
        r == 'accountant' ||
        r == 'librarian';
  }

  bool get canManageCategories {
    final r = userRole.toLowerCase();
    return r == 'super_admin' || r == 'admin' || r == 'principal' || r == 'director';
  }

  void _downloadSampleTemplate() {
    const csvContent =
        "title,content,category,priority,status,target_scope,target_roles,target_classes,requires_acknowledgement,is_urgent\n"
        "Annual Sports Day Announcement,All students and staff are invited to participate in the Annual Sports Meet.,Event,high,published,entire_institute,,,true,false\n"
        "Parent Teacher Meeting Notice,Term-1 Parent Teacher Meeting will be conducted this Saturday.,Meeting,normal,published,roles,\"parent,teacher\",,false,false\n"
        "Class 10 Revision Schedule,Extra revision classes schedule for Class 10 Board Examinations.,Academic,high,published,classes,,\"10A, 10B\",true,false\n";

    final uri = Uri.dataFromString(
      csvContent,
      mimeType: 'text/csv',
      encoding: utf8,
    );
    launchUrl(uri);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          // Title & Subtitle
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Notices & Circulars',
                style: TextStyle(
                  fontSize: isMobile ? 20 : 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Create, manage and publish notices and circulars to the right audience.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),

          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Refresh Button
              IconButton(
                onPressed: onRefresh ?? () => ref.read(noticeProvider.notifier).refreshAll(),
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: 'Refresh Notices',
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.all(10),
                ),
              ),
              const SizedBox(width: 8),

              // Manage Categories Button (Admin/Principal)
              if (canManageCategories) ...[
                OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => const NoticeCategoriesDialog(),
                    );
                  },
                  icon: const Icon(Icons.category_outlined, size: 16),
                  label: const Text('Categories'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
                    side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // + Create Notice Primary Dropdown Button
              if (canCreateNotice)
                PopupMenuButton<String>(
                  offset: const Offset(0, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  onSelected: (value) {
                    if (value == 'create' || value == 'notice') {
                      showDialog(
                        context: context,
                        builder: (ctx) => const CreateEditNoticeDialog(),
                      );
                    } else if (value == 'bulk') {
                      showDialog(
                        context: context,
                        builder: (ctx) => const BulkUploadNoticeDialog(),
                      );
                    } else if (value == 'export_template') {
                      _downloadSampleTemplate();
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'create',
                      child: Row(
                        children: const [
                          Icon(Icons.edit_note_rounded, size: 18, color: Color(0xFF4F46E5)),
                          SizedBox(width: 10),
                          Text('Create Notice / Circular', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'bulk',
                      child: Row(
                        children: const [
                          Icon(Icons.upload_file_rounded, size: 18, color: Color(0xFF10B981)),
                          SizedBox(width: 10),
                          Text('Upload Notice (Bulk)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'export_template',
                      child: Row(
                        children: const [
                          Icon(Icons.file_download_outlined, size: 18, color: Color(0xFFF59E0B)),
                          SizedBox(width: 10),
                          Text('Export Sample Template (.csv)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                  child: ElevatedButton.icon(
                    onPressed: null, // Handled by PopupMenuButton child tap
                    icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'Create Notice',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down, size: 18, color: Colors.white70),
                      ],
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF4F46E5),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 1,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
