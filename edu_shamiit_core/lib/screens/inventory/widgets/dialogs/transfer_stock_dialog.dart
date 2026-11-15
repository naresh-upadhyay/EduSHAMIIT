import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/inventory_models.dart';
import '../../providers/inventory_provider.dart';
import '../inventory_searchable_dropdown.dart';

class TransferStockDialog extends ConsumerStatefulWidget {
  final InventoryItem? preselectedItem;

  const TransferStockDialog({super.key, this.preselectedItem});

  @override
  ConsumerState<TransferStockDialog> createState() => _TransferStockDialogState();
}

class _TransferStockDialogState extends ConsumerState<TransferStockDialog> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedItemId;
  String? _fromStoreId;
  String? _toStoreId;
  final _qtyController = TextEditingController(text: '5');
  final _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.preselectedItem != null) {
      _selectedItemId = widget.preselectedItem!.itemId;
      _fromStoreId = widget.preselectedItem!.preferredStoreId;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(inventoryProvider.notifier).loadCatalogItems();
    });
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryProvider);
    final metadata = state.metadata;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final stores = metadata?.stores ?? [];
    if (_fromStoreId == null && stores.isNotEmpty) {
      _fromStoreId = stores.first.storeId;
    }
    if (_toStoreId == null && stores.length > 1) {
      _toStoreId = stores[1].storeId;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 580,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
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
                    color: const Color(0xFFFAF5FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF8B5CF6), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inter-Store Transfer',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Transfer inventory between campus storage facilities',
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

            Flexible(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                  // Item selection
                  InventorySearchableDropdown<InventoryItem>(
                    label: 'Select Item',
                    value: _selectedItemId,
                    hint: 'Search item or type new to add...',
                    isRequired: true,
                    items: state.catalogItems.isNotEmpty ? state.catalogItems : state.items,
                    getItemId: (it) => it.itemId,
                    getItemName: (it) => it.name,
                    getItemSubtitle: (it) => 'SKU: ${it.sku} • Available: ${it.currentStock.toInt()} ${it.uomCode}',
                    getItemBadge: (it) => it.category,
                    prefixIcon: Icons.inventory_2_outlined,
                    allowManualEntry: true,
                    quickAddLabel: 'Quick create item & add to catalog & lookups',
                    onChanged: (val) => setState(() => _selectedItemId = val),
                    onQuickAdd: (text) async {
                      final created = await ref.read(inventoryProvider.notifier).quickAddItem(
                        itemName: text,
                        storeId: _fromStoreId,
                      );
                      return created?.itemId;
                    },
                  ),
                  const SizedBox(height: 14),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: InventorySearchableDropdown<InventoryDropdownItem>(
                          label: 'Source Store',
                          value: _fromStoreId,
                          hint: 'Select or add store...',
                          isRequired: true,
                          items: stores,
                          getItemId: (s) => s.storeId,
                          getItemName: (s) => s.storeName,
                          getItemSubtitle: (s) => s.code.isNotEmpty ? 'Code: ${s.code}' : null,
                          prefixIcon: Icons.store_rounded,
                          allowManualEntry: true,
                          quickAddLabel: 'Add store to Lookups & Stores list',
                          onChanged: (val) => setState(() => _fromStoreId = val),
                          onQuickAdd: (text) async {
                            final added = await ref.read(inventoryProvider.notifier).quickAddLookup(
                              keyCode: 'INVENTORY_STORES',
                              valueName: text,
                              description: 'Quick added store from Transfer Stock',
                            );
                            return added?.id ?? added?.code;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Padding(
                        padding: EdgeInsets.only(top: 28),
                        child: Icon(Icons.arrow_forward_rounded, size: 20, color: Color(0xFF8B5CF6)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InventorySearchableDropdown<InventoryDropdownItem>(
                          label: 'Destination Store',
                          value: _toStoreId,
                          hint: 'Select or add store...',
                          isRequired: true,
                          items: stores,
                          getItemId: (s) => s.storeId,
                          getItemName: (s) => s.storeName,
                          getItemSubtitle: (s) => s.code.isNotEmpty ? 'Code: ${s.code}' : null,
                          prefixIcon: Icons.store_rounded,
                          allowManualEntry: true,
                          quickAddLabel: 'Add store to Lookups & Stores list',
                          onChanged: (val) => setState(() => _toStoreId = val),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Destination required';
                            if (v == _fromStoreId) return 'Must be different';
                            return null;
                          },
                          onQuickAdd: (text) async {
                            final added = await ref.read(inventoryProvider.notifier).quickAddLookup(
                              keyCode: 'INVENTORY_STORES',
                              valueName: text,
                              description: 'Quick added store from Transfer Stock',
                            );
                            return added?.id ?? added?.code;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _qtyController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Transfer Quantity *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Enter valid qty' : null,
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Transfer Reason / Dispatch Note',
                      hintText: 'e.g. Rebalancing lab materials for practical exams',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
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
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Transfer Stock'),
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
    if (_fromStoreId != null && _toStoreId != null && _fromStoreId == _toStoreId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Origin and Destination store cannot be the same.')),
      );
      return;
    }
    setState(() => _isSubmitting = true);

    final payload = {
      'item_id': _selectedItemId,
      'from_store_id': _fromStoreId,
      'to_store_id': _toStoreId,
      'quantity': double.tryParse(_qtyController.text) ?? 1.0,
      'notes': _notesController.text.trim(),
    };

    final success = await ref.read(inventoryProvider.notifier).transferStock(payload);
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inter-store transfer completed without discrepancy!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transfer failed. Verify stock in source store.')),
        );
      }
    }
  }
}
