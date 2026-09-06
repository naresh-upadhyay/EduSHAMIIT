import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/circulation_provider.dart';
import '../../models/circulation_models.dart';

import 'quick_issue_dialog.dart';
import 'quick_return_dialog.dart';

class CirculationBarcodeDialog extends ConsumerStatefulWidget {
  const CirculationBarcodeDialog({super.key});

  @override
  ConsumerState<CirculationBarcodeDialog> createState() => _CirculationBarcodeDialogState();
}

class _CirculationBarcodeDialogState extends ConsumerState<CirculationBarcodeDialog> {
  final TextEditingController _codeCtrl = TextEditingController();
  ScanResultModel? _result;
  bool _isScanning = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleScan(String code) async {
    if (code.trim().isEmpty) return;
    setState(() {
      _isScanning = true;
      _error = null;
    });

    try {
      final res = await ref.read(circulationProvider.notifier).scanLookup(code.trim());
      setState(() {
        _result = res;
        _isScanning = false;
        if (res == null) _error = 'No matching book, copy, or member found.';
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
        _error = e.toString().replaceAll("Exception:", "").trim();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 540,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF6366F1), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Scan Barcode / ISBN / Card',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Barcode Input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Scan or type barcode, ISBN, or Member Code...',
                      prefixIcon: const Icon(Icons.qr_code, size: 18),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onSubmitted: (val) => _handleScan(val),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onPressed: _isScanning ? null : () => _handleScan(_codeCtrl.text),
                  child: _isScanning
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Scan'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Result Preview
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12))),
                  ],
                ),
              )
            else if (_result != null) ...[
              _buildResultCard(_result!, isDark),
            ] else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Point your USB/Bluetooth barcode scanner here or type the identifier.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12.5),
                  ),
                ),
              ),

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(ScanResultModel scan, bool isDark) {
    final raw = scan.raw;
    final entityType = scan.entityType;

    if (entityType == 'BOOK_COPY') {
      final copy = raw['copy'] is Map ? raw['copy'] as Map<String, dynamic> : <String, dynamic>{};
      final book = raw['book'] is Map ? raw['book'] as Map<String, dynamic> : <String, dynamic>{};
      final activeLoan = raw['active_loan'] is Map ? raw['active_loan'] as Map<String, dynamic> : null;

      final isAvailable = copy['status'] == 'AVAILABLE';

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.menu_book_rounded, color: Color(0xFF6366F1), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(book['title']?.toString() ?? 'Book Title', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      Text('By ${book['author'] ?? 'Author'} • ISBN: ${book['isbn'] ?? 'N/A'}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      Text('Barcode: ${copy['barcode']} • Status: ${copy['status']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isAvailable)
              ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Issue This Book Copy'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.of(context).pop();
                  showDialog(
                    context: context,
                    builder: (_) => QuickIssueDialog(initialBookQuery: book['title']?.toString()),
                  );
                },
              )
            else if (activeLoan != null)
              ElevatedButton.icon(
                icon: const Icon(Icons.keyboard_return_rounded, size: 16),
                label: const Text('Return This Loan Now'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.of(context).pop();
                  showDialog(
                    context: context,
                    builder: (_) => QuickReturnDialog(initialBarcodeQuery: copy['barcode']?.toString()),
                  );
                },
              ),
          ],
        ),
      );
    } else if (entityType == 'MEMBER') {
      final member = raw['member'] is Map ? raw['member'] as Map<String, dynamic> : <String, dynamic>{};
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF6366F1),
                  child: Text(
                    (member['name']?.toString().isNotEmpty ?? false) ? member['name'][0] : 'M',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(member['name']?.toString() ?? 'Member Name', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      Text('${member['member_code']} • ${member['role']} • Limit: ${member['borrowing_limit']}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.menu_book_rounded, size: 16),
              label: const Text('Issue Books to this Member'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
              onPressed: () {
                Navigator.of(context).pop();
                showDialog(
                  context: context,
                  builder: (_) => QuickIssueDialog(initialMemberQuery: member['member_code']?.toString()),
                );
              },
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
