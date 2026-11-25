import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/inventory_models.dart';
import '../../providers/inventory_provider.dart';
import '../inventory_searchable_dropdown.dart';

class AdjustStockDialog extends ConsumerStatefulWidget {
  final InventoryItem? preselectedItem;

  const AdjustStockDialog({super.key, this.preselectedItem});

  @override
  ConsumerState<AdjustStockDialog> createState() => _AdjustStockDialogState();
}

class _AdjustStockDialogState extends ConsumerState<AdjustStockDialog> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedItemId;
  String? _selectedStoreId;
  String _adjustmentType = 'DECREASE';
  String? _selectedReason;
  final _qtyController = TextEditingController(text: '1');
  final _unitCostController = TextEditingController(text: '0.00');
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
    if (_selectedReason == null && (metadata?.adjustmentReasons.isNotEmpty ?? false)) {
      _selectedReason = metadata!.adjustmentReasons.first.lookupCode;
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
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.tune_rounded, color: Color(0xFF2563EB), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stock Adjustment',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Reconcile physical stock counts with reason codes',
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
                    getItemSubtitle: (it) => 'SKU: ${it.sku} • Current Stock: ${it.currentStock.toInt()} ${it.uomCode}',
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
                        storeId: _selectedStoreId,
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
                          label: 'Store / Location',
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
                              description: 'Quick added store from Stock Adjustment',
                            );
                            return added?.id ?? added?.code;
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Adjustment Type *',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                fontFamily: 'Inter',
                              ),
                            ),
                            const SizedBox(height: 7),
                            AppSearchableDropdownFormField<String>.fromMenuItems(
                              isExpanded: true,
                              initialValue: _adjustmentType,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'INCREASE', child: Text('Increase Stock (+)')),
                                DropdownMenuItem(value: 'DECREASE', child: Text('Decrease Stock (-)')),
                              ],
                              onChanged: (val) => setState(() => _adjustmentType = val ?? 'DECREASE'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Reason from Universal Lookup Values
                  InventorySearchableDropdown<InventoryDropdownItem>(
                    label: 'Adjustment Reason',
                    value: _selectedReason,
                    hint: 'Select or add adjustment reason...',
                    isRequired: true,
                    items: metadata?.adjustmentReasons ?? [],
                    getItemId: (r) => r.lookupCode,
                    getItemName: (r) => r.lookupValue,
                    prefixIcon: Icons.help_outline_rounded,
                    allowManualEntry: true,
                    quickAddLabel: 'Add new reason to Universal Lookups',
                    onChanged: (val) => setState(() => _selectedReason = val),
                    onQuickAdd: (text) async {
                      final added = await ref.read(inventoryProvider.notifier).quickAddLookup(
                        keyCode: 'INVENTORY_ADJUSTMENT_REASON',
                        valueName: text,
                        description: 'User created adjustment reason',
                      );
                      return added?.lookupCode;
                    },
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _qtyController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Adjustment Quantity *',
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
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Audit Notes / Incident Ref',
                      hintText: 'e.g. Broken during handling or annual physical count variance',
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
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Apply Adjustment'),
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

    final rawQty = double.tryParse(_qtyController.text) ?? 1.0;
    final qty = _adjustmentType == 'DECREASE' ? -rawQty.abs() : rawQty.abs();

    final payload = {
      'item_id': _selectedItemId,
      'store_id': _selectedStoreId,
      'quantity': qty,
      'reason_code': _selectedReason,
      'unit_cost': double.tryParse(_unitCostController.text) ?? 0.0,
      'notes': _notesController.text.trim(),
    };

    final success = await ref.read(inventoryProvider.notifier).adjustStock(payload);
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock adjustment applied and movement recorded!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Adjustment failed. Check stock availability.')),
        );
      }
    }
  }
}
