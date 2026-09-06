import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/book_models.dart';
import '../providers/book_provider.dart';
import 'dialogs/add_edit_book_dialog.dart';
import 'dialogs/add_copy_dialog.dart';
import 'dialogs/edit_copy_dialog.dart';
import 'dialogs/barcode_qr_dialog.dart';
import 'dialogs/ebook_reader_dialog.dart';
import 'dialogs/audiobook_player_dialog.dart';
import 'dialogs/videobook_player_dialog.dart';
import 'package:edu_shamiit_core/config/app_config.dart';

class BookDetailsDrawer extends ConsumerStatefulWidget {

  const BookDetailsDrawer({super.key});

  @override
  ConsumerState<BookDetailsDrawer> createState() => _BookDetailsDrawerState();
}

class _BookDetailsDrawerState extends ConsumerState<BookDetailsDrawer> {
  bool _isDescriptionExpanded = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookProvider);
    final notifier = ref.read(bookProvider.notifier);
    final book = state.selectedBook;
    final copies = state.selectedBookCopies;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    if (book == null) return const SizedBox.shrink();

    // Dynamically size drawer based on available screen width
    final drawerWidth = screenWidth < 500 ? screenWidth : (screenWidth < 900 ? 430.0 : 470.0);

    return Container(
      width: drawerWidth,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        border: Border(
          left: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
            blurRadius: 16,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. Drawer Header (Title, Status Pill, Close X)
          _buildDrawerHeader(book, notifier, isDark),

          // 2. Scrollable Body Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Book Cover & Metadata Grid
                  _buildBookTopInfo(book, isDark),

                  // Digital Assets & Streaming Chapters Section
                  if (book.isDigital || book.digitalFiles.isNotEmpty)
                    _buildDigitalAssetsSection(book, isDark),

                  if (!book.isDigital || copies.isNotEmpty) ...[
                    const Divider(height: 30),
                    // Physical Copies Section with Responsive Table and Zero-Overflow Actions
                    _buildCopiesSection(book, copies, notifier, isDark),
                  ],


                  const Divider(height: 30),

                  // Book Description Section
                  _buildDescriptionSection(book, isDark),

                  const Divider(height: 30),

                  // Acquisition Details Section
                  _buildAcquisitionSection(book, isDark),
                ],
              ),
            ),
          ),

          // 3. Bottom Actions Footer Bar ([Edit Book] [Add Copy])
          _buildBottomActionBar(book, notifier, isDark),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(BookModel book, BookNotifier notifier, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              book.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          _buildStatusPill(
            book.isArchived ? 'Archived' : (book.availableCopies > 0 ? 'Available' : 'Issued'),
            book.isArchived ? const Color(0xFF64748B) : (book.availableCopies > 0 ? const Color(0xFF10B981) : const Color(0xFF3B82F6)),
            isDark,
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            tooltip: 'Close drawer',
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            onPressed: () => notifier.closeDrawer(),
          ),
        ],
      ),
    );
  }

  Widget _buildBookTopInfo(BookModel book, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Book Cover Thumbnail
            Container(
              width: 96,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: book.coverUrl != null && book.coverUrl!.isNotEmpty
                  ? Image.network(
                      AppConfig.resolveUrl(book.coverUrl!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildFallbackBigCover(book),
                    )
                  : _buildFallbackBigCover(book),

            ),

            const SizedBox(width: 14),

            // Metadata Fields Key-Value Table
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMetaRow('Format', book.bookTypeName, isDark),
                  _buildMetaRow('Category', book.categoryName, isDark),
                  _buildMetaRow('Author', book.author, isDark),
                  _buildMetaRow('Access Mode', book.requiresPermission ? '🔒 Restricted' : '🌐 Open Access', isDark),
                  if (book.subject != null && book.subject!.isNotEmpty)
                    _buildMetaRow('Subject', book.subject!, isDark),
                  if (book.rating > 0)
                    _buildMetaRow('Rating', '⭐ ${book.formattedRating} (${book.totalReviews} reviews)', isDark),
                  _buildMetaRow('Engagement', '${book.readCount + book.listenCount + book.watchCount} views', isDark),
                  _buildMetaRow('Language', book.languageName, isDark),
                ],
              ),
            ),
          ],
        ),

        if (book.isDigital) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                // Trigger digital viewer
                if (book.isAudiobook) {
                  ref.read(bookProvider.notifier).fetchDigitalStreamToken(book.id).then((res) {
                    final token = res['data']?['token']?.toString() ?? '';
                    final wm = res['data']?['watermark_text']?.toString() ?? 'EduSHAMIIT';
                    // ignore: use_build_context_synchronously
                    AudiobookPlayerDialog.show(context, book: book, streamToken: token, watermarkText: wm);
                  });
                } else if (book.isVideoBook) {
                  ref.read(bookProvider.notifier).fetchDigitalStreamToken(book.id).then((res) {
                    final token = res['data']?['token']?.toString() ?? '';
                    final wm = res['data']?['watermark_text']?.toString() ?? 'EduSHAMIIT';
                    // ignore: use_build_context_synchronously
                    VideobookPlayerDialog.show(context, book: book, streamToken: token, watermarkText: wm);
                  });
                } else {
                  ref.read(bookProvider.notifier).fetchDigitalStreamToken(book.id).then((res) {
                    final token = res['data']?['token']?.toString() ?? '';
                    final wm = res['data']?['watermark_text']?.toString() ?? 'EduSHAMIIT';
                    // ignore: use_build_context_synchronously
                    EbookReaderDialog.show(context, book: book, streamToken: token, watermarkText: wm);
                  });
                }
              },
              icon: Icon(
                book.isAudiobook ? Icons.headphones : (book.isVideoBook ? Icons.play_arrow : Icons.menu_book),
                size: 18,
              ),
              label: Text(
                book.isAudiobook ? 'Listen Audiobook In-App' : (book.isVideoBook ? 'Watch Video Lecture In-App' : 'Read eBook In-App'),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
        ],
      ],
    );
  }


  Widget _buildFallbackBigCover(BookModel book) {
    return Container(
      color: const Color(0xFF6366F1).withOpacity(0.12),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_stories_rounded, size: 28, color: Color(0xFF6366F1)),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                book.title,
                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Color(0xFF6366F1)),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDigitalAssetsSection(BookModel book, bool isDark) {

    final files = book.digitalFiles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.folder_special_rounded,
                  size: 18,
                  color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                ),
                const SizedBox(width: 8),
                Text(
                  'Digital Assets & Streams (${files.length})',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                book.requiresPermission ? '🔒 Restricted' : '🌐 Open Access',
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF6366F1)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (files.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No digital files attached yet. Click "Edit Book" to upload PDFs, audiobooks, or live streams.',
                    style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: files.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final file = files[idx];
              final isLive = file.isLiveStream;
              final isVideo = file.isVideo || file.fileType.contains('VIDEO') || isLive;
              final isAudio = file.isAudio || file.fileType.contains('AUDIO');

              Color badgeColor;
              IconData iconData;
              String badgeText;

              if (isLive) {
                badgeColor = const Color(0xFFEF4444);
                iconData = Icons.live_tv_rounded;
                badgeText = 'LIVE STREAM';
              } else if (isVideo) {
                badgeColor = const Color(0xFF6366F1);
                iconData = Icons.videocam_rounded;
                badgeText = 'VIDEO LECTURE';
              } else if (isAudio) {
                badgeColor = const Color(0xFFF59E0B);
                iconData = Icons.headphones_rounded;
                badgeText = 'AUDIOBOOK';
              } else if (file.fileType.contains('EPUB')) {
                badgeColor = const Color(0xFF10B981);
                iconData = Icons.menu_book_rounded;
                badgeText = 'EPUB';
              } else {
                badgeColor = const Color(0xFFEC4899);
                iconData = Icons.picture_as_pdf_rounded;
                badgeText = 'PDF EBOOK';
              }

              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(iconData, color: badgeColor, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.title ?? file.fileName,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: badgeColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  badgeText,
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: badgeColor),
                                ),
                              ),
                              if (file.fileSizeBytes > 0) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '• ${file.formattedFileSize}',
                                  style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: badgeColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () {
                        ref.read(bookProvider.notifier).fetchDigitalStreamToken(book.id, fileId: file.id).then((res) {
                          final token = res['data']?['token']?.toString() ?? '';
                          final wm = res['data']?['watermark_text']?.toString() ?? 'EduSHAMIIT';
                          if (isAudio) {
                            AudiobookPlayerDialog.show(context, book: book, streamToken: token, watermarkText: wm, initialFileId: file.id);
                          } else if (isVideo) {
                            VideobookPlayerDialog.show(context, book: book, streamToken: token, watermarkText: wm, initialFileId: file.id);
                          } else {
                            EbookReaderDialog.show(context, book: book, streamToken: token, watermarkText: wm, initialFileId: file.id);
                          }
                        });
                      },

                      icon: Icon(isAudio ? Icons.play_arrow_rounded : (isVideo ? Icons.play_circle_filled_rounded : Icons.visibility_rounded), size: 14),
                      label: Text(
                        isAudio ? 'Listen' : (isLive ? 'Stream' : (isVideo ? 'Watch' : 'Read')),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildCopiesSection(BookModel book, List<BookCopyModel> copies, BookNotifier notifier, bool isDark) {

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Copies (${copies.length})',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add Copy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6366F1),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AddCopyDialog(book: book),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (copies.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 24, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 6),
                  const Text(
                    'No physical copies recorded yet.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 14),
                    label: const Text('Add First Copy', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      showDialog(context: context, builder: (_) => AddCopyDialog(book: book));
                    },
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                // Table Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A).withOpacity(0.5) : const Color(0xFFF1F5F9),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                  child: const Row(
                    children: [
                      Expanded(flex: 30, child: Text('Barcode / Acc', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)))),
                      Expanded(flex: 26, child: Text('Location', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)))),
                      Expanded(flex: 22, child: Text('Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)))),
                      SizedBox(width: 60, child: Text('Actions', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)))),
                    ],
                  ),
                ),
                // Table Rows
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: copies.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  itemBuilder: (ctx, idx) {
                    final copy = copies[idx];
                    final statusColor = copy.isOverdue
                        ? const Color(0xFFEF4444)
                        : (copy.isIssued
                            ? const Color(0xFF3B82F6)
                            : (copy.isAvailable ? const Color(0xFF10B981) : const Color(0xFFF59E0B)));

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(
                        children: [
                          // Barcode + Accession No (flex: 30)
                          Expanded(
                            flex: 30,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  copy.barcode,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  copy.accessionNumber,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                                if (copy.borrowerName != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    copy.borrowerName!,
                                    style: const TextStyle(fontSize: 9, color: Color(0xFF3B82F6), fontWeight: FontWeight.w500),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // Location (flex: 26)
                          Expanded(
                            flex: 26,
                            child: Text(
                              copy.location ?? '${copy.rack ?? "Rack A"} - ${copy.shelf ?? "Shelf 1"}',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          // Status (flex: 22)
                          Expanded(
                            flex: 22,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _buildStatusPill(copy.status, statusColor, isDark),
                            ),
                          ),

                          // Actions - Zero Overflow Custom Action Icons
                          SizedBox(
                            width: 60,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Edit Copy
                                  Tooltip(
                                    message: 'Edit Copy',
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(4),
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => EditCopyDialog(book: book, copy: copy),
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(2),
                                        child: Icon(
                                          Icons.edit_outlined,
                                          size: 14,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 2),

                                  // Print Barcode / QR Label
                                  Tooltip(
                                    message: 'Print Barcode',
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(4),
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => BarcodeQrDialog(
                                            title: '${book.title} (Copy #${copy.copyNumber})',
                                            isbn: book.displayIsbn,
                                            barcode: copy.barcode,
                                            accessionNumber: copy.accessionNumber,
                                          ),
                                        );
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.all(2),
                                        child: Icon(
                                          Icons.qr_code_rounded,
                                          size: 14,
                                          color: Color(0xFF3B82F6),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 2),

                                  // Delete / Archive Copy
                                  Tooltip(
                                    message: 'Delete Copy',
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(4),
                                      onTap: () => _confirmDeleteCopy(context, book, copy, notifier),
                                      child: const Padding(
                                        padding: EdgeInsets.all(2),
                                        child: Icon(
                                          Icons.delete_outline_rounded,
                                          size: 14,
                                          color: Color(0xFFEF4444),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDescriptionSection(BookModel book, bool isDark) {
    final desc = book.description ?? 'Timeless lessons on wealth, greed, and happiness. This book explores how our emotions and psychology shape our financial decisions.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Book Description',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          desc,
          style: TextStyle(
            fontSize: 12,
            height: 1.5,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
          ),
          maxLines: _isDescriptionExpanded ? 20 : 3,
          overflow: TextOverflow.ellipsis,
        ),
        InkWell(
          onTap: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              _isDescriptionExpanded ? 'View Less ⌃' : 'View More ⌵',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6366F1),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAcquisitionSection(BookModel book, bool isDark) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final purchaseDate = book.createdAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Acquisition Details',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),
        _buildMetaRow('Supplier', book.supplier ?? 'Sapna Book House', isDark),
        _buildMetaRow('Purchase Date', dateFormat.format(book.purchaseDate ?? purchaseDate), isDark),
        _buildMetaRow('Purchase Price', book.purchasePrice != null ? '₹${book.purchasePrice!.toStringAsFixed(2)}' : '₹299.00', isDark),
        _buildMetaRow('Total Copies', '${book.totalCopies}', isDark),
      ],
    );
  }

  Widget _buildBottomActionBar(BookModel book, BookNotifier notifier, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        children: [
          // Edit Book Button (Outlined)
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit Book', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
                side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AddEditBookDialog(book: book),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          // Add Copy Button (Solid Purple)
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('Add Copy', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AddCopyDialog(book: book),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  void _confirmDeleteCopy(BuildContext context, BookModel book, BookCopyModel copy, BookNotifier notifier) {
    if (copy.isIssued) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete a copy that is currently issued to a borrower.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Physical Copy'),
        content: Text('Are you sure you want to delete physical copy "${copy.barcode}" (${copy.accessionNumber})? Total copies count will be reduced.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () {
              Navigator.pop(ctx);
              notifier.archiveBookCopy(copy.id);
            },
            child: const Text('Delete Copy', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
