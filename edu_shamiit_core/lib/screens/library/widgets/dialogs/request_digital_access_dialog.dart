import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/book_models.dart';
import '../../providers/book_provider.dart';

/// Dialog for Students & Teachers to request digital access for restricted books
class RequestDigitalAccessDialog extends ConsumerStatefulWidget {
  final BookModel book;

  const RequestDigitalAccessDialog({
    super.key,
    required this.book,
  });

  static Future<bool?> show(BuildContext context, BookModel book) {
    return showDialog<bool>(
      context: context,
      builder: (context) => RequestDigitalAccessDialog(book: book),
    );
  }

  @override
  ConsumerState<RequestDigitalAccessDialog> createState() => _RequestDigitalAccessDialogState();
}

class _RequestDigitalAccessDialogState extends ConsumerState<RequestDigitalAccessDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _reasonController = TextEditingController();
  String _accessScope = 'FULL';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final success = await ref.read(bookProvider.notifier).requestDigitalAccess(
      widget.book.id,
      reason: _reasonController.text.trim(),
      accessScope: _accessScope,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF10B981),
            content: Text('Digital access request submitted! The librarian will review it.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 480,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.vpn_key, color: Color(0xFF4F46E5), size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Request Digital Access',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                          ),
                          Text(
                            widget.book.title,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Info Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18, color: Color(0xFF475569)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This ${widget.book.bookTypeName} requires librarian approval. Once approved, you can stream it securely in-app.',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Purpose / Reason
                const Text(
                  'Purpose / Reason for Access *',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _reasonController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'e.g. Preparing for class assignment or academic research...',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please provide a reason' : null,
                ),
                const SizedBox(height: 16),

                // Access Scope
                const Text(
                  'Requested Scope',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _accessScope,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),

                  items: const [
                    DropdownMenuItem(value: 'FULL', child: Text('Full In-App Streaming Access')),
                    DropdownMenuItem(value: 'READ_ONLY', child: Text('Read-Only (30 Days)')),
                    DropdownMenuItem(value: 'CUSTOM', child: Text('Short-Term Study (7 Days)')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _accessScope = v);
                  },
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send, size: 16),
                      label: const Text('Submit Request', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
