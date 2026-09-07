import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/circulation_provider.dart';
import '../../models/circulation_models.dart';



class QuickReturnDialog extends ConsumerStatefulWidget {
  final String? initialBarcodeQuery;
  final LibraryTransactionModel? transaction;

  const QuickReturnDialog({super.key, this.initialBarcodeQuery, this.transaction});

  @override
  ConsumerState<QuickReturnDialog> createState() => _QuickReturnDialogState();
}

class _QuickReturnDialogState extends ConsumerState<QuickReturnDialog> {
  final TextEditingController _lookupCtrl = TextEditingController();
  LibraryTransactionModel? _matchedTransaction;

  String _condition = 'GOOD';
  bool _collectFine = false;
  String _paymentMethod = 'CASH';
  final TextEditingController _paymentRefCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  bool _isSearching = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      _matchedTransaction = widget.transaction;
      _collectFine = widget.transaction!.fineAmount > 0;
      _lookupCtrl.text = widget.transaction!.copyBarcode != 'N/A'
          ? widget.transaction!.copyBarcode
          : widget.transaction!.transactionCode;
    } else if (widget.initialBarcodeQuery != null && widget.initialBarcodeQuery!.isNotEmpty) {
      _lookupCtrl.text = widget.initialBarcodeQuery!;
      _performLookup(widget.initialBarcodeQuery!);
    }
  }

  @override
  void dispose() {
    _lookupCtrl.dispose();
    _paymentRefCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _performLookup(String code) async {
    if (code.trim().isEmpty) return;
    setState(() => _isSearching = true);

    try {
      final state = ref.read(circulationProvider);
      // Search in transactions list first
      final found = state.transactions.where((t) {
        final q = code.trim().toLowerCase();
        return t.copyBarcode.toLowerCase() == q ||
            t.copyAccession.toLowerCase() == q ||
            t.transactionCode.toLowerCase() == q ||
            t.id.toLowerCase() == q;
      }).toList();

      if (found.isNotEmpty) {
        setState(() {
          _matchedTransaction = found.first;
          _collectFine = found.first.fineAmount > 0;
          _isSearching = false;
        });
        return;
      }

      // Or fallback scan lookup
      final scan = await ref.read(circulationProvider.notifier).scanLookup(code.trim());
      if (scan != null && scan.raw['active_loan'] != null) {
        final activeLoan = scan.raw['active_loan'] as Map<String, dynamic>;
        setState(() {
          _matchedTransaction = LibraryTransactionModel.fromJson(activeLoan);
          _collectFine = (_matchedTransaction?.fineAmount ?? 0) > 0;
          _isSearching = false;
        });
      } else {
        setState(() {
          _matchedTransaction = null;
          _isSearching = false;
        });
      }
    } catch (e) {
      setState(() {
        _matchedTransaction = null;
        _isSearching = false;
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
        width: 580,
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
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.keyboard_return_rounded, color: Color(0xFF10B981), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Process Book Return',
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

            // Search Barcode input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _lookupCtrl,
                    decoration: InputDecoration(
                      hintText: 'Enter book barcode, accession or transaction ID...',
                      prefixIcon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onSubmitted: (val) => _performLookup(val),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onPressed: _isSearching ? null : () => _performLookup(_lookupCtrl.text),
                  child: _isSearching
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Find Loan'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_matchedTransaction != null) ...[
              // Book & Member Summary Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildRow('Book Title:', _matchedTransaction!.bookTitle, isBold: true),
                    const SizedBox(height: 4),
                    _buildRow('Borrower:', '${_matchedTransaction!.memberName} (${_matchedTransaction!.memberCode})'),
                    const SizedBox(height: 4),
                    _buildRow('Due Date:', _matchedTransaction!.formattedDueDate),
                    if (_matchedTransaction!.daysOverdue > 0) ...[
                      const SizedBox(height: 4),
                      _buildRow(
                        'Overdue:',
                        '${_matchedTransaction!.daysOverdue} days overdue',
                        color: const Color(0xFFEF4444),
                      ),
                      const SizedBox(height: 4),
                      _buildRow(
                        'Calculated Fine:',
                        _matchedTransaction!.formattedFine,
                        color: const Color(0xFFEF4444),
                        isBold: true,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Book Condition Dropdown
              Row(
                children: [
                  const Text('Return Condition: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _condition,
                          items: const [
                            DropdownMenuItem(value: 'GOOD', child: Text('Good Condition')),
                            DropdownMenuItem(value: 'MINOR_DAMAGE', child: Text('Minor Wear & Tear')),
                            DropdownMenuItem(value: 'DAMAGED', child: Text('Damaged (Fine Charged)')),
                            DropdownMenuItem(value: 'LOST', child: Text('Lost Book')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _condition = val);
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Fine settlement checkbox
              if (_matchedTransaction!.fineAmount > 0) ...[
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _collectFine,
                  title: Text(
                    'Collect Fine Payment of ${_matchedTransaction!.formattedFine}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  onChanged: (val) => setState(() => _collectFine = val ?? false),
                ),
                if (_collectFine) ...[
                  Row(
                    children: [
                      const Text('Payment Mode: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 10),
                      DropdownButton<String>(
                        value: _paymentMethod,
                        items: const [
                          DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                          DropdownMenuItem(value: 'UPI', child: Text('UPI / QR')),
                          DropdownMenuItem(value: 'CARD', child: Text('Card')),
                          DropdownMenuItem(value: 'WAIVED', child: Text('Waived')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _paymentMethod = val);
                        },
                      ),
                    ],
                  ),
                ],
              ],

              const SizedBox(height: 12),
              // Notes
              TextField(
                controller: _notesCtrl,
                decoration: InputDecoration(
                  hintText: 'Return remarks or damage notes (optional)...',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Enter a barcode, accession, or select a transaction from the table to proceed.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // Submit Button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_matchedTransaction?.status.toUpperCase() == 'PENDING_RETURN') ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFEF4444)),
                    label: const Text('Reject Request', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFEF4444)),
                    ),
                    onPressed: _isSubmitting ? null : _handleRejectReturn,
                  ),
                  const SizedBox(width: 12),
                ],
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                  label: _isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_matchedTransaction?.status.toUpperCase() == 'PENDING_RETURN' ? 'Accept & Return' : 'Confirm Return'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: (_matchedTransaction != null && !_isSubmitting) ? _handleReturnSubmission : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRejectReturn() async {
    if (_matchedTransaction == null) return;
    setState(() => _isSubmitting = true);
    final success = await ref.read(circulationProvider.notifier).rejectBorrowRequest(
      _matchedTransaction!.id,
      notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : 'Return request rejected by librarian',
    );
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Return request rejected. Book loan remains active.'), backgroundColor: Color(0xFF10B981)),
        );
      }
    }
  }

  Widget _buildRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Future<void> _handleReturnSubmission() async {
    if (_matchedTransaction == null) return;
    setState(() => _isSubmitting = true);

    final success = await ref.read(circulationProvider.notifier).returnBooks(
      items: [
        {
          'borrow_id': _matchedTransaction!.id,
          'condition': _condition,
          'notes': _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
        }
      ],
      collectFine: _collectFine,
      paymentMethod: _paymentMethod,
      paymentRef: _paymentRefCtrl.text.trim().isNotEmpty ? _paymentRefCtrl.text.trim() : null,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Book returned successfully!'), backgroundColor: Color(0xFF10B981)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.read(circulationProvider).errorMessage ?? 'Failed to return book.'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }
}
