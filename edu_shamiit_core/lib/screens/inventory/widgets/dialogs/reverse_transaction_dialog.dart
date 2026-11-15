import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/inventory_models.dart';
import '../../providers/inventory_provider.dart';

class ReverseTransactionDialog extends ConsumerStatefulWidget {
  final InventoryMovement movement;

  const ReverseTransactionDialog({super.key, required this.movement});

  @override
  ConsumerState<ReverseTransactionDialog> createState() => _ReverseTransactionDialogState();
}

class _ReverseTransactionDialogState extends ConsumerState<ReverseTransactionDialog> {
  final _reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tx = widget.movement;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.undo_rounded, color: Color(0xFFEA580C), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reverse Transaction',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Creates an immutable compensatory ledger entry',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Details card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildDetailRow('Item:', tx.itemName, isDark),
                  const SizedBox(height: 6),
                  _buildDetailRow('Movement Type:', tx.movementType, isDark),
                  const SizedBox(height: 6),
                  _buildDetailRow('Quantity:', '${tx.quantity > 0 ? '+' : ''}${tx.quantity}', isDark),
                  const SizedBox(height: 6),
                  _buildDetailRow('Store Location:', tx.storeName, isDark),
                  const SizedBox(height: 6),
                  _buildDetailRow('Reference:', tx.referenceNumber ?? '-', isDark),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Form(
              key: _formKey,
              child: TextFormField(
                controller: _reasonController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Reason for Reversal *',
                  hintText: 'e.g. Data entry error or duplicate posting by cashier',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                validator: (v) => v?.trim().isEmpty ?? true ? 'Reason is mandatory for audit trail' : null,
              ),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C),
                    foregroundColor: Colors.white,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Confirm Compensatory Reversal'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
        Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final success = await ref.read(inventoryProvider.notifier).reverseTransaction(
          widget.movement.movementId,
          _reasonController.text.trim(),
        );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction successfully reversed with compensatory entry!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to reverse transaction.')),
        );
      }
    }
  }
}
