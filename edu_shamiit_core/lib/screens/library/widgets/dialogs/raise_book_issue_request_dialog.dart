import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/book_models.dart';
import '../../providers/circulation_provider.dart';
import '../../../../../config/app_config.dart';

class RaiseBookIssueRequestDialog extends ConsumerStatefulWidget {
  final BookModel book;

  const RaiseBookIssueRequestDialog({
    super.key,
    required this.book,
  });

  @override
  ConsumerState<RaiseBookIssueRequestDialog> createState() => _RaiseBookIssueRequestDialogState();
}

class _RaiseBookIssueRequestDialogState extends ConsumerState<RaiseBookIssueRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  
  DateTime? _requiredByDate = DateTime.now().add(const Duration(days: 14));
  String _selectedPurpose = 'Coursework & Assignment';
  String _selectedFormat = 'Physical Book';
  bool _isSubmitting = false;

  final List<String> _purposes = [
    'Coursework & Assignment',
    'Exam Preparation',
    'Academic Research',
    'Classroom Reference',
    'Leisure & General Reading',
    'Other Purpose',
  ];

  final List<String> _formats = [
    'Physical Book',
    'Paperback',
    'Hardcover',
    'E-Book (Digital)',
  ];

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final reasonStr = _reasonCtrl.text.trim().isNotEmpty
        ? '[$_selectedPurpose] ${_reasonCtrl.text.trim()}'
        : _selectedPurpose;

    final reqDateStr = _requiredByDate != null ? DateFormat('yyyy-MM-dd').format(_requiredByDate!) : null;

    final success = await ref.read(circulationProvider.notifier).raiseIssueRequest(
      bookId: widget.book.id,
      requiredBy: reqDateStr,
      reason: reasonStr,
      notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      preferredFormat: _selectedFormat,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final book = widget.book;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.bookmark_add_rounded, size: 22, color: Color(0xFF6366F1)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Raise Book Issue Request',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Request will be sent to the library desk for reservation and issuance.',
                            style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ),

              // Scrollable Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Book Info Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Book Thumbnail
                            Container(
                              width: 52,
                              height: 72,
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: (book.coverUrl != null && book.coverUrl!.isNotEmpty)
                                  ? Image.network(
                                      AppConfig.resolveUrl(book.coverUrl!),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Center(
                                        child: Icon(Icons.menu_book_rounded, size: 26, color: Color(0xFF6366F1)),
                                      ),
                                    )
                                  : const Center(
                                      child: Icon(Icons.menu_book_rounded, size: 26, color: Color(0xFF6366F1)),
                                    ),
                            ),
                            const SizedBox(width: 14),
                            // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    book.title,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'By ${book.author}',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: book.availableCopies > 0
                                              ? const Color(0xFF10B981).withOpacity(0.15)
                                              : const Color(0xFFEF4444).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          book.availableCopies > 0
                                              ? '${book.availableCopies} Copies Available'
                                              : 'Currently Out of Stock (Waitlist)',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: book.availableCopies > 0
                                                ? const Color(0xFF10B981)
                                                : const Color(0xFFEF4444),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'ISBN: ${book.displayIsbn}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Form Fields
                      // Purpose Dropdown
                      const Text(
                        'Borrow Purpose / Category *',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedPurpose,
                        decoration: _inputDecoration(isDark),
                        items: _purposes.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedPurpose = val);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Row: Required By Date & Preferred Format
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Required By Date
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Required By Date',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _requiredByDate ?? DateTime.now().add(const Duration(days: 14)),
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now().add(const Duration(days: 90)),
                                    );
                                    if (picked != null) {
                                      setState(() => _requiredByDate = picked);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF6366F1)),
                                        const SizedBox(width: 8),
                                        Text(
                                          _requiredByDate != null ? DateFormat('dd MMM yyyy').format(_requiredByDate!) : 'Select date',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Preferred Format
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Preferred Format',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  value: _selectedFormat,
                                  decoration: _inputDecoration(isDark),
                                  items: _formats.map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 13)))).toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedFormat = val);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Reason / Description
                      const Text(
                        'Reason / Reference Notes',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _reasonCtrl,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 13),
                        decoration: _inputDecoration(
                          isDark,
                          hintText: 'e.g. Reference material for Chapter 4 project or semester exam prep',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Notice Box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.25)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF6366F1)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Once approved by the librarian, you can collect the physical copy from the library circulation counter.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Footer Actions
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      icon: _isSubmitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded, size: 16),
                      label: Text(_isSubmitting ? 'Submitting...' : 'Submit Issue Request'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(bool isDark, {String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(fontSize: 12.5, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
      ),
    );
  }
}
