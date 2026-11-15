import '../../models/inventory_models.dart';
import 'package:intl/intl.dart';
import '../../services/inventory_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/inventory_provider.dart';
import '../inventory_searchable_dropdown.dart';

class CreateSalesOrderDialog extends ConsumerStatefulWidget {
  const CreateSalesOrderDialog({super.key});

  @override
  ConsumerState<CreateSalesOrderDialog> createState() => _CreateSalesOrderDialogState();
}

class _CreateSalesOrderDialogState extends ConsumerState<CreateSalesOrderDialog> {
  final _formKey = GlobalKey<FormState>();

  final _customerNameController = TextEditingController();
  final _customerContactController = TextEditingController();
  final _shippingAddressController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _deliveryDate = DateTime.now().add(const Duration(days: 3));

  final List<_SoLineItemInput> _lines = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _lines.add(_SoLineItemInput());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(inventoryProvider.notifier).loadCatalogItems();
    });
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerContactController.dispose();
    _shippingAddressController.dispose();
    _notesController.dispose();
    for (var l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  double get _grandTotal {
    double sum = 0;
    for (var l in _lines) {
      final q = double.tryParse(l.qtyController.text) ?? 0;
      final p = double.tryParse(l.priceController.text) ?? 0;
      sum += (q * p);
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryProvider);
    final metadata = state.metadata;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 820,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        padding: const EdgeInsets.all(24),
        child: Column(
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
                  child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF2563EB), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create Sales Order',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Record sales to branch institutes, affiliated academies or student stores',
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: InventorySearchableDropdown<InventoryDropdownItem>(
                              label: 'Customer / Institution Name',
                              value: _customerNameController.text.isNotEmpty ? _customerNameController.text : null,
                              hint: 'Select or enter buyer...',
                              isRequired: true,
                              items: metadata?.customers ?? [],
                              getItemId: (c) => c.lookupValue.isNotEmpty ? c.lookupValue : c.lookupCode,
                              getItemName: (c) => c.lookupValue.isNotEmpty ? c.lookupValue : c.lookupCode,
                              getItemSubtitle: (c) => c.code.isNotEmpty ? 'Buyer Code: ${c.code}' : null,
                              prefixIcon: Icons.account_balance_outlined,
                              allowManualEntry: true,
                              quickAddLabel: 'Add buyer to Lookups & Customers list',
                              onChanged: (val) {
                                setState(() {
                                  _customerNameController.text = val ?? '';
                                });
                              },
                              onQuickAdd: (text) async {
                                final added = await ref.read(inventoryProvider.notifier).quickAddLookup(
                                  keyCode: 'INVENTORY_CUSTOMERS',
                                  valueName: text,
                                  description: 'Quick added customer from Sales Order',
                                );
                                if (added != null) {
                                  setState(() => _customerNameController.text = added.lookupValue);
                                  return added.lookupValue;
                                }
                                setState(() => _customerNameController.text = text);
                                return text;
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
                                  'Contact Phone / Email',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                    fontFamily: 'Inter',
                                  ),
                                ),
                                const SizedBox(height: 7),
                                TextFormField(
                                  controller: _customerContactController,
                                  decoration: InputDecoration(
                                    hintText: '+91 98765 43210',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                ),
                              ],
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
                                      lastDate: DateTime.now().add(const Duration(days: 180)),
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
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _shippingAddressController,
                        decoration: InputDecoration(
                          labelText: 'Shipping / Delivery Address',
                          hintText: 'e.g., Block B, Academic Complex, North Campus',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 20),

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
                              setState(() => _lines.add(_SoLineItemInput()));
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Item Line'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

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
                                      if (found != null) {
                                        line.priceController.text = found.sellingPrice > 0 ? '${found.sellingPrice}' : '${found.purchasePrice * 1.2}';
                                      }
                                    });
                                  },
                                  onQuickAdd: (text) async {
                                    final created = await ref.read(inventoryProvider.notifier).quickAddItem(
                                      itemName: text,
                                      sellingPrice: double.tryParse(line.priceController.text) ?? 60.0,
                                    );
                                    if (created != null) {
                                      if (created.sellingPrice > 0) {
                                        line.priceController.text = '${created.sellingPrice}';
                                      }
                                      return created.itemId;
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
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
                                  validator: (v) {
                                    final val = double.tryParse(v ?? '') ?? 0;
                                    if (val <= 0) return 'Invalid';
                                    if (line.itemId != null) {
                                      final all = state.catalogItems.isNotEmpty ? state.catalogItems : state.items;
                                      final item = all.cast<InventoryItem?>().firstWhere(
                                        (e) => e?.itemId == line.itemId || e?.name.toLowerCase() == line.itemId?.toLowerCase(),
                                        orElse: () => null,
                                      );
                                      if (item != null && item.currentStock > 0 && val > item.currentStock) {
                                        return 'Max ${item.currentStock.toInt()}';
                                      }
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 85,
                                child: TextFormField(
                                  controller: line.priceController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'Price (₹)',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                  validator: (v) => double.tryParse(v ?? '') == null ? 'Invalid' : null,
                                ),
                              ),
                              const SizedBox(width: 8),
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

                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Order Grand Total:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            Text(
                              currencyFmt.format(_grandTotal),
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _notesController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Special Instructions / Delivery Remarks',
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
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Confirm Sales Order'),
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

    final state = ref.read(inventoryProvider);

    setState(() => _isSubmitting = true);

    final custName = _customerNameController.text.trim().isNotEmpty
        ? _customerNameController.text.trim()
        : 'General Customer';

    final orderData = {
      'customer_name': custName,
      'customer_contact': _customerContactController.text.trim(),
      'shipping_address': _shippingAddressController.text.trim(),
      'delivery_date': _deliveryDate.toIso8601String().split('T')[0],
      'expected_delivery_date': _deliveryDate.toIso8601String().split('T')[0],
      'notes': _notesController.text.trim(),
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
      final res = await ref.read(inventoryApiServiceProvider).createSalesOrder(orderData, items);
      if (mounted) {
        setState(() => _isSubmitting = false);
        if (res['success'] == true) {
          ref.read(inventoryProvider.notifier).loadSalesOrders();
          ref.read(inventoryProvider.notifier).loadOverview();
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('SO ${res['so_number'] ?? ''} created! Stock reserved.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['error'] ?? 'Failed to create sales order')),
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

class _SoLineItemInput {
  String? itemId;
  final TextEditingController qtyController = TextEditingController(text: '5');
  final TextEditingController priceController = TextEditingController(text: '100.00');

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
