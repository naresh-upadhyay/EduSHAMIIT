import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/inventory_models.dart';
import '../../providers/inventory_provider.dart';
import '../../services/inventory_api_service.dart';
import '../inventory_searchable_dropdown.dart';

class EditPurchaseOrderDialog extends ConsumerStatefulWidget {
  final PurchaseOrder purchaseOrder;
  final ValueChanged<PurchaseOrder>? onSaved;

  const EditPurchaseOrderDialog({
    super.key,
    required this.purchaseOrder,
    this.onSaved,
  });

  @override
  ConsumerState<EditPurchaseOrderDialog> createState() => _EditPurchaseOrderDialogState();
}

class _EditPurchaseOrderDialogState extends ConsumerState<EditPurchaseOrderDialog> {
  final _formKey = GlobalKey<FormState>();

  late String? _selectedSupplierId;
  late String _supplierName;
  late TextEditingController _supplierGstinController;
  late String? _selectedStoreId;
  late TextEditingController _shippingAddressController;
  late TextEditingController _paymentTermsController;
  late String _status;
  late DateTime _deliveryDate;
  late TextEditingController _taxRateController;
  late TextEditingController _shippingAmountController;
  late TextEditingController _notesController;
  late TextEditingController _termsConditionsController;

  final List<_EditPoLineItemInput> _lines = [];
  bool _isSubmitting = false;

  final List<String> _paymentTermsOptions = [
    'Net 30 Days',
    'Net 15 Days',
    'Net 60 Days',
    'Due on Receipt',
    'Immediate Payment',
    'Advance 50% - Balance on Delivery',
    'Advance 100%',
  ];

  final List<String> _statusOptions = [
    'Pending',
    'Approved',
    'Processing',
    'Partial',
    'Delivered',
    'Cancelled',
  ];

  @override
  void initState() {
    super.initState();
    final po = widget.purchaseOrder;
    _selectedSupplierId = po.supplierId ?? po.supplier;
    _supplierName = po.supplier;
    _supplierGstinController = TextEditingController(text: po.supplierGstin);
    _selectedStoreId = po.storeId;
    _shippingAddressController = TextEditingController(text: po.shippingAddress);
    _paymentTermsController = TextEditingController(text: po.paymentTerms);
    _status = po.status.isNotEmpty ? po.status : 'Pending';

    _deliveryDate = po.expectedDeliveryDate ?? DateTime.now().add(const Duration(days: 7));
    _notesController = TextEditingController(text: po.notes ?? '');
    _termsConditionsController = TextEditingController(
      text: po.termsConditions ??
          '1. Certified that the particulars given above are true and correct.\n'
          '2. Subject to Bangalore Jurisdiction.\n'
          '3. Any discrepancies must be brought to notice within 7 days of delivery.\n'
          '4. This is a computer generated official procurement order.',
    );

    double initialTaxRate = 18.0;
    if (po.subtotal > 0 && po.taxAmount > 0) {
      initialTaxRate = ((po.taxAmount / po.subtotal) * 100).roundToDouble();
    }
    _taxRateController = TextEditingController(text: initialTaxRate.toStringAsFixed(1));
    _shippingAmountController = TextEditingController(text: po.shippingAmount.toStringAsFixed(2));

    if (po.items.isNotEmpty) {
      for (final it in po.items) {
        _lines.add(_EditPoLineItemInput(
          id: it.poItemId,
          itemId: it.itemId,
          itemName: it.itemName,
          sku: it.sku,
          unit: it.unit,
          qty: it.quantity,
          rate: it.unitPrice,
          taxRate: it.taxRate,
        ));
      }
    } else {
      _lines.add(_EditPoLineItemInput());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(inventoryProvider.notifier).loadCatalogItems();
    });
  }

  @override
  void dispose() {
    _supplierGstinController.dispose();
    _shippingAddressController.dispose();
    _paymentTermsController.dispose();
    _taxRateController.dispose();
    _shippingAmountController.dispose();
    _notesController.dispose();
    _termsConditionsController.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  double get _subtotal {
    double sum = 0;
    for (final l in _lines) {
      sum += l.lineTotal;
    }
    return sum;
  }

  double get _taxAmount {
    final rate = double.tryParse(_taxRateController.text) ?? 0;
    return _subtotal * (rate / 100);
  }

  double get _shippingAmount => double.tryParse(_shippingAmountController.text) ?? 0;
  double get _grandTotal => (_subtotal + _taxAmount + _shippingAmount).clamp(0, double.infinity);
  String get _amountInWords => formatIndianCurrencyWords(_grandTotal);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryProvider);
    final metadata = state.metadata;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: Container(
        width: 860,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
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
                  child: const Icon(Icons.edit_document, color: Color(0xFF2563EB), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Edit Purchase Order',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                              fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.purchaseOrder.poNumber,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Update invoice attributes, supplier credentials, dispatch location, and items',
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
            Divider(height: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            const SizedBox(height: 16),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Section 1: Supplier & Tax Information
                      _buildSectionHeader('Vendor & Billing Credentials', isDark),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: InventorySearchableDropdown<InventoryDropdownItem>(
                              label: 'Supplier / Vendor',
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
                              onChanged: (val) {
                                setState(() {
                                  _selectedSupplierId = val;
                                  if (metadata?.suppliers != null) {
                                    for (final s in metadata!.suppliers) {
                                      if (s.supplierId == val) {
                                        _supplierName = s.supplierName;
                                        break;
                                      }
                                    }
                                  }
                                });
                              },
                              onQuickAdd: (text) async {
                                final added = await ref.read(inventoryProvider.notifier).quickAddLookup(
                                  keyCode: 'INVENTORY_SUPPLIERS',
                                  valueName: text,
                                  description: 'Quick added supplier from Edit PO',
                                );
                                if (added != null) {
                                  setState(() {
                                    _supplierName = added.lookupValue;
                                  });
                                }
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
                                  'Supplier GSTIN / Tax ID',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                    fontFamily: 'Inter',
                                  ),
                                ),
                                const SizedBox(height: 7),
                                TextFormField(
                                  controller: _supplierGstinController,
                                  decoration: InputDecoration(
                                    hintText: '29AAACG1234F1Z8',
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
                                  'Payment Terms',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                    fontFamily: 'Inter',
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Autocomplete<String>(
                                  initialValue: TextEditingValue(text: _paymentTermsController.text),
                                  optionsBuilder: (textEditingValue) {
                                    if (textEditingValue.text.isEmpty) {
                                      return _paymentTermsOptions;
                                    }
                                    return _paymentTermsOptions.where((opt) =>
                                        opt.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                                  },
                                  onSelected: (selection) {
                                    _paymentTermsController.text = selection;
                                  },
                                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                    // sync controller if initial
                                    controller.addListener(() {
                                      _paymentTermsController.text = controller.text;
                                    });
                                    return TextFormField(
                                      controller: controller,
                                      focusNode: focusNode,
                                      decoration: InputDecoration(
                                        hintText: 'e.g. Net 30 Days',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Section 2: Logistics, Destination & Status
                      _buildSectionHeader('Logistics & Delivery Record', isDark),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                                  description: 'Quick added store from Edit PO',
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
                                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                      lastDate: DateTime.now().add(const Duration(days: 730)),
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
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Order Status',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                    fontFamily: 'Inter',
                                  ),
                                ),
                                const SizedBox(height: 7),
                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  initialValue: _statusOptions.contains(_status) ? _status : _statusOptions.first,
                                  items: _statusOptions
                                      .map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis)))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null) setState(() => _status = v);
                                  },
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _shippingAddressController,
                        decoration: InputDecoration(
                          labelText: 'Shipping / Dispatch Address',
                          hintText: 'Campus Road, Sarjapur, Bangalore, Karnataka - 560035',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Section 3: Line Items
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionHeader('Order Line Items', isDark),
                          TextButton.icon(
                            onPressed: () {
                              setState(() => _lines.add(_EditPoLineItemInput()));
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Item Line'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Line Items Table List (Scrollable horizontally)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: 800,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: _lines.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final line = entry.value;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text('${idx + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    const SizedBox(width: 8),
                                    // Item selector
                                    Expanded(
                                      flex: 4,
                                      child: InventorySearchableDropdown<InventoryItem>(
                                        label: 'Item',
                                        value: line.itemId,
                                        hint: 'Select or add item...',
                                        isRequired: true,
                                        items: state.catalogItems.isNotEmpty ? state.catalogItems : state.items,
                                        getItemId: (it) => it.itemId,
                                        getItemName: (it) => it.name,
                                        getItemSubtitle: (it) => 'SKU: ${it.sku} • ${it.category}',
                                        getItemBadge: (it) => it.uomCode,
                                        prefixIcon: Icons.inventory_2_outlined,
                                        allowManualEntry: true,
                                        quickAddLabel: 'Create item in catalog & lookups',
                                        onChanged: (val) {
                                          setState(() {
                                            line.itemId = val;
                                            final all = state.catalogItems.isNotEmpty ? state.catalogItems : state.items;
                                            final found = all.cast<InventoryItem?>().firstWhere(
                                              (e) => e?.itemId == val || e?.name.toLowerCase() == val?.toLowerCase(),
                                              orElse: () => null,
                                            );
                                            if (found != null) {
                                              line.itemNameController.text = found.name;
                                              line.skuController.text = found.sku;
                                              line.unitController.text = found.uomCode;
                                              if (found.purchasePrice > 0) {
                                                line.priceController.text = '${found.purchasePrice}';
                                              }
                                            } else if (val != null && val.isNotEmpty) {
                                              line.itemNameController.text = val;
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
                                            line.itemNameController.text = created.name;
                                            line.skuController.text = created.sku;
                                            line.unitController.text = created.uomCode;
                                            return created.itemId;
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // SKU / Code
                                    SizedBox(
                                      width: 110,
                                      child: TextFormField(
                                        controller: line.skuController,
                                        decoration: const InputDecoration(
                                          labelText: 'SKU / Code',
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Unit
                                    SizedBox(
                                      width: 65,
                                      child: TextFormField(
                                        controller: line.unitController,
                                        decoration: const InputDecoration(
                                          labelText: 'Unit',
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                                        ),
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
                                    // Rate (INR)
                                    SizedBox(
                                      width: 90,
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
                                    // Tax %
                                    SizedBox(
                                      width: 65,
                                      child: TextFormField(
                                        controller: line.taxRateController,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'Tax %',
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                                        ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Line Total
                                    SizedBox(
                                      width: 85,
                                      child: Text(
                                        currencyFmt.format(line.lineTotal),
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.end,
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
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Financial summary calculations
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Taxable Subtotal:', style: TextStyle(fontSize: 13.5)),
                                Text(currencyFmt.format(_subtotal), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Text('Integrated GST / Tax Rate: ', style: TextStyle(fontSize: 13.5)),
                                    SizedBox(
                                      width: 55,
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
                                Text(currencyFmt.format(_taxAmount), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Text('Shipping / Freight Charges: ', style: TextStyle(fontSize: 13.5)),
                                    SizedBox(
                                      width: 75,
                                      height: 28,
                                      child: TextField(
                                        controller: _shippingAmountController,
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(fontSize: 12),
                                        onChanged: (_) => setState(() {}),
                                        decoration: const InputDecoration(contentPadding: EdgeInsets.all(4), border: OutlineInputBorder()),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(currencyFmt.format(_shippingAmount), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              ],
                            ),
                            const Divider(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Invoice Grand Total:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                Text(
                                  currencyFmt.format(_grandTotal),
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Amount in Words: $_amountInWords',
                                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Remarks & Terms
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _notesController,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText: 'Remarks / Dispatch Notes',
                                hintText: 'Enter procurement notes or specific handling instructions...',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextFormField(
                              controller: _termsConditionsController,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText: 'Declaration & Terms',
                                hintText: 'Official purchase order terms & jurisdiction...',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                        ],
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
                ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check, size: 18),
                  label: const Text('Save Order Changes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155),
        fontFamily: 'Inter',
        letterSpacing: 0.2,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_lines.isEmpty) return;

    setState(() => _isSubmitting = true);

    final payload = {
      'supplier_id': _selectedSupplierId,
      'supplier_name': _supplierName.isNotEmpty ? _supplierName : _selectedSupplierId,
      'supplier_gstin': _supplierGstinController.text.trim(),
      'store_id': _selectedStoreId,
      'shipping_address': _shippingAddressController.text.trim(),
      'payment_terms': _paymentTermsController.text.trim(),
      'status': _status,
      'delivery_date': _deliveryDate.toIso8601String().split('T')[0],
      'expected_delivery_date': _deliveryDate.toIso8601String().split('T')[0],
      'notes': _notesController.text.trim(),
      'terms_conditions': _termsConditionsController.text.trim(),
      'subtotal': _subtotal,
      'tax_amount': _taxAmount,
      'shipping_amount': _shippingAmount,
      'total_amount': _grandTotal,
      'items': _lines.map((l) {
        final q = double.tryParse(l.qtyController.text) ?? 1.0;
        final p = double.tryParse(l.priceController.text) ?? 0.0;
        final tax = double.tryParse(l.taxRateController.text) ?? 18.0;
        return {
          'id': l.id,
          'item_id': l.itemId,
          'item_name': l.itemNameController.text.trim().isNotEmpty ? l.itemNameController.text.trim() : (l.itemId ?? 'Item'),
          'sku': l.skuController.text.trim(),
          'unit': l.unitController.text.trim().isNotEmpty ? l.unitController.text.trim() : 'Pcs',
          'quantity': q,
          'unit_price': p,
          'tax_rate': tax,
          'total_price': q * p,
        };
      }).toList(),
    };

    try {
      final res = await ref.read(inventoryApiServiceProvider).updatePurchaseOrder(widget.purchaseOrder.id, payload);
      if (mounted) {
        setState(() => _isSubmitting = false);
        if (res['success'] == true) {
          ref.read(inventoryProvider.notifier).loadPurchaseOrders();
          ref.read(inventoryProvider.notifier).loadOverview();

          // Create an updated PurchaseOrder model for instant reactive UI update
          final updatedItems = _lines.map((l) {
            final q = double.tryParse(l.qtyController.text) ?? 1.0;
            final p = double.tryParse(l.priceController.text) ?? 0.0;
            return PurchaseOrderItem(
              poItemId: l.id ?? '',
              itemId: l.itemId ?? '',
              itemName: l.itemNameController.text.trim().isNotEmpty ? l.itemNameController.text.trim() : 'Item',
              sku: l.skuController.text.trim(),
              unit: l.unitController.text.trim().isNotEmpty ? l.unitController.text.trim() : 'Pcs',
              quantity: q,
              unitPrice: p,
              taxRate: double.tryParse(l.taxRateController.text) ?? 18.0,
              totalPrice: q * p,
            );
          }).toList();

          final updatedPo = InventoryPurchaseOrder(
            id: widget.purchaseOrder.id,
            poNumber: widget.purchaseOrder.poNumber,
            date: widget.purchaseOrder.date,
            dateRaw: widget.purchaseOrder.dateRaw,
            supplierId: _selectedSupplierId,
            supplier: _supplierName.isNotEmpty ? _supplierName : widget.purchaseOrder.supplier,
            supplierGstin: _supplierGstinController.text.trim(),
            storeId: _selectedStoreId,
            department: widget.purchaseOrder.department,
            shippingAddress: _shippingAddressController.text.trim(),
            paymentTerms: _paymentTermsController.text.trim(),
            itemsCount: updatedItems.length,
            itemsText: updatedItems.map((e) => e.itemName).join(', '),
            subtotal: _subtotal,
            taxAmount: _taxAmount,
            shippingAmount: _shippingAmount,
            totalAmount: _grandTotal,
            status: _status,
            deliveryDate: DateFormat('dd MMM yyyy').format(_deliveryDate),
            deliveryDateRaw: _deliveryDate.toIso8601String().split('T')[0],
            notes: _notesController.text.trim(),
            termsConditions: _termsConditionsController.text.trim(),
            items: updatedItems,
          );

          widget.onSaved?.call(updatedPo);
          Navigator.of(context).pop(updatedPo);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Purchase Order ${widget.purchaseOrder.poNumber} updated successfully!'),
              backgroundColor: const Color(0xFF059669),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['error'] ?? 'Failed to update Purchase Order'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating PO: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _EditPoLineItemInput {
  String? id;
  String? itemId;
  late final TextEditingController itemNameController;
  late final TextEditingController skuController;
  late final TextEditingController unitController;
  late final TextEditingController qtyController;
  late final TextEditingController priceController;
  late final TextEditingController taxRateController;

  _EditPoLineItemInput({
    this.id,
    this.itemId,
    String itemName = '',
    String sku = '',
    String unit = 'Pcs',
    double qty = 10,
    double rate = 50.0,
    double taxRate = 18.0,
  }) {
    itemNameController = TextEditingController(text: itemName);
    skuController = TextEditingController(text: sku);
    unitController = TextEditingController(text: unit);
    qtyController = TextEditingController(text: qty.toInt().toString());
    priceController = TextEditingController(text: rate.toStringAsFixed(2));
    taxRateController = TextEditingController(text: taxRate.toStringAsFixed(1));
  }

  double get lineTotal {
    final q = double.tryParse(qtyController.text) ?? 0;
    final p = double.tryParse(priceController.text) ?? 0;
    return q * p;
  }

  void dispose() {
    itemNameController.dispose();
    skuController.dispose();
    unitController.dispose();
    qtyController.dispose();
    priceController.dispose();
    taxRateController.dispose();
  }
}
