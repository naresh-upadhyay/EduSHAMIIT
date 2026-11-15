import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/inventory_models.dart';

class InventoryDetailDrawer extends StatelessWidget {
  final InventoryItem? item;
  final InventoryMovement? movement;
  final PurchaseOrder? purchaseOrder;
  final SalesOrder? salesOrder;
  final VoidCallback? onClose;
  final VoidCallback? onEdit;
  final VoidCallback? onDownloadPdf;

  const InventoryDetailDrawer({
    super.key,
    this.item,
    this.movement,
    this.purchaseOrder,
    this.salesOrder,
    this.onClose,
    this.onEdit,
    this.onDownloadPdf,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
    final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');

    return SelectionArea(
      child: Container(
        width: double.infinity,
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drawer Top Bar with Action Controls
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            _getHeaderIcon(),
                            size: 20,
                            color: const Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _getTitle(),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                fontFamily: 'Inter',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onDownloadPdf != null) ...[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          side: BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.file_download_outlined, size: 16, color: Color(0xFF2563EB)),
                        label: const Text(
                          'Invoice PDF',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                        ),
                        onPressed: onDownloadPdf,
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (onEdit != null) ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text(
                          'Edit',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        onPressed: onEdit,
                      ),
                      const SizedBox(width: 8),
                    ],
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: onClose ?? () => Navigator.of(context).pop(),
                      tooltip: 'Close Drawer',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ),

              // Drawer Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildBody(context, isDark, currencyFmt, dateFmt),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getHeaderIcon() {
    if (item != null) return Icons.inventory_2_outlined;
    if (movement != null) return Icons.swap_horiz_rounded;
    if (purchaseOrder != null) return Icons.receipt_long_rounded;
    if (salesOrder != null) return Icons.point_of_sale_rounded;
    return Icons.info_outline;
  }

  String _getTitle() {
    if (item != null) return 'Item: ${item!.name}';
    if (movement != null) return 'Transaction: ${movement!.movementType}';
    if (purchaseOrder != null) return 'Purchase Invoice: ${purchaseOrder!.poNumber}';
    if (salesOrder != null) return 'Tax Invoice: ${salesOrder!.soNumber}';
    return 'Details';
  }

  Widget _buildBody(BuildContext context, bool isDark, NumberFormat currencyFmt, DateFormat dateFmt) {
    if (item != null) {
      final i = item!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF2563EB), size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        i.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text('SKU: ${i.sku} • ${i.categoryName}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Stock parameters
          _buildSectionHeader('Stock & Valuation', isDark),
          const SizedBox(height: 10),
          _buildInfoRow('Current Physical Stock', '${i.currentStock.toInt()} ${i.uomCode}', isDark, isHighlight: true),
          _buildInfoRow('Min Stock Level', '${i.minStockLevel.toInt()} ${i.uomCode}', isDark),
          _buildInfoRow('Max Stock Level', '${i.maxStockLevel.toInt()} ${i.uomCode}', isDark),
          _buildInfoRow('Reorder Quantity', '${i.reorderQuantity.toInt()} ${i.uomCode}', isDark),
          _buildInfoRow('Purchase Price', currencyFmt.format(i.purchasePrice), isDark),
          _buildInfoRow('Selling Price', currencyFmt.format(i.sellingPrice), isDark),
          _buildInfoRow('Stock Valuation', currencyFmt.format(i.currentStock * i.purchasePrice), isDark, isHighlight: true),
          const SizedBox(height: 20),

          _buildSectionHeader('Item Specifications', isDark),
          const SizedBox(height: 10),
          _buildInfoRow('Category', i.categoryName, isDark),
          _buildInfoRow('Unit of Measure', i.uomName, isDark),
          _buildInfoRow('Tracking Method', i.trackingMethod, isDark),
          _buildInfoRow('Stock Status', i.stockStatus, isDark),
          _buildInfoRow('Description', i.description ?? '-', isDark, isMultiLine: true),
        ],
      );
    }

    if (movement != null) {
      final m = movement!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Movement Overview', isDark),
          const SizedBox(height: 10),
          _buildInfoRow('Item Name', m.itemName, isDark),
          _buildInfoRow('Movement Type', m.movementType, isDark, isHighlight: true),
          _buildInfoRow('Quantity', '${m.quantity > 0 ? '+' : ''}${m.quantity.toInt()}', isDark),
          _buildInfoRow('Unit Rate', currencyFmt.format(m.unitCost), isDark),
          _buildInfoRow('Total Valuation', currencyFmt.format(m.totalCost), isDark, isHighlight: true),
          _buildInfoRow('Location / Store', m.storeName, isDark),
          _buildInfoRow('Date & Time', m.formattedDateTime.replaceAll('\n', ' '), isDark),
          _buildInfoRow('Reference #', m.referenceNumber ?? '-', isDark),
          _buildInfoRow('Notes / Remarks', m.notes ?? '-', isDark, isMultiLine: true),
        ],
      );
    }

    if (purchaseOrder != null) {
      return _buildPurchaseInvoiceDetails(purchaseOrder!, isDark, currencyFmt);
    }

    if (salesOrder != null) {
      return _buildSalesInvoiceDetails(salesOrder!, isDark, currencyFmt);
    }

    return const Center(child: Text('No details available.'));
  }

  /// Official Purchase Order & Procurement Invoice View
  Widget _buildPurchaseInvoiceDetails(PurchaseOrder po, bool isDark, NumberFormat currencyFmt) {
    final statusUpper = po.status.toUpperCase();
    Color statusColor = const Color(0xFFF59E0B);
    if (statusUpper == 'DELIVERED' || statusUpper == 'COMPLETED' || statusUpper == 'RECEIVED') {
      statusColor = const Color(0xFF10B981);
    } else if (statusUpper == 'CANCELLED') {
      statusColor = const Color(0xFFEF4444);
    } else if (statusUpper == 'APPROVED' || statusUpper == 'PARTIAL') {
      statusColor = const Color(0xFF2563EB);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Institution Branding & Invoice Title Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Greenwood High International School',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Campus Road, Sarjapur, Bangalore, Karnataka - 560035',
                          style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                        Text(
                          'GSTIN: 29AAACG1234F1Z8 | Phone: +91 80 4567 8900',
                          style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                        Text(
                          'Email: procurement@edushamiit.edu.in',
                          style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'PURCHASE ORDER & REQUISITION',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2563EB),
                          fontFamily: 'Inter',
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'PO #: ${po.poNumber}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          po.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Date: ${po.formattedOrderDate}',
                        style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Vendor & Dispatch Detail Cards (Side-by-side)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vendor Details Card
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'VENDOR / SUPPLIER DETAILS:',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2563EB),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      po.supplierName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildCompactMeta('GSTIN', po.supplierGstin, isDark),
                    _buildCompactMeta('Account Status', 'Active Approved Vendor', isDark),
                    _buildCompactMeta('Payment Terms', po.paymentTerms, isDark),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Dispatch & Requisition Card
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DISPATCH & REQUISITION:',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2563EB),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildCompactMeta('Target Store', po.department.isNotEmpty ? po.department : 'Main Campus Store', isDark),
                    _buildCompactMeta('PO Date', po.formattedOrderDate, isDark),
                    _buildCompactMeta('Expected Delivery', po.formattedDeliveryDate, isDark),
                    _buildCompactMeta('Delivery Address', po.shippingAddress, isDark),
                    _buildCompactMeta('Fulfillment State', po.status, isDark),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 3. Complete Line Items Table
        _buildSectionHeader('Purchased Items Specification', isDark),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              // Table Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                ),
                child: const Row(
                  children: [
                    SizedBox(width: 28, child: Text('#', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    Expanded(flex: 3, child: Text('Item Name & Description', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    SizedBox(width: 90, child: Text('SKU / Code', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    SizedBox(width: 50, child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    SizedBox(width: 45, child: Text('Unit', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    SizedBox(width: 75, child: Text('Rate (₹)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    SizedBox(width: 55, child: Text('Tax %', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    SizedBox(width: 85, child: Text('Total (₹)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                  ],
                ),
              ),

              // Items Rows
              if (po.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No item details recorded for this purchase order.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                )
              else
                ...po.items.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final it = entry.value;
                  final isEven = idx % 2 == 0;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isEven
                          ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                          : (isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC)),
                      border: Border(
                        top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(width: 28, child: Text('${idx + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                        Expanded(
                          flex: 3,
                          child: Text(
                            it.itemName,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 90,
                          child: Text(
                            it.sku.isNotEmpty ? it.sku : '-',
                            style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF64748B)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 50, child: Text('${it.quantity.toInt()}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
                        SizedBox(width: 45, child: Text(it.unit, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                        SizedBox(width: 75, child: Text(currencyFmt.format(it.unitPrice), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
                        SizedBox(width: 55, child: Text('${it.taxRate.toInt()}%', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                        SizedBox(
                          width: 85,
                          child: Text(
                            currencyFmt.format(it.totalPrice),
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4. Financial Summary, Words, and Remarks
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Words & Remarks
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Invoice Total (in words):',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          po.amountInWords,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Remarks / Dispatch Notes:',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (po.notes != null && po.notes!.trim().isNotEmpty)
                              ? po.notes!
                              : 'Official procurement order fulfilled under institutional educational quota.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Right Column: Financial Breakdown
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildTotalRow('Taxable Subtotal:', currencyFmt.format(po.subtotal > 0 ? po.subtotal : po.totalAmount), isDark),
                    const SizedBox(height: 6),
                    _buildTotalRow('Integrated GST:', currencyFmt.format(po.taxAmount), isDark),
                    const SizedBox(height: 6),
                    _buildTotalRow('Shipping / Freight:', currencyFmt.format(po.shippingAmount), isDark),
                    const Divider(height: 16),
                    _buildTotalRow(
                      'Invoice Grand Total:',
                      currencyFmt.format(po.totalAmount),
                      isDark,
                      isGrandTotal: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // 5. Terms & Declaration Section
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DECLARATION & TERMS:',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 6),
              Text(
                (po.termsConditions != null && po.termsConditions!.trim().isNotEmpty)
                    ? po.termsConditions!
                    : '1. Certified that the particulars given above are true and correct.\n'
                        '2. Subject to Bangalore Jurisdiction.\n'
                        '3. Any discrepancies must be brought to notice within 7 days of delivery.\n'
                        '4. This is a computer generated official procurement order.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.45,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 6. Signatory Verification Box
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: 160,
                  height: 1,
                  color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Authorized Signatory',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const Text(
                  'EduSHAMIIT Procurement & Inventory Management',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                const Text(
                  'Official Digital Procurement Document',
                  style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// Official Sales Order & Tax Invoice View
  Widget _buildSalesInvoiceDetails(SalesOrder so, bool isDark, NumberFormat currencyFmt) {
    final statusUpper = so.status.toUpperCase();
    Color statusColor = const Color(0xFFF59E0B);
    if (statusUpper == 'DELIVERED' || statusUpper == 'COMPLETED' || statusUpper == 'FULFILLED') {
      statusColor = const Color(0xFF10B981);
    } else if (statusUpper == 'CANCELLED') {
      statusColor = const Color(0xFFEF4444);
    } else if (statusUpper == 'PROCESSING') {
      statusColor = const Color(0xFF2563EB);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Institution Branding & Invoice Title Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Greenwood High International School',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Campus Road, Sarjapur, Bangalore, Karnataka - 560035',
                          style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                        Text(
                          'GSTIN: 29AAACG1234F1Z8 | Phone: +91 80 4567 8900',
                          style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                        Text(
                          'Email: sales@edushamiit.edu.in',
                          style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'TAX INVOICE & SALES ORDER',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF059669),
                          fontFamily: 'Inter',
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Invoice / SO: ${so.soNumber}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          so.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Date: ${so.formattedOrderDate}',
                        style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Customer & Dispatch Detail Cards (Side-by-side)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer Details Card
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BILL TO / CUSTOMER DETAILS:',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF059669),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      so.customerName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildCompactMeta('Client Classification', so.customerType, isDark),
                    _buildCompactMeta('Customer GSTIN', so.customerGstin, isDark),
                    _buildCompactMeta('Account Status', 'Verified Institutional Account', isDark),
                    if (so.contactPhone != null && so.contactPhone!.isNotEmpty)
                      _buildCompactMeta('Phone', so.contactPhone!, isDark),
                    if (so.contactEmail != null && so.contactEmail!.isNotEmpty)
                      _buildCompactMeta('Email', so.contactEmail!, isDark),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Dispatch & Sales Record Card
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DISPATCH & SALES RECORD:',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF059669),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildCompactMeta('Origin Store', so.department.isNotEmpty ? so.department : 'Sales & Distribution', isDark),
                    _buildCompactMeta('SO Date', so.formattedOrderDate, isDark),
                    _buildCompactMeta('Delivery Date', so.formattedDeliveryDate, isDark),
                    _buildCompactMeta('Dispatch Location', so.shippingAddress, isDark),
                    _buildCompactMeta('Fulfillment State', so.status, isDark),
                    _buildCompactMeta('Payment Terms', so.paymentTerms, isDark),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 3. Complete Line Items Table
        _buildSectionHeader('Billed Items Specification', isDark),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              // Table Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                ),
                child: const Row(
                  children: [
                    SizedBox(width: 28, child: Text('#', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    Expanded(flex: 3, child: Text('Item Name & Description', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    SizedBox(width: 90, child: Text('SKU / Code', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    SizedBox(width: 50, child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    SizedBox(width: 45, child: Text('Unit', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    SizedBox(width: 75, child: Text('Rate (₹)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    SizedBox(width: 55, child: Text('Tax %', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    SizedBox(width: 85, child: Text('Total (₹)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                  ],
                ),
              ),

              // Items Rows
              if (so.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No item details recorded for this sales order.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                )
              else
                ...so.items.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final it = entry.value;
                  final isEven = idx % 2 == 0;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isEven
                          ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                          : (isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC)),
                      border: Border(
                        top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(width: 28, child: Text('${idx + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                        Expanded(
                          flex: 3,
                          child: Text(
                            it.itemName,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 90,
                          child: Text(
                            it.sku.isNotEmpty ? it.sku : '-',
                            style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF64748B)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 50, child: Text('${it.quantity.toInt()}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
                        SizedBox(width: 45, child: Text(it.unit, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                        SizedBox(width: 75, child: Text(currencyFmt.format(it.unitPrice), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
                        SizedBox(width: 55, child: Text('${it.taxRate.toInt()}%', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                        SizedBox(
                          width: 85,
                          child: Text(
                            currencyFmt.format(it.totalPrice),
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4. Financial Summary, Words, and Remarks
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Words & Remarks
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Invoice Total (in words):',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          so.amountInWords,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Remarks / Dispatch Notes:',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (so.notes != null && so.notes!.trim().isNotEmpty)
                              ? so.notes!
                              : 'Consignment sales fulfilled under institutional educational quota.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Right Column: Financial Breakdown
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildTotalRow('Taxable Subtotal:', currencyFmt.format(so.subtotal > 0 ? so.subtotal : so.totalAmount), isDark),
                    const SizedBox(height: 6),
                    _buildTotalRow('Integrated GST:', currencyFmt.format(so.taxAmount), isDark),
                    const SizedBox(height: 6),
                    _buildTotalRow('Discount:', currencyFmt.format(so.discountAmount), isDark),
                    const Divider(height: 16),
                    _buildTotalRow(
                      'Invoice Grand Total:',
                      currencyFmt.format(so.totalAmount),
                      isDark,
                      isGrandTotal: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // 5. Terms & Declaration Section
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DECLARATION & TERMS:',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 6),
              Text(
                (so.termsConditions != null && so.termsConditions!.trim().isNotEmpty)
                    ? so.termsConditions!
                    : '1. Certified that the particulars given above are true and correct.\n'
                        '2. Subject to Bangalore Jurisdiction.\n'
                        '3. Any discrepancies must be brought to notice within 7 days of delivery.\n'
                        '4. This is a computer generated tax invoice.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.45,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 6. Signatory Verification Box
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: 160,
                  height: 1,
                  color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Authorized Signatory',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const Text(
                  'EduSHAMIIT Inventory & Sales Operations',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                const Text(
                  'Official Digital Billing Document',
                  style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactMeta(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 12, fontFamily: 'Inter', color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(
              text: value.isNotEmpty ? value : '-',
              style: TextStyle(fontWeight: FontWeight.w500, color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(String label, String value, bool isDark, {bool isGrandTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: isGrandTotal ? 13.5 : 12,
              fontWeight: isGrandTotal ? FontWeight.w800 : FontWeight.w500,
              color: isGrandTotal
                  ? (isDark ? Colors.white : const Color(0xFF0F172A))
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: isGrandTotal ? 14.5 : 12.5,
            fontWeight: isGrandTotal ? FontWeight.w800 : FontWeight.w600,
            color: isGrandTotal
                ? const Color(0xFF2563EB)
                : (isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A)),
          ),
        ),
      ],
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

  Widget _buildInfoRow(String label, String value, bool isDark, {bool isHighlight = false, bool isMultiLine = false}) {
    if (isMultiLine || value.length > 50) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 5),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: SelectableText(
                value,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
                  color: isHighlight
                      ? const Color(0xFF2563EB)
                      : (isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A)),
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 135,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontFamily: 'Inter',
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              softWrap: true,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
                color: isHighlight
                    ? const Color(0xFF2563EB)
                    : (isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A)),
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
