import '../../services/inventory_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/inventory_models.dart';
import '../../providers/inventory_provider.dart';

class ReceiveGrnDialog extends ConsumerStatefulWidget {
  final PurchaseOrder po;

  const ReceiveGrnDialog({super.key, required this.po});

  @override
  ConsumerState<ReceiveGrnDialog> createState() => _ReceiveGrnDialogState();
}

class _ReceiveGrnDialogState extends ConsumerState<ReceiveGrnDialog> {
  final _formKey = GlobalKey<FormState>();

  final _challanController = TextEditingController();
  final _vehicleController = TextEditingController();
  final _notesController = TextEditingController();
  final List<TextEditingController> _receivedQtyControllers = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    for (var item in widget.po.items) {
      final remaining = (item.quantity - item.receivedQuantity).clamp(0, item.quantity);
      _receivedQtyControllers.add(TextEditingController(text: '${remaining.toInt()}'));
    }
  }

  @override
  void dispose() {
    _challanController.dispose();
    _vehicleController.dispose();
    _notesController.dispose();
    for (var c in _receivedQtyControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final po = widget.po;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 720,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.archive_outlined, color: Color(0xFF10B981), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Receive Goods (GRN) – ${po.poNumber}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Supplier: ${po.supplierName} • Total Items: ${po.itemsCount}',
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

            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _challanController,
                              decoration: InputDecoration(
                                labelText: 'Delivery Challan / Invoice #',
                                hintText: 'e.g., DC-88219',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextFormField(
                              controller: _vehicleController,
                              decoration: InputDecoration(
                                labelText: 'Vehicle / Transporter Info',
                                hintText: 'e.g. DL-01-AB-1234',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      Text(
                        'Verify Received Quantities',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 8),

                      if (po.items.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'All items in this purchase order will be marked received and added to store balances.',
                            style: TextStyle(fontSize: 13, fontFamily: 'Inter'),
                          ),
                        )
                      else
                        ...po.items.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final item = entry.value;
                          final controller = _receivedQtyControllers[idx];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.itemName,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                      Text(
                                        'Ordered: ${item.quantity.toInt()} | Previously Received: ${item.receivedQuantity.toInt()}',
                                        style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                SizedBox(
                                  width: 120,
                                  child: TextFormField(
                                    controller: controller,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Receiving Now',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (v) {
                                      final val = double.tryParse(v ?? '');
                                      if (val == null || val < 0) return 'Invalid';
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _notesController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Inspection Remarks / Condition Notes',
                          hintText: 'e.g. All cartons inspected in good condition, seal intact',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

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
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Confirm GRN & Intake Stock'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final grnData = {
      'delivery_challan_number': _challanController.text.trim().isEmpty ? null : _challanController.text.trim(),
      'vehicle_number': _vehicleController.text.trim().isEmpty ? null : _vehicleController.text.trim(),
      'notes': _notesController.text.trim(),
    };

    List<Map<String, dynamic>> receivedItems = [];
    if (widget.po.items.isNotEmpty) {
      for (int i = 0; i < widget.po.items.length; i++) {
        final line = widget.po.items[i];
        final q = double.tryParse(_receivedQtyControllers[i].text) ?? 0;
        if (q > 0) {
          receivedItems.add({
            'po_item_id': line.poItemId,
            'item_id': line.itemId,
            'quantity_received': q,
            'received_quantity': q,
          });
        }
      }
    }

    try {
      final res = await ref.read(inventoryApiServiceProvider).receiveGoodsReceipt(
            widget.po.poId,
            grnData,
            receivedItems,
          );
      if (mounted) {
        setState(() => _isSubmitting = false);
        if (res['success'] == true) {
          ref.read(inventoryProvider.notifier).loadPurchaseOrders();
          ref.read(inventoryProvider.notifier).loadItems();
          ref.read(inventoryProvider.notifier).loadMovements();
          ref.read(inventoryProvider.notifier).loadOverview();
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('GRN ${res['grn_number'] ?? ''} created! Stock updated.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['error'] ?? 'Failed to receive goods')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
