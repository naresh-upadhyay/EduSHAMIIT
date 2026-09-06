import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/circulation_provider.dart';



class FineCollectionDialog extends ConsumerStatefulWidget {
  final String? fineId;
  final String? memberId;

  const FineCollectionDialog({
    super.key,
    this.fineId,
    this.memberId,
  });

  @override
  ConsumerState<FineCollectionDialog> createState() => _FineCollectionDialogState();
}

class _FineCollectionDialogState extends ConsumerState<FineCollectionDialog> {
  List<Map<String, dynamic>> _fines = [];
  Map<String, dynamic>? _selectedFine;
  bool _isLoading = true;
  bool _isSubmitting = false;

  bool _isWaiveMode = false;
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _refCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  String _paymentMethod = 'CASH';

  @override
  void initState() {
    super.initState();
    _loadFines();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFines() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(circulationApiServiceProvider);
      final list = await api.fetchFines(status: 'UNPAID', memberId: widget.memberId);
      setState(() {
        _fines = list;
        if (widget.fineId != null) {
          final found = list.where((f) => f['id'] == widget.fineId).toList();
          if (found.isNotEmpty) {
            _selectedFine = found.first;
            _amountCtrl.text = (_selectedFine!['outstanding_amount'] as num? ?? _selectedFine!['amount'] as num? ?? 0).toString();
          }
        } else if (list.isNotEmpty) {
          _selectedFine = list.first;
          _amountCtrl.text = (_selectedFine!['outstanding_amount'] as num? ?? _selectedFine!['amount'] as num? ?? 0).toString();
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
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
                        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.currency_rupee_rounded, color: Color(0xFFEF4444), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isWaiveMode ? 'Waive Library Fine' : 'Collect Fine Payment',
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

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(color: Color(0xFFEF4444))),
              )
            else if (_fines.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'No outstanding library fines found.',
                    style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ),
              )
            else ...[
              // Fine Selection
              const Text('Select Fine Record:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Map<String, dynamic>>(
                    value: _selectedFine,
                    isExpanded: true,
                    items: _fines.map((f) {
                      final member = f['member_name'] ?? 'Member';
                      final amt = f['outstanding_amount'] ?? f['amount'] ?? 0;
                      final book = f['book_title'] ?? 'Book';
                      return DropdownMenuItem(
                        value: f,
                        child: Text('$member — ₹$amt ($book)', maxLines: 1, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedFine = val;
                          _amountCtrl.text = (val['outstanding_amount'] ?? val['amount'] ?? 0).toString();
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Action Mode Toggle: Collect vs Waive
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Payment Collection'),
                    selected: !_isWaiveMode,
                    selectedColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                    onSelected: (val) => setState(() => _isWaiveMode = !val),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Waive Fine'),
                    selected: _isWaiveMode,
                    selectedColor: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    onSelected: (val) => setState(() => _isWaiveMode = val),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Amount Input
              TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount (₹)',
                  prefixIcon: const Icon(Icons.currency_rupee, size: 16),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),

              if (!_isWaiveMode) ...[
                // Payment Method
                Row(
                  children: [
                    const Text('Payment Method: ', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 10),
                    DropdownButton<String>(
                      value: _paymentMethod,
                      items: const [
                        DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                        DropdownMenuItem(value: 'UPI', child: Text('UPI / QR')),
                        DropdownMenuItem(value: 'CARD', child: Text('Card')),
                        DropdownMenuItem(value: 'ONLINE', child: Text('Online / NetBanking')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _paymentMethod = val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Transaction Reference
                TextField(
                  controller: _refCtrl,
                  decoration: InputDecoration(
                    hintText: 'Transaction Ref / Receipt No. (optional)',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ] else ...[
                // Waiver Reason (Mandatory)
                TextField(
                  controller: _notesCtrl,
                  decoration: InputDecoration(
                    hintText: 'Reason for waiver (e.g. Principal approval, medical leave)...',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ],

            const SizedBox(height: 20),

            // Submit Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: Icon(_isWaiveMode ? Icons.shield_outlined : Icons.check_circle_outline, size: 16),
                  label: _isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_isWaiveMode ? 'Confirm Waiver' : 'Record Payment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isWaiveMode ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: (_selectedFine != null && !_isSubmitting) ? _handleSubmission : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmission() async {
    if (_selectedFine == null) return;
    final amt = double.tryParse(_amountCtrl.text.trim());
    if (amt == null || amt <= 0) return;

    setState(() => _isSubmitting = true);

    bool success = false;
    if (_isWaiveMode) {
      if (_notesCtrl.text.trim().isEmpty) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please specify a waiver reason.'), backgroundColor: Color(0xFFEF4444)),
        );
        return;
      }
      success = await ref.read(circulationProvider.notifier).waiveFine(
        fineId: _selectedFine!['id'],
        amount: amt,
        reason: _notesCtrl.text.trim(),
      );
    } else {
      success = await ref.read(circulationProvider.notifier).collectFine(
        fineId: _selectedFine!['id'],
        amount: amt,
        paymentMethod: _paymentMethod,
        reference: _refCtrl.text.trim().isNotEmpty ? _refCtrl.text.trim() : null,
        notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      );
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isWaiveMode ? 'Fine waived successfully!' : 'Payment recorded successfully!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.read(circulationProvider).errorMessage ?? 'Operation failed.'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }
}
