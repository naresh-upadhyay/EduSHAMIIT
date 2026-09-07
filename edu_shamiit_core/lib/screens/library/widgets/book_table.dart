import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/providers/role_provider.dart';
import '../models/book_models.dart';
import '../providers/book_provider.dart';
import 'dialogs/add_edit_book_dialog.dart';
import 'dialogs/add_copy_dialog.dart';
import 'dialogs/barcode_qr_dialog.dart';
import 'dialogs/ebook_reader_dialog.dart';
import 'dialogs/audiobook_player_dialog.dart';
import 'dialogs/videobook_player_dialog.dart';
import 'dialogs/request_digital_access_dialog.dart';
import 'dialogs/raise_book_issue_request_dialog.dart';
import 'package:edu_shamiit_core/utils/responsive.dart';
import 'package:edu_shamiit_core/config/app_config.dart';

class BookTable extends ConsumerStatefulWidget {

  const BookTable({super.key});

  @override
  ConsumerState<BookTable> createState() => _BookTableState();
}

class _BookTableState extends ConsumerState<BookTable> {
  final ScrollController _horizontalScrollCtrl = ScrollController();

  @override
  void dispose() {
    _horizontalScrollCtrl.dispose();
    super.dispose();
  }

  void _openDigitalViewer(BuildContext context, BookModel book) async {
    final notifier = ref.read(bookProvider.notifier);
    
    // If book requires permission and user does not have active approved access
    if (book.requiresPermission && book.userPermissionStatus != 'APPROVED') {
      final requested = await RequestDigitalAccessDialog.show(context, book);
      if (requested == true) {
        notifier.loadBooks();
      }
      return;
    }

    // Fetch expiring stream token
    try {
      final tokenRes = await notifier.fetchDigitalStreamToken(book.id);
      if (!mounted) return;
      final data = tokenRes['data'] as Map<String, dynamic>? ?? {};
      final token = data['token']?.toString() ?? '';
      final watermark = data['watermark_text']?.toString() ?? 'EduSHAMIIT Digital Library';

      if (book.isAudiobook) {
        AudiobookPlayerDialog.show(context, book: book, streamToken: token, watermarkText: watermark);
      } else if (book.isVideoBook) {
        VideobookPlayerDialog.show(context, book: book, streamToken: token, watermarkText: watermark);
      } else {
        EbookReaderDialog.show(context, book: book, streamToken: token, watermarkText: watermark);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Access restricted: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookProvider);
    final notifier = ref.read(bookProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = Responsive.isDesktop(context);

    // Top Layout Toolbar: Format Pills + Table/Cards View Toggle (Always Visible)
    return Column(
      children: [
        // Sub-filter & View Mode Bar
        Container(
          margin: EdgeInsets.symmetric(horizontal: isDesktop ? 28 : 16, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131B2E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              // Format Filter Pills
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _formatFilterPill('ALL', 'All Formats', Icons.apps, state, notifier, isDark),
                      const SizedBox(width: 8),
                      _formatFilterPill('PHYSICAL', 'Physical Books', Icons.menu_book, state, notifier, isDark),
                      const SizedBox(width: 8),
                      _formatFilterPill('EBOOK', 'eBooks (PDF/ePub)', Icons.picture_as_pdf, state, notifier, isDark),
                      const SizedBox(width: 8),
                      _formatFilterPill('AUDIOBOOK', 'Audiobooks', Icons.headphones, state, notifier, isDark),
                      const SizedBox(width: 8),
                      _formatFilterPill('VIDEOBOOK', 'Video Books', Icons.play_circle_fill, state, notifier, isDark),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // View Mode Toggle (Table vs Cards)
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    _viewModeButton('TABLE', Icons.table_rows, state.viewMode == 'TABLE', notifier, isDark),
                    _viewModeButton('CARDS', Icons.grid_view_rounded, state.viewMode == 'CARDS', notifier, isDark),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Main Content Area: Loading / Empty / Content
        if (state.isLoading)
          Container(
            margin: EdgeInsets.symmetric(horizontal: isDesktop ? 28 : 16, vertical: 10),
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131B2E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF6366F1), strokeWidth: 3),
                  SizedBox(height: 16),
                  Text('Loading library books catalogue...', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                ],
              ),
            ),
          )
        else if (state.books.isEmpty)
          Container(
            margin: EdgeInsets.symmetric(horizontal: isDesktop ? 28 : 16, vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131B2E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off_rounded, size: 48, color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                  const SizedBox(height: 12),
                  Text(
                    state.searchQuery.isNotEmpty ? 'No books matching "${state.searchQuery}"' : 'No books found in this catalogue view',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Try adjusting your search terms, categories, or filter options.',
                    style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.clear_all_rounded, size: 16),
                    label: const Text('Clear All Filters'),
                    onPressed: () => notifier.clearFilters(),
                  ),
                ],
              ),
            ),
          )
        else
          state.viewMode == 'CARDS'
              ? _buildSmartCardsGrid(state, notifier, isDark, isDesktop)
              : _buildEnterpriseTable(state, notifier, isDark, isDesktop),
      ],
    );
  }

  Widget _viewModeButton(String mode, IconData icon, bool isSelected, BookNotifier notifier, bool isDark) {
    return GestureDetector(
      onTap: () => notifier.setViewMode(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 16,
          color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        ),
      ),
    );
  }

  Widget _formatFilterPill(String filterKey, String label, IconData icon, BookState state, BookNotifier notifier, bool isDark) {
    final isSelected = state.selectedFormatFilter == filterKey;
    return InkWell(
      onTap: () => notifier.setFormatFilter(filterKey),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6366F1).withOpacity(0.15)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF6366F1) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? const Color(0xFF6366F1) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF6366F1) : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 1. Smart Cards Layout Grid
  Widget _buildSmartCardsGrid(BookState state, BookNotifier notifier, bool isDark, bool isDesktop) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isDesktop ? 28 : 16, vertical: 6),
      child: Column(
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.books.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isDesktop ? 4 : 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.72,
            ),
            itemBuilder: (context, idx) {
              final book = state.books[idx];
              return _buildBookCard(book, notifier, isDark);
            },
          ),
          const SizedBox(height: 16),
          _buildPaginationFooter(state, notifier, isDark, isDesktop),
        ],
      ),
    );
  }

  Widget _buildBookCard(BookModel book, BookNotifier notifier, bool isDark) {
    Color formatColor = const Color(0xFF6366F1);
    IconData formatIcon = Icons.menu_book;
    String formatLabel = book.bookTypeName;

    if (book.isAudiobook) {
      formatColor = Colors.purple;
      formatIcon = Icons.headphones;
    } else if (book.isVideoBook) {
      formatColor = Colors.red;
      formatIcon = Icons.play_circle_filled;
    } else if (book.isEBook) {
      formatColor = const Color(0xFF10B981);
      formatIcon = Icons.picture_as_pdf;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.25 : 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Cover Area
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: formatColor.withOpacity(0.08),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: book.coverUrl != null && book.coverUrl!.isNotEmpty
                      ? Image.network(
                          AppConfig.resolveUrl(book.coverUrl!),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (ctx, err, stack) => Center(
                            child: Icon(formatIcon, size: 48, color: formatColor.withOpacity(0.5)),
                          ),
                        )
                      : Center(
                          child: Icon(formatIcon, size: 48, color: formatColor.withOpacity(0.5)),
                        ),
                ),


                // Format Badge
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: formatColor,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(formatIcon, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          formatLabel,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),

                // Visibility Badge
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: book.requiresPermission ? Colors.amber[700] : const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      book.requiresPermission ? 'RESTRICTED' : 'OPEN ACCESS',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Meta & Action
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        book.author,
                        style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                          const SizedBox(width: 3),
                          Text(
                            book.formattedRating,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '• ${book.readCount + book.listenCount + book.watchCount} views',
                            style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Smart Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 32,
                    child: (book.hasBothEditions && book.isUnrestrictedDigital)
                        ? Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: formatColor,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () => _openDigitalViewer(context, book),
                                  icon: Icon(
                                    book.isAudiobook ? Icons.headphones : (book.isVideoBook ? Icons.play_arrow : Icons.auto_stories),
                                    size: 13,
                                  ),
                                  label: Text(
                                    book.isAudiobook ? 'Listen' : (book.isVideoBook ? 'Watch' : 'Read'),
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () => notifier.selectBookForDrawer(book.id),
                                  child: Text(
                                    '${book.availableCopies} Copies',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF334155)),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : (book.hasDigitalEdition && book.isUnrestrictedDigital)
                            ? ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: formatColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => _openDigitalViewer(context, book),
                                icon: Icon(
                                  book.isAudiobook ? Icons.headphones : (book.isVideoBook ? Icons.play_arrow : Icons.auto_stories),
                                  size: 14,
                                ),
                                label: Text(
                                  book.isAudiobook ? 'Listen Now' : (book.isVideoBook ? 'Watch Lecture' : 'Read Now'),
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                                ),
                              )
                            : OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => notifier.selectBookForDrawer(book.id),
                                child: Text(
                                  book.hasPhysicalEdition
                                      ? '${book.availableCopies} Available'
                                      : (book.hasDigitalEdition ? 'Restricted Access' : 'View Details'),
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF334155)),
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
  }

  /// 2. Enterprise Table View
  Widget _buildEnterpriseTable(BookState state, BookNotifier notifier, bool isDark, bool isDesktop) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isDesktop ? 28 : 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const minTableWidth = 1100.0;
          final tableWidth = constraints.maxWidth > minTableWidth ? constraints.maxWidth : minTableWidth;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Scrollbar(
                controller: _horizontalScrollCtrl,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _horizontalScrollCtrl,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTableHeader(isDark),
                        Divider(height: 1, thickness: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                        ...state.books.map((book) => _buildTableRow(book, state, notifier, isDark)),
                      ],
                    ),
                  ),
                ),
              ),
              Divider(height: 1, thickness: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
              _buildPaginationFooter(state, notifier, isDark, isDesktop),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTableHeader(bool isDark) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A).withOpacity(0.6) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Expanded(flex: 32, child: _buildHeaderCell('Book Title & Format', isDark)),
          const SizedBox(width: 12),
          Expanded(flex: 16, child: _buildHeaderCell('Author', isDark)),
          const SizedBox(width: 12),
          Expanded(flex: 14, child: _buildHeaderCell('Category / Subject', isDark)),
          const SizedBox(width: 12),
          Expanded(flex: 16, child: _buildHeaderCell('Access / DRM', isDark)),
          const SizedBox(width: 12),
          Expanded(flex: 8, child: _buildHeaderCell('Copies', isDark)),
          const SizedBox(width: 12),
          Expanded(flex: 8, child: _buildHeaderCell('Available', isDark)),
          const SizedBox(width: 12),
          Expanded(flex: 10, child: _buildHeaderCell('Status', isDark)),
          const SizedBox(width: 12),
          SizedBox(width: 175, child: _buildHeaderCell('Actions', isDark, alignment: Alignment.centerRight)),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String label, bool isDark, {Alignment alignment = Alignment.centerLeft}) {
    return Align(
      alignment: alignment,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildTableRow(BookModel book, BookState state, BookNotifier notifier, bool isDark) {
    final isDrawerActive = state.selectedBook?.id == book.id && state.isDrawerOpen;
    final roleState = ref.watch(roleProvider);
    final isLibraryAdmin = ref.watch(isLibraryAdminProvider);

    Color formatColor = const Color(0xFF6366F1);
    if (book.isAudiobook) {
      formatColor = const Color(0xFF9333EA);
    } else if (book.isVideoBook) {
      formatColor = const Color(0xFFEF4444);
    } else if (book.isEBook) {
      formatColor = const Color(0xFF10B981);
    }

    return Container(
      decoration: BoxDecoration(
        color: isDrawerActive ? const Color(0xFF6366F1).withOpacity(isDark ? 0.16 : 0.06) : Colors.transparent,
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          hoverColor: const Color(0xFF6366F1).withOpacity(isDark ? 0.08 : 0.03),
          onTap: () => notifier.selectBookForDrawer(book.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                // Title + Cover + Format Icon
                Expanded(
                  flex: 32,
                  child: Row(
                    children: [
                      _buildCoverThumbnail(book, isDark),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    book.title,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: formatColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    book.bookTypeName,
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: formatColor),
                                  ),
                                ),
                                if (book.rating > 0) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.star, size: 12, color: Colors.amber),
                                  const SizedBox(width: 2),
                                  Text('${book.rating.toStringAsFixed(1)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Author
                Expanded(
                  flex: 16,
                  child: Text(
                    book.author,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),

                // Category & Subject
                Expanded(
                  flex: 14,
                  child: Text(
                    book.categoryName,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),

                // Access / DRM
                Expanded(
                  flex: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: book.requiresPermission
                          ? Colors.amber.withOpacity(0.15)
                          : const Color(0xFF10B981).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      book.requiresPermission ? '🔒 Permission Req.' : '🌐 Open Access',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: book.requiresPermission ? Colors.amber[800] : const Color(0xFF10B981),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Copies
                Expanded(
                  flex: 8,
                  child: Text(
                    '${book.totalCopies}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Available
                Expanded(
                  flex: 8,
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: book.availableCopies > 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${book.availableCopies}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: book.availableCopies > 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Status
                Expanded(
                  flex: 10,
                  child: _buildStatusPill(book, isDark),
                ),
                const SizedBox(width: 12),

                // Actions
                SizedBox(
                  width: 175,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Quick Stream Action Button if Digital (Direct access if unrestricted, or for librarians)
                      if (book.hasDigitalEdition && (book.isUnrestrictedDigital || isLibraryAdmin))
                        IconButton(
                          icon: Icon(
                            book.isAudiobook ? Icons.headphones : (book.isVideoBook ? Icons.play_circle_fill : Icons.menu_book),
                            size: 18,
                            color: const Color(0xFF6366F1),
                          ),
                          tooltip: book.isAudiobook ? 'Direct Access: Listen In-App' : (book.isVideoBook ? 'Direct Access: Watch In-App' : 'Direct Access: Read eBook In-App'),
                          onPressed: () => _openDigitalViewer(context, book),
                          splashRadius: 18,
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          padding: EdgeInsets.zero,
                        ),

                      if (isLibraryAdmin) ...[
                        // Manage Digital Access Button
                        IconButton(
                          icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
                          tooltip: 'Manage Digital Permissions',
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          onPressed: () => notifier.openAccessDrawer(book),
                          splashRadius: 18,
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          padding: EdgeInsets.zero,
                        ),

                        // Edit Button
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'Edit Publication',
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => AddEditBookDialog(book: book),
                            );
                          },
                          splashRadius: 18,
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          padding: EdgeInsets.zero,
                        ),

                        // More Actions
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          icon: Icon(Icons.more_vert_rounded, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          onSelected: (val) {
                            if (val == 'copies') {
                              showDialog(context: context, builder: (_) => AddCopyDialog(book: book));
                            } else if (val == 'barcode') {
                              showDialog(
                                context: context,
                                builder: (_) => BarcodeQrDialog(
                                  title: book.title,
                                  isbn: book.displayIsbn,
                                  barcode: book.primaryBarcode ?? (book.primaryAccessionNumber ?? 'BC000001'),
                                  accessionNumber: book.primaryAccessionNumber ?? (book.primaryBarcode ?? 'ACC-0001'),
                                ),
                              );
                            } else if (val == 'archive') {
                              notifier.archiveBook(book.id);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'copies', child: Text('Manage Physical Copies')),
                            const PopupMenuItem(value: 'barcode', child: Text('Print Barcodes / Labels')),
                            const PopupMenuItem(value: 'archive', child: Text('Archive Title', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      ] else ...[
                        // Non-admin roles: Request button for physical hardcopy or restricted digital
                        if (book.hasPhysicalEdition)
                          ElevatedButton.icon(
                            icon: const Icon(Icons.bookmark_add_rounded, size: 14),
                            label: const Text('Request Hardcopy', style: TextStyle(fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              minimumSize: const Size(0, 30),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => RaiseBookIssueRequestDialog(book: book),
                              );
                            },
                          )
                        else if (book.hasDigitalEdition && !book.isUnrestrictedDigital)
                          OutlinedButton.icon(
                            icon: const Icon(Icons.lock_open_rounded, size: 14),
                            label: const Text('Request Access', style: TextStyle(fontSize: 11)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              minimumSize: const Size(0, 30),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => RaiseBookIssueRequestDialog(book: book),
                              );
                            },
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverThumbnail(BookModel book, bool isDark) {
    final rawUrl = book.coverUrl?.trim() ?? '';
    final resolvedUrl = rawUrl.isNotEmpty ? AppConfig.resolveUrl(rawUrl) : '';

    return Container(
      width: 36,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: resolvedUrl.isNotEmpty
          ? Image.network(
              resolvedUrl,
              fit: BoxFit.cover,
              width: 36,
              height: 48,
              errorBuilder: (ctx, err, stack) => Center(
                child: Icon(
                  book.isAudiobook ? Icons.headphones : (book.isVideoBook ? Icons.videocam : Icons.book),
                  size: 18,
                  color: const Color(0xFF6366F1),
                ),
              ),
            )
          : Center(
              child: Icon(
                book.isAudiobook ? Icons.headphones : (book.isVideoBook ? Icons.videocam : Icons.book),
                size: 18,
                color: const Color(0xFF6366F1),
              ),
            ),
    );
  }


  Widget _buildStatusPill(BookModel book, bool isDark) {
    final status = book.status.toUpperCase();
    Color bg = Colors.grey.withOpacity(0.12);
    Color text = Colors.grey;

    if (status == 'ACTIVE') {
      bg = const Color(0xFF10B981).withOpacity(0.12);
      text = const Color(0xFF10B981);
    } else if (status == 'ARCHIVED') {
      bg = Colors.red.withOpacity(0.12);
      text = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        status,
        style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildPaginationFooter(BookState state, BookNotifier notifier, bool isDark, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: isDesktop
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left: Records count & Page Size Selector
                Row(
                  children: [
                    Text(
                      'Showing ${state.books.length} of ${state.totalRecords} records',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Text(
                      'Records per page:',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: state.pageSize,
                          isDense: true,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          items: const [10, 25, 50, 100].map((size) {
                            return DropdownMenuItem<int>(
                              value: size,
                              child: Text('$size'),
                            );
                          }).toList(),
                          onChanged: (newSize) {
                            if (newSize != null) {
                              notifier.setPageSize(newSize);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                // Right: Navigation Buttons
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.first_page_rounded, size: 20),
                      tooltip: 'First Page',
                      onPressed: state.currentPage > 1 ? () => notifier.setPage(1) : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 20),
                      tooltip: 'Previous Page',
                      onPressed: state.currentPage > 1 ? () => notifier.setPage(state.currentPage - 1) : null,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Page ${state.currentPage} of ${state.totalPages > 0 ? state.totalPages : 1}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 20),
                      tooltip: 'Next Page',
                      onPressed: state.currentPage < state.totalPages ? () => notifier.setPage(state.currentPage + 1) : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.last_page_rounded, size: 20),
                      tooltip: 'Last Page',
                      onPressed: state.currentPage < state.totalPages ? () => notifier.setPage(state.totalPages) : null,
                    ),
                  ],
                ),
              ],
            )
          : Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${state.books.length} / ${state.totalRecords} records',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'Per page: ',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        Container(
                          height: 28,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: state.pageSize,
                              isDense: true,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                              items: const [10, 25, 50, 100].map((size) {
                                return DropdownMenuItem<int>(
                                  value: size,
                                  child: Text('$size'),
                                );
                              }).toList(),
                              onChanged: (newSize) {
                                if (newSize != null) {
                                  notifier.setPageSize(newSize);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 20),
                      onPressed: state.currentPage > 1 ? () => notifier.setPage(state.currentPage - 1) : null,
                    ),
                    Text(
                      'Page ${state.currentPage} of ${state.totalPages > 0 ? state.totalPages : 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 20),
                      onPressed: state.currentPage < state.totalPages ? () => notifier.setPage(state.currentPage + 1) : null,
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
