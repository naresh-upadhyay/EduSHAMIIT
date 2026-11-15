import '../../models/inventory_models.dart';
import 'package:intl/intl.dart';
import '../../services/inventory_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/inventory_provider.dart';
import '../inventory_searchable_dropdown.dart';

class CreatePurchaseOrderDialog extends ConsumerStatefulWidget {
  const CreatePurchaseOrderDialog({super.key});

  @override
  ConsumerState<CreatePurchaseOrderDialog> createState() => _CreatePurchaseOrderDialogState();
}

class _CreatePurchaseOrderDialogState extends ConsumerState<CreatePurchaseOrderDialog> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedSupplierId;
  String? _selectedStoreId;
  DateTime _deliveryDate = DateTime.now().add(const Duration(days: 7));
  final _notesController = TextEditingController();
  final _taxRateController = TextEditingController(text: '18.0');
  final _discountController = TextEditingController(text: '0.00');

  final List<_PoLineItemInput> _lines = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Default 1 line
    _lines.add(_PoLineItemInput());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(inventoryProvider.notifier).loadCatalogItems();
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    _taxRateController.dispose();
    _discountController.dispose();
    for (var l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  double get _subtotal {
    double sum = 0;
    for (var l in _lines) {
      final q = double.tryParse(l.qtyController.text) ?? 0;
      final p = double.tryParse(l.priceController.text) ?? 0;
      sum += (q * p);
    }
    return sum;
  }

  double get _taxAmount {
    final rate = double.tryParse(_taxRateController.text) ?? 0;
    return _subtotal * (rate / 100);
  }

  double get _discountAmount => double.tryParse(_discountController.text) ?? 0;
  double get _grandTotal => (_subtotal + _taxAmount - _discountAmount).clamp(0, double.infinity);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryProvider);
    final metadata = state.metadata;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

    if (_selectedSupplierId == null && (metadata?.suppliers.isNotEmpty ?? false)) {
      _selectedSupplierId = metadata!.suppliers.first.supplierId;
    }
    if (_selectedStoreId == null && (metadata?.stores.isNotEmpty ?? false)) {
      _selectedStoreId = metadata!.stores.first.storeId;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 820,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shopping_cart_outlined, color: Color(0xFF2563EB), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create Purchase Order',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Draft an official procurement order for verified suppliers',
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

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Supplier & Store & Date
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: InventorySearchableDropdown<InventoryDropdownItem>(
                              label: 'Supplier',
                              value: _selectedSupplierId,
                              hint: 'Select or add supplier...',
                              isRequired: true,
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
                                  description: 'Quick added supplier from Purchase Order',
                                );
                                return added?.id ?? added?.code;
                              },
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 2,
                            child: InventorySearchableDropdown<InventoryDropdownItem>(
                              label: 'Target Store',
                              value: _selectedStoreId,
                              hint: 'Select or add store...',
                              isRequired: true,
                              items: metadata?.stores ?? [],
                              getItemId: (s) => s.storeId,
                              getItemName: (s) => s.storeName,
                              getItemSubtitle: (s) => s.code.isNotEmpty ? 'Code: ${s.code}' : null,
                              prefixIcon: Icons.store_rounded,
                              allowManualEntry: true,
                              quickAddLabel: 'Add store to Lookups & Locations list',
                              onChanged: (val) => setState(() => _selectedStoreId = val),
                              onQuickAdd: (text) async {
                                final added = await ref.read(inventoryProvider.notifier).quickAddLookup(
                                  keyCode: 'INVENTORY_STORES',
                                  valueName: text,
                                  description: 'Quick added store from Purchase Order',
                                );
                                return added?.id ?? added?.code;
                              },
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Delivery Date',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                    fontFamily: 'Inter',
                                  ),
                                ),
                                const SizedBox(height: 7),
                                InkWell(
                                  onTap: () async {
                                    final d = await showDatePicker(
                                      context: context,
                                      initialDate: _deliveryDate,
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now().add(const Duration(days: 365)),
                                    );
                                    if (d != null) setState(() => _deliveryDate = d);
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF64748B)),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            DateFormat('dd MMM yyyy').format(_deliveryDate),
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                              fontWeight: FontWeight.w600,
                                              fontFamily: 'Inter',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Line Items Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Order Line Items',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                              fontFamily: 'Inter',
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              setState(() => _lines.add(_PoLineItemInput()));
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Item Line'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Lines Table
                      ..._lines.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final line = entry.value;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Text('${idx + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              // Item dropdown
                              Expanded(
                                flex: 4,
                                child: InventorySearchableDropdown<InventoryItem>(
                                  label: 'Item',
                                  value: line.itemId,
                                  hint: 'Search catalog or type to add...',
                                  isRequired: true,
                                  items: state.catalogItems.isNotEmpty ? state.catalogItems : state.items,
                                  getItemId: (it) => it.itemId,
                                  getItemName: (it) => it.name,
                                  getItemSubtitle: (it) => 'SKU: ${it.sku} • Stock: ${it.currentStock.toInt()} ${it.uomCode}',
                                  getItemBadge: (it) => it.category,
                                  prefixIcon: Icons.inventory_2_outlined,
                                  allowManualEntry: true,
                                  quickAddLabel: 'Quick create item & sync to catalog & lookups',
                                  onChanged: (val) {
                                    setState(() {
                                      line.itemId = val;
                                      final all = state.catalogItems.isNotEmpty ? state.catalogItems : state.items;
                                      final found = all.cast<InventoryItem?>().firstWhere(
                                        (e) => e?.itemId == val || e?.name.toLowerCase() == val?.toLowerCase(),
                                        orElse: () => null,
                                      );
                                      if (found != null && found.purchasePrice > 0) {
                                        line.priceController.text = '${found.purchasePrice}';
                                      }
                                    });
                                  },
                                  onQuickAdd: (text) async {
                                    final created = await ref.read(inventoryProvider.notifier).quickAddItem(
                                      itemName: text,
                                      purchasePrice: double.tryParse(line.priceController.text) ?? 50.0,
                                      storeId: _selectedStoreId,
                                    );
                                    if (created != null) {
                                      if (created.purchasePrice > 0) {
                                        line.priceController.text = '${created.purchasePrice}';
                                      }
                                      return created.itemId;
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Qty
                              SizedBox(
                                width: 75,
                                child: TextFormField(
                                  controller: line.qtyController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Qty',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                  validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Invalid' : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Rate
                              SizedBox(
                                width: 85,
                                child: TextFormField(
                                  controller: line.priceController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'Rate (₹)',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                  validator: (v) => double.tryParse(v ?? '') == null ? 'Invalid' : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Total
                              SizedBox(
                                width: 80,
                                child: Text(
                                  currencyFmt.format(line.lineTotal),
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_lines.length > 1)
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                  onPressed: () {
                                    setState(() => _lines.removeAt(idx));
                                  },
                                ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 14),

                      // Financial summary calculations
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Subtotal:', style: TextStyle(fontSize: 13)),
                                Text(currencyFmt.format(_subtotal), style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Text('GST / Tax Rate: ', style: TextStyle(fontSize: 13)),
                                    SizedBox(
                                      width: 50,
                                      height: 28,
                                      child: TextField(
                                        controller: _taxRateController,
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(fontSize: 12),
                                        onChanged: (_) => setState(() {}),
                                        decoration: const InputDecoration(contentPadding: EdgeInsets.all(4), border: OutlineInputBorder()),
                                      ),
                                    ),
                                    const Text(' %'),
                                  ],
                                ),
                                Text(currencyFmt.format(_taxAmount), style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Grand Total:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                Text(
                                  currencyFmt.format(_grandTotal),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _notesController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Terms & Conditions / Shipping Remarks',
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

            // Footer actions
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
                      : const Text('Generate Purchase Order'),
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
    if (_lines.isEmpty) return;

    final invState = ref.read(inventoryProvider);
    final metadata = invState.metadata;
    final state = invState;

    setState(() => _isSubmitting = true);

    String? supName;
    if (metadata?.suppliers != null && _selectedSupplierId != null) {
      for (final s in metadata!.suppliers) {
        if (s.supplierId == _selectedSupplierId) {
          supName = s.supplierName;
          break;
        }
      }
    }

    final orderData = {
      'supplier_id': _selectedSupplierId,
      'supplier_name': supName ?? _selectedSupplierId ?? 'General Vendor',
      'store_id': _selectedStoreId,
      'delivery_date': _deliveryDate.toIso8601String().split('T')[0],
      'expected_delivery_date': _deliveryDate.toIso8601String().split('T')[0],
      'notes': _notesController.text.trim(),
      'tax_amount': _taxAmount,
      'discount_amount': _discountAmount,
    };

    final items = _lines.map((l) {
      final q = double.tryParse(l.qtyController.text) ?? 1.0;
      final p = double.tryParse(l.priceController.text) ?? 0.0;
      String itName = 'General Item';
      String itSku = '';
      String itUnit = 'Pcs';
      final allItems = state.catalogItems.isNotEmpty ? state.catalogItems : state.items;
      for (final it in allItems) {
        if (it.itemId == l.itemId || it.name.toLowerCase() == l.itemId?.toLowerCase()) {
          itName = it.name;
          itSku = it.sku;
          itUnit = it.uomCode;
          break;
        }
      }
      if (itName == 'General Item' && l.itemId != null && l.itemId!.trim().isNotEmpty) {
        itName = l.itemId!.trim();
      }
      return {
        'item_id': l.itemId,
        'item_name': itName,
        'sku': itSku,
        'unit': itUnit,
        'quantity': q,
        'unit_price': p,
      };
    }).toList();

    try {
      final res = await ref.read(inventoryApiServiceProvider).createPurchaseOrder(orderData, items);
      if (mounted) {
        setState(() => _isSubmitting = false);
        if (res['success'] == true) {
          ref.read(inventoryProvider.notifier).loadPurchaseOrders();
          ref.read(inventoryProvider.notifier).loadOverview();
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('PO ${res['po_number'] ?? ''} created successfully!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['error'] ?? 'Failed to create PO')),
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

class _PoLineItemInput {
  String? itemId;
  final TextEditingController qtyController = TextEditingController(text: '10');
  final TextEditingController priceController = TextEditingController(text: '50.00');

  double get lineTotal {
    final q = double.tryParse(qtyController.text) ?? 0;
    final p = double.tryParse(priceController.text) ?? 0;
    return q * p;
  }

  void dispose() {
    qtyController.dispose();
    priceController.dispose();
  }
}
