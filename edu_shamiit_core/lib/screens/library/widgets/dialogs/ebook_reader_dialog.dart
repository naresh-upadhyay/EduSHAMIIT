import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/book_models.dart';
import '../../providers/book_provider.dart';
import '../../../../utils/digital_media_player_helper.dart';

/// In-App Secure Real PDF Document Viewer Dialog with Embedded Engine, Multi-Document Switching & AI Study Assistant
class EbookReaderDialog extends ConsumerStatefulWidget {
  final BookModel book;
  final String streamToken;
  final String watermarkText;
  final String? initialFileId;
  final int initialAssetIndex;

  const EbookReaderDialog({
    super.key,
    required this.book,
    required this.streamToken,
    required this.watermarkText,
    this.initialFileId,
    this.initialAssetIndex = 0,
  });

  static Future<void> show(
    BuildContext context, {
    required BookModel book,
    required String streamToken,
    required String watermarkText,
    String? initialFileId,
    int initialAssetIndex = 0,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => EbookReaderDialog(
        book: book,
        streamToken: streamToken,
        watermarkText: watermarkText,
        initialFileId: initialFileId,
        initialAssetIndex: initialAssetIndex,
      ),
    );
  }

  @override
  ConsumerState<EbookReaderDialog> createState() => _EbookReaderDialogState();
}

class _EbookReaderDialogState extends ConsumerState<EbookReaderDialog> {
  String _pdfViewKey = '';
  bool _isAiSidebarOpen = false;
  String _aiQueryAction = 'SUMMARIZE_PAGE';
  String _aiResult = '';
  bool _isAiLoading = false;
  final TextEditingController _noteController = TextEditingController();
  final Set<int> _bookmarkedPages = {};
  List<BookInteractionModel> _annotations = [];

  // Multi-Document Support
  int _selectedAssetIndex = 0;
  List<DigitalFileModel> _readingAssets = [];

  @override
  void initState() {
    super.initState();
    _initReadingAssets();
    _registerPdfPlayer();
    _loadInteractions();
  }

  void _initReadingAssets() {
    _readingAssets = widget.book.digitalFiles.where((f) => f.isPdf || f.isEpub || f.fileType.startsWith('EBOOK')).toList();
    if (_readingAssets.isEmpty && widget.book.digitalFiles.isNotEmpty) {
      _readingAssets = widget.book.digitalFiles;
    }

    if (widget.initialFileId != null && widget.initialFileId!.isNotEmpty) {
      final found = _readingAssets.indexWhere((f) => f.id == widget.initialFileId);
      _selectedAssetIndex = found != -1 ? found : 0;
    } else if (widget.initialAssetIndex >= 0 && widget.initialAssetIndex < _readingAssets.length) {
      _selectedAssetIndex = widget.initialAssetIndex;
    } else {
      _selectedAssetIndex = 0;
    }

    if (_selectedAssetIndex < 0 || _selectedAssetIndex >= _readingAssets.length) {
      _selectedAssetIndex = 0;
    }
  }

  void _registerPdfPlayer() {
    if (_readingAssets.isEmpty || _selectedAssetIndex < 0 || _selectedAssetIndex >= _readingAssets.length) {
      return;
    }
    final curAsset = _readingAssets[_selectedAssetIndex];
    final rawStream = curAsset.streamUrl?.trim() ?? '';
    final rawStorage = curAsset.storageKey.trim();
    final pdfUrl = rawStream.isNotEmpty ? rawStream : rawStorage;

    _pdfViewKey = 'digital_pdf_${curAsset.id}_${DateTime.now().millisecondsSinceEpoch}';

    if (kIsWeb && pdfUrl.isNotEmpty) {
      registerDigitalPdfView(_pdfViewKey, pdfUrl);
    }
  }

  void _switchAsset(int index) {
    if (index < 0 || index >= _readingAssets.length) return;
    setState(() {
      _selectedAssetIndex = index;
      _registerPdfPlayer();
    });
  }

  Future<void> _loadInteractions() async {
    final interactions = await ref.read(libraryApiServiceProvider).fetchBookInteractions(widget.book.id);
    if (mounted) {
      setState(() {
        _annotations = interactions;
        for (var i in interactions) {
          if (i.interactionType == 'BOOKMARK' && i.pageNumber != null) {
            _bookmarkedPages.add(i.pageNumber!);
          }
        }
      });
    }
  }

  Future<void> _toggleBookmark() async {
    final isBookmarked = _bookmarkedPages.contains(1);
    if (isBookmarked) {
      final existing = _annotations.firstWhere(
        (a) => a.interactionType == 'BOOKMARK',
        orElse: () => _annotations.first,
      );
      if (existing.id.isNotEmpty) {
        await ref.read(libraryApiServiceProvider).deleteBookInteraction(widget.book.id, existing.id);
      }
      setState(() => _bookmarkedPages.remove(1));
    } else {
      await ref.read(libraryApiServiceProvider).createBookInteraction(widget.book.id, {
        'interaction_type': 'BOOKMARK',
        'page_number': 1,
        'chapter_title': _readingAssets.isNotEmpty ? _readingAssets[_selectedAssetIndex].displayTitle : widget.book.title,
      });
      setState(() => _bookmarkedPages.add(1));
    }
    _loadInteractions();
  }

  Future<void> _askAiAssistant() async {
    setState(() {
      _isAiLoading = true;
      _aiResult = '';
    });

    try {
      final curTitle = _readingAssets.isNotEmpty ? _readingAssets[_selectedAssetIndex].displayTitle : widget.book.title;
      final res = await ref.read(libraryApiServiceProvider).askAiReadingAssistant(widget.book.id, {
        'action': _aiQueryAction,
        'page_text': curTitle,
        'selected_text': widget.book.title,
        'target_language': 'Hindi',
      });
      if (mounted) {
        setState(() {
          _aiResult = res['data']?['response']?.toString() ?? 'No response generated.';
          _isAiLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiResult = 'AI Companion Error: $e';
          _isAiLoading = false;
        });
      }
    }
  }

  void _syncReadingProgress() {
    ref.read(bookProvider.notifier).recordDigitalProgress(widget.book.id, {
      'media_type': 'EBOOK',
      'current_page': 1,
      'total_pages': widget.book.pages ?? 1,
      'progress_pct': 100.0,
      'session_seconds': 60,
      'is_completed': false,
    });
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0F172A);
    const textColor = Color(0xFFF1F5F9);

    final isBookmarked = _bookmarkedPages.contains(1);
    final safeAssetIndex = (_readingAssets.isNotEmpty && _selectedAssetIndex >= 0 && _selectedAssetIndex < _readingAssets.length)
        ? _selectedAssetIndex
        : 0;
    final activeAsset = _readingAssets.isNotEmpty ? _readingAssets[safeAssetIndex] : null;
    final rawStream = activeAsset?.streamUrl?.trim() ?? '';
    final rawStorage = activeAsset?.storageKey.trim() ?? '';
    final pdfUrl = rawStream.isNotEmpty ? rawStream : rawStorage;
    final hasPdf = pdfUrl.isNotEmpty;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      backgroundColor: Colors.transparent,
      child: Container(
        width: 1200,
        height: 860,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 28, offset: const Offset(0, 10)),
          ],
        ),
        child: Column(
          children: [
            // Top Navigation Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: Colors.redAccent,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.book.title,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: textColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_readingAssets.length > 1) ...[
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: safeAssetIndex,
                                isDense: true,
                                dropdownColor: const Color(0xFF1E293B),
                                icon: const Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF818CF8)),
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF818CF8)),
                                items: List.generate(_readingAssets.length, (idx) {
                                  final asset = _readingAssets[idx];
                                  return DropdownMenuItem(
                                    value: idx,
                                    child: Text('📄 ${asset.displayTitle}', maxLines: 1, overflow: TextOverflow.ellipsis),
                                  );
                                }),
                                onChanged: (v) {
                                  if (v != null) _switchAsset(v);
                                },
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Open raw document / file button
                  if (hasPdf)
                    IconButton(
                      icon: const Icon(Icons.open_in_new_rounded, size: 20, color: Colors.white70),
                      tooltip: 'Open document in new browser tab',
                      onPressed: () async {
                        final uri = Uri.tryParse(pdfUrl);
                        if (uri != null) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),

                  // Bookmark button
                  IconButton(
                    icon: Icon(isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, size: 22),
                    color: isBookmarked ? Colors.amber[400] : Colors.white70,
                    tooltip: isBookmarked ? 'Remove Bookmark' : 'Bookmark Document',
                    onPressed: _toggleBookmark,
                  ),

                  // AI Companion Toggle
                  IconButton(
                    icon: Icon(Icons.auto_awesome_rounded, color: _isAiSidebarOpen ? const Color(0xFF818CF8) : Colors.white70),
                    tooltip: 'EduSHAMIIT AI Document Assistant',
                    onPressed: () {
                      setState(() => _isAiSidebarOpen = !_isAiSidebarOpen);
                      if (_isAiSidebarOpen && _aiResult.isEmpty) _askAiAssistant();
                    },
                  ),

                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () {
                      _syncReadingProgress();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),

            // Main Document Content Area + Floating DRM Watermark + AI Sidebar
            Expanded(
              child: Row(
                children: [
                  // Real Embedded PDF Viewer Area
                  Expanded(
                    flex: 7,
                    child: Stack(
                      children: [
                        // Embedded Native Browser PDF Engine
                        if (kIsWeb && _pdfViewKey.isNotEmpty)
                          HtmlElementView(
                            key: ValueKey(_pdfViewKey),
                            viewType: _pdfViewKey,
                          )
                        else
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 64),
                                const SizedBox(height: 12),
                                Text(
                                  activeAsset != null ? activeAsset.displayTitle : widget.book.title,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Loading secure digital PDF stream...',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ),

                        // Anti-Piracy DRM Floating Watermark
                        IgnorePointer(
                          child: Center(
                            child: Transform.rotate(
                              angle: -0.3,
                              child: Text(
                                widget.watermarkText,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white.withOpacity(0.025),
                                  letterSpacing: 2.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // AI Companion Sidebar
                  if (_isAiSidebarOpen) ...[
                    const VerticalDivider(width: 1, color: Color(0xFF1E293B)),
                    Expanded(
                      flex: 4,
                      child: Container(
                        color: const Color(0xFF0B1120),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.auto_awesome, color: Color(0xFF818CF8), size: 18),
                                const SizedBox(width: 8),
                                const Text('AI Document Companion', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Colors.white)),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 16, color: Colors.white70),
                                  onPressed: () => setState(() => _isAiSidebarOpen = false),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              children: [
                                _aiActionChip('SUMMARIZE_PAGE', 'Summarize', Icons.short_text),
                                _aiActionChip('EXPLAIN_CONCEPT', 'Explain', Icons.lightbulb_outline),
                                _aiActionChip('GENERATE_QUIZ', 'Quiz Me', Icons.quiz_outlined),
                                _aiActionChip('VOCABULARY', 'Glossary', Icons.spellcheck),
                              ],
                            ),
                            const Divider(height: 20, color: Color(0xFF1E293B)),
                            Expanded(
                              child: _isAiLoading
                                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF818CF8), strokeWidth: 2.5))
                                  : SingleChildScrollView(
                                      child: SelectableText(
                                        _aiResult.isNotEmpty ? _aiResult : 'Select an AI action above to analyze this document.',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          height: 1.5,
                                          color: Color(0xFFCBD5E1),
                                        ),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Bottom Navigation Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF1E293B))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    activeAsset != null ? activeAsset.displayTitle : widget.book.title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('REAL PDF VIEWER', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                  const Spacer(),
                  if (hasPdf)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF334155)),
                      ),
                      icon: const Icon(Icons.open_in_new_rounded, size: 14),
                      label: const Text('Open in Full Tab', style: TextStyle(fontSize: 11.5)),
                      onPressed: () async {
                        final uri = Uri.tryParse(pdfUrl);
                        if (uri != null) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _aiActionChip(String actionKey, String label, IconData icon) {
    final isSelected = _aiQueryAction == actionKey;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      avatar: Icon(icon, size: 13, color: isSelected ? Colors.white : const Color(0xFF818CF8)),
      selected: isSelected,
      selectedColor: const Color(0xFF6366F1),
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: FontWeight.w600),
      onSelected: (v) {
        if (v) {
          setState(() => _aiQueryAction = actionKey);
          _askAiAssistant();
        }
      },
    );
  }
}
