import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/role_provider.dart';
import '../providers/book_provider.dart';
import 'dialogs/add_edit_book_dialog.dart';
import 'dialogs/import_books_dialog.dart';
import 'dialogs/scan_book_dialog.dart';
import 'dialogs/bulk_operations_dialog.dart';
import 'package:edu_shamiit_core/utils/responsive.dart';

class BookHeaderBar extends ConsumerWidget {
  const BookHeaderBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookProvider);
    final notifier = ref.read(bookProvider.notifier);
    final roleState = ref.watch(roleProvider);
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
                      'Books',
                      style: TextStyle(
                        fontSize: isDesktop ? 24 : 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    if (state.selectedStatus == 'ARCHIVED') ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                        ),
                        child: const Text(
                          'ARCHIVED VIEW',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFEF4444),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage all library books, copies, availability and details.',
                  style: TextStyle(
                    fontSize: isDesktop ? 13 : 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // 2. Action Buttons (Right) - Matching Screenshot 4: [+ Add Book] [Import] [Export] [:]
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLibraryAdmin) ...[
                // Primary Add Book Button
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text(
                    'Add Book',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1), // Royal Purple / Indigo
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 16 : 12,
                      vertical: isDesktop ? 12 : 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const AddEditBookDialog(),
                    );
                  },
                ),

                if (isDesktop) ...[
                  const SizedBox(width: 10),

                  // Import Button
                  OutlinedButton.icon(
                    icon: const Icon(Icons.file_upload_outlined, size: 17),
                    label: const Text(
                      'Import',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
                      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      side: BorderSide(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const ImportBooksDialog(),
                      );
                    },
                  ),
                ],
                const SizedBox(width: 10),
              ],

                // Export Button
                OutlinedButton.icon(
                  icon: const Icon(Icons.file_download_outlined, size: 17),
                  label: const Text(
                    'Export',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
                    backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    side: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    try {
                      final api = ref.read(libraryApiServiceProvider);
                      final csv = await api.exportBooksCsv(
                        search: state.searchQuery,
                        category: state.selectedCategory,
                        status: state.selectedStatus,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Catalogue exported (${csv.length} bytes ready).'),
                            backgroundColor: const Color(0xFF10B981),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                ),

              const SizedBox(width: 8),

              // More Options Menu (3 Dots)
              PopupMenuButton<String>(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Icon(
                    Icons.more_vert_rounded,
                    size: 18,
                    color: isDark ? Colors.white : const Color(0xFF334155),
                  ),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'scan',
                    child: Row(
                      children: [
                        Icon(Icons.qr_code_scanner_rounded, size: 18, color: Color(0xFF6366F1)),
                        SizedBox(width: 10),
                        Text('Scan Barcode / QR', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  if (!isDesktop) ...[
                    const PopupMenuItem(
                      value: 'import',
                      child: Row(
                        children: [
                          Icon(Icons.file_upload_outlined, size: 18),
                          SizedBox(width: 10),
                          Text('Import Books', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'export',
                      child: Row(
                        children: [
                          Icon(Icons.file_download_outlined, size: 18),
                          SizedBox(width: 10),
                          Text('Export Books', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                  if (state.selectedBookIds.isNotEmpty)
                    PopupMenuItem(
                      value: 'bulk',
                      child: Row(
                        children: [
                          const Icon(Icons.checklist_rounded, size: 18, color: Color(0xFF3B82F6)),
                          const SizedBox(width: 10),
                          Text('Bulk Operations (${state.selectedBookIds.length})', style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
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
                onSelected: (val) {
                  switch (val) {
                    case 'scan':
                      showDialog(context: context, builder: (_) => const ScanBookDialog());
                      break;
                    case 'import':
                      showDialog(context: context, builder: (_) => const ImportBooksDialog());
                      break;
                    case 'bulk':
                      showDialog(context: context, builder: (_) => const BulkOperationsDialog());
                      break;
                    case 'refresh':
                      notifier.loadStats();
                      notifier.loadFilterOptions();
                      notifier.loadBooks();
                      break;
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
