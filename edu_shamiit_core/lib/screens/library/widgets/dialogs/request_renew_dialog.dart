import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/circulation_models.dart';
import '../../providers/circulation_provider.dart';

class RequestRenewDialog extends ConsumerStatefulWidget {
  final LibraryTransactionModel transaction;

  const RequestRenewDialog({
    super.key,
    required this.transaction,
  });

  @override
  ConsumerState<RequestRenewDialog> createState() => _RequestRenewDialogState();
}

class _RequestRenewDialogState extends ConsumerState<RequestRenewDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonCtrl = TextEditingController();
  late DateTime _requestedDueDate;
  String _selectedReasonPreset = 'Still reading and completing coursework';
  bool _isSubmitting = false;

  final List<String> _presets = [
    'Still reading and completing coursework',
    'Required for upcoming semester exams',
    'Project reference work ongoing',
    'Faculty recommendation extension',
    'Other reason (specified below)',
  ];

  @override
  void initState() {
    super.initState();
    final currentDue = widget.transaction.dueDate ?? DateTime.now();
    _requestedDueDate = currentDue.add(const Duration(days: 14));
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final reasonStr = _reasonCtrl.text.trim().isNotEmpty
        ? '[$_selectedReasonPreset] ${_reasonCtrl.text.trim()}'
        : _selectedReasonPreset;

    final dueDateStr = DateFormat('yyyy-MM-dd').format(_requestedDueDate);

    final success = await ref.read(circulationProvider.notifier).requestRenewLoan(
      widget.transaction.id,
      reason: reasonStr,
      newDueDate: dueDateStr,
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
    final tx = widget.transaction;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
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
                        color: const Color(0xFF8B5CF6).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.autorenew_rounded, size: 22, color: Color(0xFF8B5CF6)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Request Book Loan Renewal',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Submit a loan extension request for librarian approval.',
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

              // Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Book Loan Summary Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tx.bookTitle,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Author: ${tx.bookAuthor} · Barcode: ${tx.copyBarcode}',
                              style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Current Due Date', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                    const SizedBox(height: 2),
                                    Text(tx.formattedDueDate, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('Renewals Used', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                    const SizedBox(height: 2),
                                    Text('${tx.renewalsUsed} of ${tx.maxRenewals}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF8B5CF6))),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Reason preset
                      const Text('Reason for Extension *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedReasonPreset,
                        decoration: _inputDecoration(isDark),
                        items: _presets.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 12.5)))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedReasonPreset = val);
                        },
                      ),
                      const SizedBox(height: 14),

                      // Desired new due date
                      const Text('Requested New Due Date', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final currentDue = widget.transaction.dueDate ?? DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _requestedDueDate,
                            firstDate: currentDue,
                            lastDate: currentDue.add(const Duration(days: 60)),
                          );
                          if (picked != null) setState(() => _requestedDueDate = picked);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.event_available_rounded, size: 16, color: Color(0xFF8B5CF6)),
                              const SizedBox(width: 8),
                              Text(DateFormat('dd MMM yyyy').format(_requestedDueDate), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Additional details
                      const Text('Additional Details (Optional)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _reasonCtrl,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 13),
                        decoration: _inputDecoration(isDark, hintText: 'Any extra message for the librarian...'),
                      ),
                    ],
                  ),
                ),
              ),

              // Footer
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
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      icon: _isSubmitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded, size: 16),
                      label: Text(_isSubmitting ? 'Submitting...' : 'Submit Renewal Request'),
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
        borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
      ),
    );
  }
}
