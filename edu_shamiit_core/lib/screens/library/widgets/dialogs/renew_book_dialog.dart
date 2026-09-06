import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/circulation_provider.dart';
import '../../models/circulation_models.dart';


class RenewBookDialog extends ConsumerStatefulWidget {
  final LibraryTransactionModel? transaction;
  final String? borrowId;

  const RenewBookDialog({
    super.key,
    this.transaction,
    this.borrowId,
  });

  @override
  ConsumerState<RenewBookDialog> createState() => _RenewBookDialogState();
}

class _RenewBookDialogState extends ConsumerState<RenewBookDialog> {
  LibraryTransactionModel? _selectedTx;
  late DateTime _newDueDate;
  final TextEditingController _reasonCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedTx = widget.transaction;
    _newDueDate = DateTime.now().add(const Duration(days: 14));

    if (_selectedTx == null && widget.borrowId != null) {
      final state = ref.read(circulationProvider);
      final found = state.transactions.where((t) => t.id == widget.borrowId).toList();
      if (found.isNotEmpty) _selectedTx = found.first;
    }
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(circulationProvider);

    final activeLoans = state.transactions.where((t) => t.status == 'ISSUED' || t.status == 'OVERDUE' || t.status == 'RENEWED').toList();

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
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
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.autorenew_rounded, color: Color(0xFF8B5CF6), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Renew Book Loan',
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

            // Select active loan if not preselected
            if (_selectedTx == null) ...[
              const Text('Select Active Loan:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<LibraryTransactionModel>(
                    isExpanded: true,
                    hint: const Text('Choose a loan to renew...'),
                    items: activeLoans.map((tx) {
                      return DropdownMenuItem(
                        value: tx,
                        child: Text('${tx.bookTitle} (${tx.memberName})', maxLines: 1, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedTx = val;
                          _newDueDate = (val.dueDate ?? DateTime.now()).add(const Duration(days: 14));
                        });
                      }
                    },
                  ),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildRow('Book Title:', _selectedTx!.bookTitle, isBold: true),
                    const SizedBox(height: 4),
                    _buildRow('Borrower:', '${_selectedTx!.memberName} (${_selectedTx!.memberCode})'),
                    const SizedBox(height: 4),
                    _buildRow('Current Due Date:', _selectedTx!.formattedDueDate),
                    const SizedBox(height: 4),
                    _buildRow('Renewals Used:', '${_selectedTx!.renewalsUsed} / ${_selectedTx!.maxRenewals}'),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            // New Due Date Picker
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _newDueDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 90)),
                );
                if (picked != null) {
                  setState(() => _newDueDate = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF8B5CF6)),
                        const SizedBox(width: 8),
                        Text('New Due Date: ${DateFormat('dd MMM yyyy').format(_newDueDate)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ],
                    ),
                    const Text('Change', style: TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.w600, fontSize: 12)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Reason
            TextField(
              controller: _reasonCtrl,
              decoration: InputDecoration(
                hintText: 'Renewal reason (e.g. exam preparation, extended project)...',
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 20),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.autorenew_rounded, size: 16),
                  label: _isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Confirm Renewal'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: (_selectedTx != null && !_isSubmitting) ? _handleRenewal : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        Text(value, style: TextStyle(fontSize: 12.5, fontWeight: isBold ? FontWeight.w800 : FontWeight.w600)),
      ],
    );
  }

  Future<void> _handleRenewal() async {
    if (_selectedTx == null) return;
    setState(() => _isSubmitting = true);

    final success = await ref.read(circulationProvider.notifier).renewBook(
      borrowId: _selectedTx!.id,
      newDueDate: DateFormat('yyyy-MM-dd').format(_newDueDate),
      reason: _reasonCtrl.text.trim().isNotEmpty ? _reasonCtrl.text.trim() : null,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Book loan renewed successfully!'), backgroundColor: Color(0xFF10B981)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.read(circulationProvider).errorMessage ?? 'Failed to renew book loan.'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }
}
