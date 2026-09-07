import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/circulation_models.dart';
import '../../providers/circulation_provider.dart';

class RequestReturnDialog extends ConsumerStatefulWidget {
  final LibraryTransactionModel? transaction;
  final String? borrowId;
  final Map<String, dynamic>? rawTransactionData;

  const RequestReturnDialog({
    super.key,
    this.transaction,
    this.borrowId,
    this.rawTransactionData,
  });

  static Future<bool?> show(
    BuildContext context, {
    LibraryTransactionModel? transaction,
    String? borrowId,
    Map<String, dynamic>? rawTransactionData,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => RequestReturnDialog(
        transaction: transaction,
        borrowId: borrowId,
        rawTransactionData: rawTransactionData,
      ),
    );
  }

  @override
  ConsumerState<RequestReturnDialog> createState() => _RequestReturnDialogState();
}

class _RequestReturnDialogState extends ConsumerState<RequestReturnDialog> {
  final TextEditingController _notesCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  String get _borrowId {
    if (widget.transaction != null) return widget.transaction!.id;
    if (widget.borrowId != null && widget.borrowId!.isNotEmpty) return widget.borrowId!;
    return widget.rawTransactionData?['id']?.toString() ?? '';
  }

  String get _transactionCode {
    if (widget.transaction != null) return widget.transaction!.transactionCode;
    return widget.rawTransactionData?['transaction_code']?.toString() ?? 'TXN-0000';
  }

  String get _bookTitle {
    if (widget.transaction != null) return widget.transaction!.bookTitle;
    final book = widget.rawTransactionData?['book'];
    if (book is Map) {
      return book['title']?.toString() ?? 'Book';
    }
    return widget.rawTransactionData?['book_title']?.toString() ?? 'Book';
  }

  Future<void> _handleSubmit() async {
    final borrowId = _borrowId;
    if (borrowId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid transaction ID.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref.read(circulationProvider.notifier).requestReturnLoan(
        borrowId,
        reason: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Return request for "$_bookTitle" submitted successfully.'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        final errorText = e
            .toString()
            .replaceAll(RegExp(r'^(ApiException:|Exception:|\s*Api)+', caseSensitive: false), '')
            .trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorText.isNotEmpty ? errorText : 'Failed to submit return request.'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.keyboard_return_rounded, color: Color(0xFF10B981), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Request Book Return',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              size: 20,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to request the return of this book? The librarian will verify the physical condition upon receipt.',
              style: TextStyle(
                fontSize: 13.5,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.book_rounded,
                    size: 20,
                    color: isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _transactionCode,
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _bookTitle,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _notesCtrl,
              decoration: InputDecoration(
                labelText: 'Notes for Librarian (Optional)',
                hintText: 'e.g. Returning at main desk counter',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                labelStyle: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  fontSize: 13,
                ),
                hintStyle: TextStyle(
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  fontSize: 12.5,
                ),
              ),
              maxLines: 2,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _isSubmitting ? null : _handleSubmit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Submit Request', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
