import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/member_provider.dart';
import 'dialogs/add_member_dialog.dart';
import 'dialogs/import_members_dialog.dart';
import 'dialogs/bulk_members_dialog.dart';
import 'package:edu_shamiit_core/utils/responsive.dart';
import 'package:edu_shamiit_core/providers/role_provider.dart';

class MemberHeaderBar extends ConsumerWidget {
  const MemberHeaderBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(memberProvider);
    final notifier = ref.read(memberProvider.notifier);
    final isLibraryAdmin = ref.watch(isLibraryAdminProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = Responsive.isDesktop(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 16,
        vertical: 18,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Title & Subtitle (Left)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Members',
                      style: TextStyle(
                        fontSize: isDesktop ? 24 : 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    if (state.selectedStatus == 'SUSPENDED') ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                        ),
                        child: const Text(
                          'Suspended View',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFEF4444)),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage library members, their books, fines and membership details.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // 2. Action Buttons (Right)
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (isLibraryAdmin) ...[
                // + Add Member Button
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Member', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const AddMemberDialog(),
                    );
                  },
                ),

                // Import Button
                OutlinedButton.icon(
                  icon: const Icon(Icons.file_upload_outlined, size: 16),
                  label: const Text('Import', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
                    side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const ImportMembersDialog(),
                    );
                  },
                ),
              ],

              // Export Button
              OutlinedButton.icon(
                icon: const Icon(Icons.file_download_outlined, size: 16),
                label: const Text('Export', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
                  side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  _triggerExport(context);
                },
              ),

              if (isLibraryAdmin) ...[
                // More Actions Menu Button
                PopupMenuButton<String>(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.more_vert_rounded,
                      size: 18,
                      color: isDark ? Colors.white : const Color(0xFF334155),
                    ),
                  ),
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onSelected: (val) {
                    if (val == 'bulk' && state.selectedMemberIds.isNotEmpty) {
                      showDialog(
                        context: context,
                        builder: (_) => const BulkMembersDialog(),
                      );
                    } else if (val == 'refresh') {
                      notifier.fetchMembers(resetPage: true);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'bulk',
                      child: Row(
                        children: [
                          Icon(Icons.checklist_rounded, size: 18, color: Color(0xFF6366F1)),
                          SizedBox(width: 10),
                          Text('Bulk Member Actions', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'refresh',
                      child: Row(
                        children: [
                          Icon(Icons.refresh_rounded, size: 18),
                          SizedBox(width: 10),
                          Text('Refresh Data', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _triggerExport(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Downloading library members CSV export...'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }
}
