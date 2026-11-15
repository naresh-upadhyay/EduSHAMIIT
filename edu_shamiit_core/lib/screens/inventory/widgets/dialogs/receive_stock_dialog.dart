import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/inventory_models.dart';
import '../../providers/inventory_provider.dart';
import '../inventory_searchable_dropdown.dart';

class ReceiveStockDialog extends ConsumerStatefulWidget {
  final InventoryItem? preselectedItem;

  const ReceiveStockDialog({super.key, this.preselectedItem});

  @override
  ConsumerState<ReceiveStockDialog> createState() => _ReceiveStockDialogState();
}

class _ReceiveStockDialogState extends ConsumerState<ReceiveStockDialog> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedItemId;
  String? _selectedStoreId;
  String? _selectedSupplierId;
  final _qtyController = TextEditingController(text: '10');
  final _unitCostController = TextEditingController(text: '0.00');
  final _invoiceRefController = TextEditingController();
  final _batchController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.preselectedItem != null) {
      _selectedItemId = widget.preselectedItem!.itemId;
      _selectedStoreId = widget.preselectedItem!.preferredStoreId;
      _unitCostController.text = '${widget.preselectedItem!.purchasePrice}';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(inventoryProvider.notifier).loadCatalogItems();
    });
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _unitCostController.dispose();
    _invoiceRefController.dispose();
    _batchController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryProvider);
    final metadata = state.metadata;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_selectedStoreId == null && (metadata?.stores.isNotEmpty ?? false)) {
      _selectedStoreId = metadata!.stores.first.storeId;
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
                        'Receive Stock',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Record direct intake into store inventory',
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
                    getItemSubtitle: (it) => 'SKU: ${it.sku} • Stock: ${it.currentStock.toInt()} ${it.uomCode}',
                    getItemBadge: (it) => it.category,
                    prefixIcon: Icons.inventory_2_outlined,
                    allowManualEntry: true,
                    quickAddLabel: 'Quick create item & add to catalog & lookups',
                    onChanged: (val) {
                      setState(() {
                        _selectedItemId = val;
                        final all = state.catalogItems.isNotEmpty ? state.catalogItems : state.items;
                        final found = all.cast<InventoryItem?>().firstWhere(
                          (e) => e?.itemId == val || e?.name.toLowerCase() == val?.toLowerCase(),
                          orElse: () => null,
                        );
                        if (found != null && found.purchasePrice > 0) {
                          _unitCostController.text = '${found.purchasePrice}';
                        }
                      });
                    },
                    onQuickAdd: (text) async {
                      final created = await ref.read(inventoryProvider.notifier).quickAddItem(
                        itemName: text,
                        purchasePrice: double.tryParse(_unitCostController.text) ?? 50.0,
                        storeId: _selectedStoreId,
                      );
                      if (created != null) {
                        if (created.purchasePrice > 0) {
                          _unitCostController.text = '${created.purchasePrice}';
                        }
                        return created.itemId;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Receiving Store & Supplier
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: InventorySearchableDropdown<InventoryDropdownItem>(
                          label: 'Receiving Store',
                          value: _selectedStoreId,
                          hint: 'Select or add store...',
                          isRequired: true,
                          items: metadata?.stores ?? [],
                          getItemId: (s) => s.storeId,
                          getItemName: (s) => s.storeName,
                          getItemSubtitle: (s) => s.code.isNotEmpty ? 'Code: ${s.code}' : null,
                          prefixIcon: Icons.store_rounded,
                          allowManualEntry: true,
                          quickAddLabel: 'Add store to Lookups & Stores list',
                          onChanged: (val) => setState(() => _selectedStoreId = val),
                          onQuickAdd: (text) async {
                            final added = await ref.read(inventoryProvider.notifier).quickAddLookup(
                              keyCode: 'INVENTORY_STORES',
                              valueName: text,
                              description: 'Quick added store from Receive Stock',
                            );
                            return added?.id ?? added?.code;
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: InventorySearchableDropdown<InventoryDropdownItem>(
                          label: 'Supplier',
                          value: _selectedSupplierId,
                          hint: 'Select or add supplier...',
                          isRequired: false,
                          items: metadata?.suppliers ?? [],
                          getItemId: (s) => s.supplierId,
                          getItemName: (s) => s.supplierName,
                          getItemSubtitle: (s) => s.code.isNotEmpty ? 'Code: ${s.code}' : null,
                          prefixIcon: Icons.business_rounded,
                          allowManualEntry: true,
                          quickAddLabel: 'Add supplier to Lookups & Suppliers list',
                          onChanged: (val) => setState(() => _selectedSupplierId = val),
                          onQuickAdd: (text) async {
                            final added = await ref.read(inventoryProvider.notifier).quickAddLookup(
                              keyCode: 'INVENTORY_SUPPLIERS',
                              valueName: text,
                              description: 'Quick added supplier from Receive Stock',
                            );
                            return added?.id ?? added?.code;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Quantity and Unit Cost
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _qtyController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Quantity to Receive *',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Enter valid qty' : null,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextFormField(
                          controller: _unitCostController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Unit Cost (₹) *',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          validator: (v) => double.tryParse(v ?? '') == null ? 'Enter valid cost' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Invoice / Reference & Batch
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _invoiceRefController,
                          decoration: InputDecoration(
                            labelText: 'Invoice / Ref Number',
                            hintText: 'e.g., INV-9042',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextFormField(
                          controller: _batchController,
                          decoration: InputDecoration(
                            labelText: 'Batch Number',
                            hintText: 'Optional',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Remarks / Notes',
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
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Confirm Receipt'),
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

    final payload = {
      'item_id': _selectedItemId,
      'store_id': _selectedStoreId,
      'supplier_id': _selectedSupplierId,
      'quantity': double.tryParse(_qtyController.text) ?? 1.0,
      'unit_cost': double.tryParse(_unitCostController.text) ?? 0.0,
      'invoice_reference': _invoiceRefController.text.trim().isEmpty ? null : _invoiceRefController.text.trim(),
      'batch_number': _batchController.text.trim().isEmpty ? null : _batchController.text.trim(),
      'notes': _notesController.text.trim(),
    };

    final success = await ref.read(inventoryProvider.notifier).receiveStock(payload);
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock received successfully into inventory!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to receive stock. Please try again.')),
        );
      }
    }
  }
}
