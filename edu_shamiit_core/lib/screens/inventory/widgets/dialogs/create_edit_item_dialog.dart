import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/inventory_models.dart';
import '../../providers/inventory_provider.dart';
import '../inventory_searchable_dropdown.dart';

class CreateEditItemDialog extends ConsumerStatefulWidget {
  final InventoryItem? item;

  const CreateEditItemDialog({super.key, this.item});

  @override
  ConsumerState<CreateEditItemDialog> createState() => _CreateEditItemDialogState();
}

class _CreateEditItemDialogState extends ConsumerState<CreateEditItemDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _skuController;
  late TextEditingController _descController;
  late TextEditingController _barcodeController;
  late TextEditingController _brandController;
  late TextEditingController _modelController;
  late TextEditingController _purchasePriceController;
  late TextEditingController _sellingPriceController;
  late TextEditingController _minStockController;
  late TextEditingController _maxStockController;
  late TextEditingController _reorderQtyController;

  String? _selectedCategory;
  String? _selectedUom;
  String? _selectedStatus;
  String? _selectedStoreId;
  String? _selectedSupplierId;
  String _trackingMethod = 'NONE';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController = TextEditingController(text: item?.name ?? '');
    _skuController = TextEditingController(text: item?.sku ?? '');
    _descController = TextEditingController(text: item?.description ?? '');
    _barcodeController = TextEditingController(text: item?.barcode ?? '');
    _brandController = TextEditingController(text: item?.brand ?? '');
    _modelController = TextEditingController(text: item?.modelNumber ?? '');
    _purchasePriceController = TextEditingController(text: item != null ? '${item.purchasePrice}' : '0.00');
    _sellingPriceController = TextEditingController(text: item != null ? '${item.sellingPrice}' : '0.00');
    _minStockController = TextEditingController(text: item != null ? '${item.minStockLevel.toInt()}' : '10');
    _maxStockController = TextEditingController(text: item != null ? '${item.maxStockLevel.toInt()}' : '100');
    _reorderQtyController = TextEditingController(text: item != null ? '${item.reorderQuantity.toInt()}' : '25');

    _selectedCategory = item?.categoryCode;
    _selectedUom = item?.uomCode;
    _selectedStatus = item?.stockStatus ?? 'IN_STOCK';
    _selectedStoreId = item?.preferredStoreId;
    _selectedSupplierId = item?.defaultSupplierId;
    _trackingMethod = item?.trackingMethod ?? 'NONE';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _descController.dispose();
    _barcodeController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _minStockController.dispose();
    _maxStockController.dispose();
    _reorderQtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryProvider);
    final metadata = state.metadata;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.item != null;

    // Reconcile and default dropdowns
    if (_selectedCategory != null && (metadata?.itemCategories.isNotEmpty ?? false)) {
      final match = metadata!.itemCategories.cast<InventoryDropdownItem?>().firstWhere(
        (c) =>
            c?.lookupCode.toUpperCase() == _selectedCategory!.toUpperCase() ||
            c?.lookupValue.toUpperCase() == _selectedCategory!.toUpperCase(),
        orElse: () => null,
      );
      if (match != null) {
        _selectedCategory = match.lookupCode;
      }
    }
    if (_selectedCategory == null && (metadata?.itemCategories.isNotEmpty ?? false)) {
      _selectedCategory = metadata!.itemCategories.first.lookupCode;
    }

    if (_selectedUom != null && (metadata?.unitsOfMeasurement.isNotEmpty ?? false)) {
      final match = metadata!.unitsOfMeasurement.cast<InventoryDropdownItem?>().firstWhere(
        (u) =>
            u?.lookupCode.toUpperCase() == _selectedUom!.toUpperCase() ||
            u?.lookupValue.toUpperCase() == _selectedUom!.toUpperCase(),
        orElse: () => null,
      );
      if (match != null) {
        _selectedUom = match.lookupCode;
      }
    }
    if (_selectedUom == null && (metadata?.unitsOfMeasurement.isNotEmpty ?? false)) {
      _selectedUom = metadata!.unitsOfMeasurement.first.lookupCode;
    }

    if (_selectedStatus != null && (metadata?.itemStatuses.isNotEmpty ?? false)) {
      final match = metadata!.itemStatuses.cast<InventoryDropdownItem?>().firstWhere(
        (s) =>
            s?.lookupCode.toUpperCase() == _selectedStatus!.toUpperCase() ||
            s?.lookupValue.toUpperCase() == _selectedStatus!.toUpperCase(),
        orElse: () => null,
      );
      if (match != null) {
        _selectedStatus = match.lookupCode;
      }
    }
    if (_selectedStatus == null && (metadata?.itemStatuses.isNotEmpty ?? false)) {
      _selectedStatus = metadata!.itemStatuses.first.lookupCode;
    }

    if (_selectedStoreId != null && (metadata?.stores.isNotEmpty ?? false)) {
      final hasStore = metadata!.stores.any((s) => s.storeId == _selectedStoreId);
      if (!hasStore) _selectedStoreId = null;
    }

    if (_selectedSupplierId != null && (metadata?.suppliers.isNotEmpty ?? false)) {
      final hasSupplier = metadata!.suppliers.any((s) => s.supplierId == _selectedSupplierId);
      if (!hasSupplier) _selectedSupplierId = null;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 720,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dialog Title Bar
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF2563EB), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditing ? 'Edit Inventory Item' : 'Create New Inventory Item',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Fill in catalog attributes, stock parameters, and pricing',
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

            // Form Content
            Flexible(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Row 1: Item Name & SKU
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: _buildTextField(
                              controller: _nameController,
                              label: 'Item Name *',
                              hint: 'e.g., Notebook (Classmate)',
                              validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: _buildTextField(
                              controller: _skuController,
                              label: 'SKU / Item Code',
                              hint: 'Auto-generated if empty',
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                tooltip: 'Generate unique SKU',
                                onPressed: () {
                                  final rand = DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase().substring(3, 8);
                                  setState(() => _skuController.text = 'SKU-$rand');
                                },
                              ),
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Row 2: Category & Unit of Measurement (From Universal Lookup Values)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: InventorySearchableDropdown<InventoryDropdownItem>(
                              label: 'Item Category',
                              value: _selectedCategory,
                              hint: 'Select or add category...',
                              isRequired: true,
                              items: metadata?.itemCategories ?? [],
                              getItemId: (c) => c.lookupCode,
                              getItemName: (c) => c.lookupValue,
                              prefixIcon: Icons.category_outlined,
                              allowManualEntry: true,
                              quickAddLabel: 'Add category to Universal Lookups',
                              onChanged: (val) => setState(() => _selectedCategory = val),
                              onQuickAdd: (text) async {
                                final added = await ref.read(inventoryProvider.notifier).quickAddLookup(
                                  keyCode: 'INVENTORY_ITEM_CATEGORY',
                                  valueName: text,
                                  description: 'Quick added item category',
                                );
                                return added?.lookupCode;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InventorySearchableDropdown<InventoryDropdownItem>(
                              label: 'Unit of Measurement',
                              value: _selectedUom,
                              hint: 'Select or add unit...',
                              isRequired: true,
                              items: metadata?.unitsOfMeasurement ?? [],
                              getItemId: (u) => u.lookupCode,
                              getItemName: (u) => u.lookupValue,
                              prefixIcon: Icons.straighten_outlined,
                              allowManualEntry: true,
                              quickAddLabel: 'Add unit to Universal Lookups',
                              onChanged: (val) => setState(() => _selectedUom = val),
                              onQuickAdd: (text) async {
                                final added = await ref.read(inventoryProvider.notifier).quickAddLookup(
                                  keyCode: 'INVENTORY_UNIT_OF_MEASUREMENT',
                                  valueName: text,
                                  description: 'Quick added unit of measurement',
                                );
                                return added?.lookupCode;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Row 3: Pricing (Purchase Price & Selling Price)
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _purchasePriceController,
                              label: 'Purchase Price (₹) *',
                              hint: '0.00',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (v) => double.tryParse(v ?? '') == null ? 'Invalid price' : null,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _sellingPriceController,
                              label: 'Selling Price (₹)',
                              hint: '0.00',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Row 4: Stock Levels (Min, Max, Reorder)
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _minStockController,
                              label: 'Min Stock Level',
                              hint: '10',
                              keyboardType: TextInputType.number,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _maxStockController,
                              label: 'Max Stock Level',
                              hint: '100',
                              keyboardType: TextInputType.number,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _reorderQtyController,
                              label: 'Reorder Quantity',
                              hint: '25',
                              keyboardType: TextInputType.number,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Row 5: Store, Supplier & Tracking Method
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: InventorySearchableDropdown<InventoryDropdownItem>(
                              label: 'Preferred Store',
                              value: _selectedStoreId,
                              hint: 'Select or add store...',
                              isRequired: false,
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
                                  description: 'Quick added store from Item Editor',
                                );
                                return added?.id ?? added?.code;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InventorySearchableDropdown<InventoryDropdownItem>(
                              label: 'Default Supplier',
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
                                  description: 'Quick added supplier from Item Editor',
                                );
                                return added?.id ?? added?.code;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDropdownField<String>(
                              label: 'Tracking Method',
                              value: _trackingMethod,
                              items: const [
                                DropdownMenuItem(value: 'NONE', child: Text('None (Standard)')),
                                DropdownMenuItem(value: 'BATCH', child: Text('Batch Controlled')),
                                DropdownMenuItem(value: 'EXPIRY', child: Text('Expiry Controlled')),
                                DropdownMenuItem(value: 'SERIAL', child: Text('Serial Tracked')),
                              ],
                              onChanged: (val) => setState(() => _trackingMethod = val ?? 'NONE'),
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Description
                      _buildTextField(
                        controller: _descController,
                        label: 'Description / Notes',
                        hint: 'Specifications, brand details or usage instructions...',
                        maxLines: 2,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Dialog Footer Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(isEditing ? 'Save Changes' : 'Create Item'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Widget? suffixIcon,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
            fontFamily: 'Inter',
          ),
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffixIcon,
            hintStyle: TextStyle(
              fontSize: 12.5,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T?>> items,
    required ValueChanged<T?> onChanged,
    required bool isDark,
  }) {
    // 1. Deduplicate by value
    final seen = <T?>{};
    final cleanItems = <DropdownMenuItem<T?>>[];
    for (final it in items) {
      if (seen.add(it.value)) {
        cleanItems.add(it);
      }
    }

    // 2. Validate value existence with case-insensitive fallback
    T? effectiveValue;
    if (cleanItems.any((it) => it.value == value)) {
      effectiveValue = value;
    } else if (cleanItems.any((it) => it.value != null && value != null && it.value.toString().toLowerCase() == value.toString().toLowerCase())) {
      effectiveValue = cleanItems.firstWhere((it) => it.value != null && value != null && it.value.toString().toLowerCase() == value.toString().toLowerCase()).value;
    } else if (cleanItems.isNotEmpty) {
      effectiveValue = cleanItems.first.value;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: AppSearchableDropdown<T?>.fromMenuItems(
              value: effectiveValue,
              isExpanded: true,
              items: cleanItems,
              onChanged: onChanged,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                fontFamily: 'Inter',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final categoryName = (ref.read(inventoryProvider).metadata?.itemCategories ?? [])
        .cast<InventoryDropdownItem?>()
        .firstWhere((c) => c?.lookupCode == _selectedCategory, orElse: () => null)
        ?.lookupValue ?? _selectedCategory ?? 'Stationery';

    final uomName = (ref.read(inventoryProvider).metadata?.unitsOfMeasurement ?? [])
        .cast<InventoryDropdownItem?>()
        .firstWhere((u) => u?.lookupCode == _selectedUom, orElse: () => null)
        ?.lookupValue ?? _selectedUom ?? 'Pcs';

    final payload = {
      if (widget.item != null) ...{
        'id': widget.item!.itemId,
        'item_id': widget.item!.itemId,
      },
      'item_name': _nameController.text.trim(),
      'name': _nameController.text.trim(),
      'sku': _skuController.text.trim().isEmpty ? null : _skuController.text.trim(),
      'description': _descController.text.trim(),
      'category': categoryName,
      'category_code': _selectedCategory,
      'unit': uomName,
      'uom_code': _selectedUom,
      'stock_status': _selectedStatus,
      'preferred_store_id': (_selectedStoreId != null && _selectedStoreId!.trim().isNotEmpty && _selectedStoreId != 'NONE') ? _selectedStoreId : null,
      'default_supplier_id': (_selectedSupplierId != null && _selectedSupplierId!.trim().isNotEmpty && _selectedSupplierId != 'NONE') ? _selectedSupplierId : null,
      'purchase_price': double.tryParse(_purchasePriceController.text) ?? 0.0,
      'selling_price': double.tryParse(_sellingPriceController.text) ?? 0.0,
      'min_stock': int.tryParse(_minStockController.text) ?? 10,
      'min_stock_level': double.tryParse(_minStockController.text) ?? 10.0,
      'max_stock': int.tryParse(_maxStockController.text) ?? 1000,
      'max_stock_level': double.tryParse(_maxStockController.text) ?? 1000.0,
      'reorder_quantity': double.tryParse(_reorderQtyController.text) ?? 25.0,
      'tracking_method': _trackingMethod,
    };

    final res = await ref.read(inventoryProvider.notifier).upsertItem(payload);
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (res['success'] == true) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.item != null ? 'Item updated successfully!' : 'Item created successfully!'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      } else {
        final errorMsg = res['error']?.toString() ?? res['message']?.toString() ?? 'Failed to save item. Please check errors.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }
}
