import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/book_provider.dart';

class ScanBookDialog extends ConsumerStatefulWidget {
  const ScanBookDialog({super.key});

  @override
  ConsumerState<ScanBookDialog> createState() => _ScanBookDialogState();
}

class _ScanBookDialogState extends ConsumerState<ScanBookDialog> {
  final TextEditingController _codeCtrl = TextEditingController();
  bool _isSearching = false;
  Map<String, dynamic>? _resolvedCopy;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchCode() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isSearching = true;
      _error = null;
      _resolvedCopy = null;
    });

    try {
      final api = ref.read(libraryApiServiceProvider);
      final res = await api.lookupByScan(code);
      setState(() {
        _isSearching = false;
        _resolvedCopy = res['data'] as Map<String, dynamic>?;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
        _error = 'No physical book copy matching "$code" was found in your library.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF6366F1), size: 22),
                  const SizedBox(width: 10),
                  const Text('Scan & Lookup Book', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter or Scan Barcode, QR Code, or Accession Number:',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _codeCtrl,
                          autofocus: true,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'e.g. BC000001-01 or PSY-MONEY-001',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          onSubmitted: (_) => _searchCode(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onPressed: _isSearching ? null : _searchCode,
                        child: _isSearching
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Lookup'),
                      ),
                    ],
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_resolvedCopy != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _resolvedCopy!['book_title'] ?? '',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _resolvedCopy!['status'] ?? 'AVAILABLE',
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Author: ${_resolvedCopy!['book_author']} • Category: ${_resolvedCopy!['book_category']}',
                            style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Accession: ${_resolvedCopy!['accession_number']}', style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace')),
                              Text('Location: ${_resolvedCopy!['location'] ?? 'Main Section'}', style: const TextStyle(fontSize: 11.5)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                              label: const Text('Open Book Details'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () {
                                final bookId = _resolvedCopy!['book_id'];
                                Navigator.pop(context);
                                ref.read(bookProvider.notifier).selectBookForDrawer(bookId.toString());
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
