import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/inventory_models.dart';
import '../../providers/inventory_provider.dart';
import '../../services/inventory_api_service.dart';
import '../inventory_searchable_dropdown.dart';

class EditSalesOrderDialog extends ConsumerStatefulWidget {
  final SalesOrder salesOrder;
  final ValueChanged<SalesOrder>? onSaved;

  const EditSalesOrderDialog({
    super.key,
    required this.salesOrder,
    this.onSaved,
  });

  @override
  ConsumerState<EditSalesOrderDialog> createState() => _EditSalesOrderDialogState();
}

class _EditSalesOrderDialogState extends ConsumerState<EditSalesOrderDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _customerNameController;
  late String _customerType;
  late TextEditingController _customerGstinController;
  late TextEditingController _contactPhoneController;
  late TextEditingController _contactEmailController;
  late String? _selectedStoreId;
  late TextEditingController _shippingAddressController;
  late TextEditingController _paymentTermsController;
  late String _status;
  late DateTime _deliveryDate;
  late TextEditingController _taxRateController;
  late TextEditingController _discountAmountController;
  late TextEditingController _notesController;
  late TextEditingController _termsConditionsController;

  final List<_EditSoLineItemInput> _lines = [];
  bool _isSubmitting = false;

  final List<String> _customerTypeOptions = [
    'Student',
    'Staff',
    'Partner School',
    'Academic Department',
    'Institutional Account',
    'General Buyer',
  ];

  final List<String> _paymentTermsOptions = [
    'Due on Receipt',
    'Net 15 Days',
    'Net 30 Days',
    'Advance 50% - Balance on Delivery',
    'Advance 100%',
    'Immediate Cash / UPI',
  ];

  final List<String> _statusOptions = [
    'Pending',
    'Processing',
    'Delivered',
    'Cancelled',
  ];

  @override
  void initState() {
    super.initState();
    final so = widget.salesOrder;
    _customerNameController = TextEditingController(text: so.customer);
    _customerType = _customerTypeOptions.contains(so.customerType) ? so.customerType : 'Student';
    _customerGstinController = TextEditingController(text: so.customerGstin);
    _contactPhoneController = TextEditingController(text: so.contactPhone ?? '');
    _contactEmailController = TextEditingController(text: so.contactEmail ?? '');
    _selectedStoreId = so.storeId;
    _shippingAddressController = TextEditingController(text: so.shippingAddress);
    _paymentTermsController = TextEditingController(text: so.paymentTerms);
    _status = so.status.isNotEmpty ? so.status : 'Pending';

    _deliveryDate = so.expectedDeliveryDate ?? DateTime.now().add(const Duration(days: 3));
    _notesController = TextEditingController(text: so.notes ?? '');
    _termsConditionsController = TextEditingController(
      text: so.termsConditions ??
          '1. Certified that the particulars given above are true and correct.\n'
          '2. Subject to Bangalore Jurisdiction.\n'
          '3. Any discrepancies must be brought to notice within 7 days of delivery.\n'
          '4. This is a computer generated tax invoice.',
    );

    double initialTaxRate = 5.0;
    if (so.subtotal > 0 && so.taxAmount > 0) {
      initialTaxRate = ((so.taxAmount / so.subtotal) * 100).roundToDouble();
    }
    _taxRateController = TextEditingController(text: initialTaxRate.toStringAsFixed(1));
    _discountAmountController = TextEditingController(text: so.discountAmount.toStringAsFixed(2));

    if (so.items.isNotEmpty) {
      for (final it in so.items) {
        _lines.add(_EditSoLineItemInput(
          id: it.soItemId,
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
      _lines.add(_EditSoLineItemInput());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(inventoryProvider.notifier).loadCatalogItems();
    });
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerGstinController.dispose();
    _contactPhoneController.dispose();
    _contactEmailController.dispose();
    _shippingAddressController.dispose();
    _paymentTermsController.dispose();
    _taxRateController.dispose();
    _discountAmountController.dispose();
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

  double get _discountAmount => double.tryParse(_discountAmountController.text) ?? 0;
  double get _grandTotal => (_subtotal + _taxAmount - _discountAmount).clamp(0, double.infinity);
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
                  child: const Icon(Icons.edit_note_rounded, color: Color(0xFF2563EB), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Edit Sales Order',
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
                              widget.salesOrder.soNumber,
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
                        'Update invoice attributes, buyer details, delivery location, terms, and line items',
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
                      // Section 1: Customer & Buyer Credentials
                      _buildSectionHeader('Bill To / Customer Credentials', isDark),
                      const SizedBox(height: 12),
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
                                  description: 'Quick added customer from Edit SO',
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
                                  'Client Classification',
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
                                  initialValue: _customerTypeOptions.contains(_customerType)
                                      ? _customerType
                                      : _customerTypeOptions.first,
                                  items: _customerTypeOptions
                                      .map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis)))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null) setState(() => _customerType = v);
                                  },
                                  decoration: InputDecoration(
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
                                  'Customer GSTIN / Tax ID',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                    fontFamily: 'Inter',
                                  ),
                                ),
                                const SizedBox(height: 7),
                                TextFormField(
                                  controller: _customerGstinController,
                                  decoration: InputDecoration(
                                    hintText: '29AAACG1234F1Z8',
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _contactPhoneController,
                              decoration: InputDecoration(
                                labelText: 'Contact Phone',
                                hintText: '+91 98765 43210',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _contactEmailController,
                              decoration: InputDecoration(
                                labelText: 'Contact Email',
                                hintText: 'client@institution.edu.in',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 2,
                            child: Autocomplete<String>(
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
                                controller.addListener(() {
                                  _paymentTermsController.text = controller.text;
                                });
                                return TextFormField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  decoration: InputDecoration(
                                    labelText: 'Payment Terms',
                                    hintText: 'e.g. Due on Receipt',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Section 2: Dispatch & Sales Record
                      _buildSectionHeader('Dispatch & Sales Record', isDark),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: InventorySearchableDropdown<InventoryDropdownItem>(
                              label: 'Origin Store',
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
                                  description: 'Quick added store from Edit SO',
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
                                AppSearchableDropdownFormField<String>.fromMenuItems(
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
                          labelText: 'Dispatch Location / Shipping Address',
                          hintText: 'Bangalore Center Distribution Hub',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Section 3: Line Items
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionHeader('Sales Order Line Items', isDark),
                          TextButton.icon(
                            onPressed: () {
                              setState(() => _lines.add(_EditSoLineItemInput()));
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
                                        getItemSubtitle: (it) => 'SKU: ${it.sku} • Stock: ${it.currentStock.toInt()} ${it.uomCode}',
                                        getItemBadge: (it) => it.category,
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
                                              if (found.sellingPrice > 0) {
                                                line.priceController.text = '${found.sellingPrice}';
                                              }
                                            } else if (val != null && val.isNotEmpty) {
                                              line.itemNameController.text = val;
                                            }
                                          });
                                        },
                                        onQuickAdd: (text) async {
                                          final created = await ref.read(inventoryProvider.notifier).quickAddItem(
                                            itemName: text,
                                            purchasePrice: 40.0,
                                            sellingPrice: double.tryParse(line.priceController.text) ?? 50.0,
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
                                    const Text('Institutional Discount: ', style: TextStyle(fontSize: 13.5)),
                                    SizedBox(
                                      width: 75,
                                      height: 28,
                                      child: TextField(
                                        controller: _discountAmountController,
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(fontSize: 12),
                                        onChanged: (_) => setState(() {}),
                                        decoration: const InputDecoration(contentPadding: EdgeInsets.all(4), border: OutlineInputBorder()),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(currencyFmt.format(_discountAmount), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.green)),
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
                                hintText: 'Consignment sales fulfilled under institutional quota...',
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
                                hintText: 'Official sales invoice terms & conditions...',
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
      'customer_id': widget.salesOrder.customerId,
      'customer_name': _customerNameController.text.trim(),
      'customer_type': _customerType,
      'customer_gstin': _customerGstinController.text.trim(),
      'contact_phone': _contactPhoneController.text.trim(),
      'contact_email': _contactEmailController.text.trim(),
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
      'discount_amount': _discountAmount,
      'total_amount': _grandTotal,
      'items': _lines.map((l) {
        final q = double.tryParse(l.qtyController.text) ?? 1.0;
        final p = double.tryParse(l.priceController.text) ?? 0.0;
        final tax = double.tryParse(l.taxRateController.text) ?? 5.0;
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
      final res = await ref.read(inventoryApiServiceProvider).updateSalesOrder(widget.salesOrder.id, payload);
      if (mounted) {
        setState(() => _isSubmitting = false);
        if (res['success'] == true) {
          ref.read(inventoryProvider.notifier).loadSalesOrders();
          ref.read(inventoryProvider.notifier).loadOverview();

          // Create an updated SalesOrder model for instant reactive UI update
          final updatedItems = _lines.map((l) {
            final q = double.tryParse(l.qtyController.text) ?? 1.0;
            final p = double.tryParse(l.priceController.text) ?? 0.0;
            return SalesOrderItem(
              soItemId: l.id ?? '',
              itemId: l.itemId ?? '',
              itemName: l.itemNameController.text.trim().isNotEmpty ? l.itemNameController.text.trim() : 'Item',
              sku: l.skuController.text.trim(),
              unit: l.unitController.text.trim().isNotEmpty ? l.unitController.text.trim() : 'Pcs',
              quantity: q,
              unitPrice: p,
              taxRate: double.tryParse(l.taxRateController.text) ?? 5.0,
              totalPrice: q * p,
            );
          }).toList();

          final updatedSo = InventorySalesOrder(
            id: widget.salesOrder.id,
            soNumber: widget.salesOrder.soNumber,
            date: widget.salesOrder.date,
            dateRaw: widget.salesOrder.dateRaw,
            customerId: widget.salesOrder.customerId,
            customer: _customerNameController.text.trim(),
            customerType: _customerType,
            customerGstin: _customerGstinController.text.trim(),
            contactPhone: _contactPhoneController.text.trim(),
            contactEmail: _contactEmailController.text.trim(),
            storeId: _selectedStoreId,
            department: widget.salesOrder.department,
            shippingAddress: _shippingAddressController.text.trim(),
            paymentTerms: _paymentTermsController.text.trim(),
            itemsCount: updatedItems.length,
            itemsText: updatedItems.map((e) => e.itemName).join(', '),
            subtotal: _subtotal,
            taxAmount: _taxAmount,
            discountAmount: _discountAmount,
            totalAmount: _grandTotal,
            status: _status,
            deliveryDate: DateFormat('dd MMM yyyy').format(_deliveryDate),
            deliveryDateRaw: _deliveryDate.toIso8601String().split('T')[0],
            notes: _notesController.text.trim(),
            termsConditions: _termsConditionsController.text.trim(),
            items: updatedItems,
          );

          widget.onSaved?.call(updatedSo);
          Navigator.of(context).pop(updatedSo);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sales Order ${widget.salesOrder.soNumber} updated successfully!'),
              backgroundColor: const Color(0xFF059669),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['error'] ?? 'Failed to update Sales Order'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating SO: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _EditSoLineItemInput {
  String? id;
  String? itemId;
  late final TextEditingController itemNameController;
  late final TextEditingController skuController;
  late final TextEditingController unitController;
  late final TextEditingController qtyController;
  late final TextEditingController priceController;
  late final TextEditingController taxRateController;

  _EditSoLineItemInput({
    this.id,
    this.itemId,
    String itemName = '',
    String sku = '',
    String unit = 'Pcs',
    double qty = 1,
    double rate = 50.0,
    double taxRate = 5.0,
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
