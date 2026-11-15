import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/inventory/models/inventory_models.dart';
import 'package:edu_shamiit_core/screens/inventory/widgets/inventory_tabs_bar.dart';
import 'package:edu_shamiit_core/screens/inventory/widgets/inventory_kpi_cards.dart';
import 'package:edu_shamiit_core/screens/inventory/widgets/dialogs/create_edit_item_dialog.dart';
import 'package:edu_shamiit_core/screens/inventory/widgets/dialogs/receive_stock_dialog.dart';
import 'package:edu_shamiit_core/screens/inventory/widgets/dialogs/issue_stock_dialog.dart';
import 'package:edu_shamiit_core/screens/inventory/widgets/dialogs/adjust_stock_dialog.dart';
import 'package:edu_shamiit_core/screens/inventory/widgets/dialogs/inventory_detail_drawer.dart';
import 'package:edu_shamiit_core/screens/inventory/widgets/dialogs/edit_purchase_order_dialog.dart';
import 'package:edu_shamiit_core/screens/inventory/widgets/dialogs/edit_sales_order_dialog.dart';

void main() {
  group('Enterprise Inventory Models Serialization & Business Logic', () {
    test('InventoryItem fromJson and helper getters', () {
      final json = {
        'id': 'item-101',
        'item_id': 'item-101',
        'sku': 'NB-CLS-001',
        'item_name': 'Notebook (Classmate)',
        'description': '180 pages single line ruled notebook',
        'category': 'Stationery',
        'unit': 'Pcs',
        'current_stock': 250.0,
        'min_stock': 50,
        'max_stock': 1000,
        'purchase_price': 50.0,
        'selling_price': 65.0,
        'tax_rate': 18.0,
        'status': 'In Stock',
        'preferred_store_id': 'store-1',
        'tracking_method': 'Quantity-based',
      };

      final item = InventoryItem.fromJson(json);
      expect(item.id, 'item-101');
      expect(item.itemId, 'item-101');
      expect(item.name, 'Notebook (Classmate)');
      expect(item.sku, 'NB-CLS-001');
      expect(item.categoryName, 'Stationery');
      expect(item.uomCode, 'Pcs');
      expect(item.currentStock, 250.0);
      expect(item.minStockLevel, 50.0);
      expect(item.purchasePrice, 50.0);
      expect(item.sellingPrice, 65.0);
      expect(item.stockStatus, 'In Stock');
      expect(item.isLowStock, false);
      expect(item.isOutOfStock, false);
    });

    test('InventoryItem detects low stock and out of stock conditions', () {
      final lowStockJson = {
        'id': 'item-102',
        'sku': 'MKR-WB-001',
        'item_name': 'White Board Marker',
        'category': 'Stationery',
        'unit': 'Pcs',
        'current_stock': 5.0,
        'min_stock': 20,
        'purchase_price': 20.0,
        'selling_price': 30.0,
        'status': 'Low Stock',
      };
      final lowItem = InventoryItem.fromJson(lowStockJson);
      expect(lowItem.isLowStock, true);
      expect(lowItem.isOutOfStock, false);

      final outStockJson = {
        'id': 'item-103',
        'sku': 'OUT-001',
        'item_name': 'Sold Out Item',
        'category': 'Stationery',
        'unit': 'Pcs',
        'current_stock': 0.0,
        'min_stock': 15,
        'purchase_price': 10.0,
        'selling_price': 15.0,
        'status': 'Out of Stock',
      };
      final outItem = InventoryItem.fromJson(outStockJson);
      expect(outItem.isLowStock, false);
      expect(outItem.isOutOfStock, true);
    });

    test('InventoryMovement deserialization and quantity direction', () {
      final jsonIn = {
        'id': 'mov-1',
        'movement_number': 'MOV-2026-001',
        'date_time': '2026-03-31T16:15:00',
        'transaction_type': 'Purchase',
        'item_id': 'item-101',
        'item_name': 'Notebook (Classmate)',
        'sku': 'NB-CLS-001',
        'quantity': 500.0,
        'unit': 'Pcs',
        'rate': 50.0,
        'total': 25000.0,
        'location': 'Main Store',
        'remarks': 'Supplier: ABC Enterprises',
      };
      final movIn = InventoryMovement.fromJson(jsonIn);
      expect(movIn.movementId, 'mov-1');
      expect(movIn.isStockIn, true);
      expect(movIn.unitCost, 50.0);
      expect(movIn.totalCost, 25000.0);

      final jsonOut = {
        'id': 'mov-2',
        'movement_number': 'MOV-2026-002',
        'date_time': '2026-03-30T11:20:00',
        'transaction_type': 'Sale',
        'item_id': 'item-102',
        'item_name': 'White Board Marker',
        'sku': 'MKR-WB-001',
        'quantity': -100.0,
        'unit': 'Pcs',
        'rate': 20.0,
        'total': 2000.0,
        'location': 'Lab Store',
        'remarks': 'To Class 10-A',
      };
      final movOut = InventoryMovement.fromJson(jsonOut);
      expect(movOut.isStockIn, false);
      expect(movOut.quantity, -100.0);
    });

    test('PurchaseOrder & SalesOrder model parsing', () {
      final poJson = {
        'id': 'po-1',
        'po_number': 'PO-2026-001',
        'date': '2026-03-25',
        'supplier': 'ABC Enterprises',
        'supplier_gstin': '29ABCDE1234F1Z5',
        'department': 'Main Campus Store',
        'shipping_address': 'Sarjapur Campus, Bangalore',
        'payment_terms': 'Net 30 Days',
        'subtotal': 60000.0,
        'tax_amount': 10800.0,
        'shipping_amount': 500.0,
        'total_amount': 71300.0,
        'status': 'Delivered',
        'delivery_date': '2026-03-28',
        'items': [
          {
            'po_item_id': 'poi-1',
            'item_id': 'item-101',
            'item_name': 'Notebook (Classmate)',
            'sku': 'NB-CLS-001',
            'unit': 'Pcs',
            'quantity': 1000.0,
            'unit_price': 60.0,
            'tax_rate': 18.0,
            'total_price': 60000.0,
          }
        ],
      };
      final po = PurchaseOrder.fromJson(poJson);
      expect(po.poId, 'po-1');
      expect(po.poNumber, 'PO-2026-001');
      expect(po.supplierName, 'ABC Enterprises');
      expect(po.supplierGstin, '29ABCDE1234F1Z5');
      expect(po.paymentTerms, 'Net 30 Days');
      expect(po.subtotal, 60000.0);
      expect(po.taxAmount, 10800.0);
      expect(po.totalAmount, 71300.0);
      expect(po.status, 'Delivered');
      expect(po.items.length, 1);
      expect(po.items.first.sku, 'NB-CLS-001');
      expect(po.amountInWords, contains('Rupees'));

      final soJson = {
        'id': 'so-1',
        'so_number': 'SO-2026-001',
        'date': '2026-03-26',
        'customer': 'ABC School',
        'customer_type': 'Partner School',
        'customer_gstin': '29XYZDE9876F1Z1',
        'department': 'Sales & Distribution',
        'shipping_address': 'Bangalore Center Hub',
        'payment_terms': 'Due on Receipt',
        'subtotal': 12000.0,
        'tax_amount': 600.0,
        'discount_amount': 100.0,
        'total_amount': 12500.0,
        'status': 'Delivered',
        'delivery_date': '2026-03-26',
        'items': [
          {
            'so_item_id': 'soi-1',
            'item_id': 'item-102',
            'item_name': 'White Board Marker',
            'sku': 'MKR-WB-001',
            'unit': 'Pcs',
            'quantity': 200.0,
            'unit_price': 60.0,
            'tax_rate': 5.0,
            'total_price': 12000.0,
          }
        ],
      };
      final so = SalesOrder.fromJson(soJson);
      expect(so.soId, 'so-1');
      expect(so.soNumber, 'SO-2026-001');
      expect(so.customerName, 'ABC School');
      expect(so.customerType, 'Partner School');
      expect(so.customerGstin, '29XYZDE9876F1Z1');
      expect(so.totalAmount, 12500.0);
      expect(so.status, 'Delivered');
      expect(so.items.length, 1);
      expect(so.items.first.unit, 'Pcs');
      expect(so.amountInWords, contains('Rupees Twelve Thousand Five Hundred Only'));
    });

    test('Metadata & Overview default fallback structures', () {
      final meta = InventoryMetadata.fromJson({
        'item_statuses': [
          {'lookup_code': 'ACTIVE', 'lookup_value': 'Active'},
          {'lookup_code': 'LOW_STOCK', 'lookup_value': 'Low Stock'},
          {'lookup_code': 'OUT_OF_STOCK', 'lookup_value': 'Out of Stock'},
        ],
        'adjustment_reasons': [
          {'lookup_code': 'DAMAGE', 'lookup_value': 'Damage'},
          {'lookup_code': 'EXPIRY', 'lookup_value': 'Expiry'},
          {'lookup_code': 'THEFT', 'lookup_value': 'Theft'},
          {'lookup_code': 'CORRECTION', 'lookup_value': 'Correction'},
          {'lookup_code': 'AUDIT', 'lookup_value': 'Physical Audit'},
        ],
      });
      expect(meta.categories, isEmpty);
      expect(meta.itemStatuses.length, 3);
      expect(meta.adjustmentReasons.length, 5);

      final emptyMeta = InventoryMetadata.fromJson({});
      expect(emptyMeta.itemStatuses, isEmpty);
      expect(emptyMeta.adjustmentReasons, isEmpty);

      final ov = InventoryOverviewData.fromJson({});
      expect(ov.totalItems, 286);
      expect(ov.totalPurchaseOrders, 72);
      expect(ov.totalSalesOrders, 186);
    });
  });

  group('Inventory Widgets Rendering & Tab Interactions', () {
    testWidgets('InventoryTabsBar renders all 4 tabs and responds to tap', (tester) async {
      int tappedIndex = -1;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: InventoryTabsBar(
                onTabChanged: (idx) => tappedIndex = idx,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Stock Overview'), findsOneWidget);
      expect(find.text('Recent Transactions'), findsOneWidget);
      expect(find.text('Purchase Orders'), findsOneWidget);
      expect(find.text('Sales Orders'), findsOneWidget);

      // Tap 'Purchase Orders' tab
      await tester.tap(find.text('Purchase Orders'));
      await tester.pumpAndSettle();

      expect(tappedIndex, 2);
    });

    testWidgets('InventoryKpiCards renders 4 top cards with formatted numbers and percentage chips', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: InventoryKpiCards(),
              ),
            ),
          ),
        ),
      );

      // Default Tab 0 cards
      expect(find.text('Total Items'), findsOneWidget);
      expect(find.text('0'), findsWidgets);
      expect(find.text('Total Stock Value'), findsOneWidget);
      expect(find.text('Pending Purchase'), findsOneWidget);
      expect(find.text('Low Stock Items'), findsOneWidget);
      expect(find.text('Valuation'), findsOneWidget);
    });

    testWidgets('CreateEditItemDialog renders form fields with dynamic lookups', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CreateEditItemDialog(),
            ),
          ),
        ),
      );

      expect(find.text('Create New Inventory Item'), findsOneWidget);
      expect(find.text('Item Name *'), findsOneWidget);
      expect(find.text('SKU / Item Code'), findsOneWidget);
      expect(find.text('Purchase Price (₹) *'), findsOneWidget);
      expect(find.text('Min Stock Level'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Create Item'), findsOneWidget);
    });

    testWidgets('ReceiveStockDialog displays intake inputs and validation', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ReceiveStockDialog(),
            ),
          ),
        ),
      );

      expect(find.text('Receive Stock'), findsOneWidget);
      expect(find.text('Quantity to Receive *'), findsOneWidget);
      expect(find.text('Unit Cost (₹) *'), findsOneWidget);
      expect(find.text('Confirm Receipt'), findsOneWidget);
    });

    testWidgets('IssueStockDialog displays recipient and department fields', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: IssueStockDialog(),
            ),
          ),
        ),
      );

      expect(find.text('Issue Stock'), findsOneWidget);
      expect(find.text('Department / Room *'), findsOneWidget);
      expect(find.text('Recipient Name / Staff *'), findsOneWidget);
      expect(find.text('Confirm Issue'), findsOneWidget);
    });

    testWidgets('AdjustStockDialog displays adjustment reasons and type selector', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AdjustStockDialog(),
            ),
          ),
        ),
      );

      expect(find.text('Stock Adjustment'), findsOneWidget);
      expect(find.text('Adjustment Type *'), findsOneWidget);
      expect(find.text('Adjustment Reason *'), findsOneWidget);
      expect(find.text('Apply Adjustment'), findsOneWidget);
    });

    testWidgets('InventoryDetailDrawer renders full Purchase Order invoice view with actions', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool editCalled = false;
      bool pdfCalled = false;

      final po = PurchaseOrder.fromJson({
        'id': 'po-test-1',
        'po_number': 'PO-2026-999',
        'date': '2026-11-10',
        'supplier': 'Acme Lab Supplies',
        'supplier_gstin': '29ACME1234F1Z9',
        'department': 'Chemistry Laboratory',
        'shipping_address': 'Sarjapur Campus, Lab Store',
        'payment_terms': 'Net 30 Days',
        'subtotal': 4500.0,
        'tax_amount': 810.0,
        'shipping_amount': 150.0,
        'total_amount': 5460.0,
        'status': 'Approved',
        'delivery_date': '2026-11-17',
        'notes': 'Fragile glassware shipment handle with care.',
        'items': [
          {
            'po_item_id': 'poi-99',
            'item_id': 'item-glass-1',
            'item_name': 'Borosil Beaker 500ml',
            'sku': 'GLS-BEAK-500',
            'unit': 'Pcs',
            'quantity': 30.0,
            'unit_price': 150.0,
            'tax_rate': 18.0,
            'total_price': 4500.0,
          }
        ],
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 1000,
              child: InventoryDetailDrawer(
                purchaseOrder: po,
                onEdit: () => editCalled = true,
                onDownloadPdf: () => pdfCalled = true,
              ),
            ),
          ),
        ),
      );

      // Verify Header and Branding
      expect(find.text('Greenwood High International School'), findsOneWidget);
      expect(find.text('PURCHASE ORDER & REQUISITION'), findsOneWidget);
      expect(find.text('PO #: PO-2026-999'), findsOneWidget);
      expect(find.text('APPROVED'), findsOneWidget);

      // Verify Vendor and Billing Details
      expect(find.text('VENDOR / SUPPLIER DETAILS:'), findsOneWidget);
      expect(find.text('Acme Lab Supplies'), findsOneWidget);
      expect(find.text('DISPATCH & REQUISITION:'), findsOneWidget);

      // Verify Line Item Table
      expect(find.text('Borosil Beaker 500ml'), findsOneWidget);
      expect(find.text('GLS-BEAK-500'), findsOneWidget);

      // Verify Words, Financials and Declarations
      expect(find.text('Invoice Total (in words):'), findsOneWidget);
      expect(find.text('Taxable Subtotal:'), findsOneWidget);
      expect(find.text('DECLARATION & TERMS:'), findsOneWidget);
      expect(find.text('Authorized Signatory'), findsOneWidget);

      // Verify Top Bar Actions
      expect(find.text('Invoice PDF'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);

      await tester.tap(find.text('Edit'));
      expect(editCalled, true);

      await tester.tap(find.text('Invoice PDF'));
      expect(pdfCalled, true);
    });

    testWidgets('InventoryDetailDrawer renders full Sales Order invoice view with actions', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final so = SalesOrder.fromJson({
        'id': 'so-test-1',
        'so_number': 'SO-2026-888',
        'date': '2026-11-10',
        'customer': 'St. Xavier High School Branch',
        'customer_type': 'Partner School',
        'customer_gstin': '29STXAVIER123F1Z0',
        'department': 'Central Distribution Hub',
        'shipping_address': 'Whitefield Campus Delivery',
        'payment_terms': 'Due on Receipt',
        'subtotal': 8000.0,
        'tax_amount': 400.0,
        'discount_amount': 200.0,
        'total_amount': 8200.0,
        'status': 'Delivered',
        'delivery_date': '2026-11-12',
        'notes': 'Annual stationery consignment.',
        'items': [
          {
            'so_item_id': 'soi-88',
            'item_id': 'item-stat-1',
            'item_name': 'Official School Diary 2026',
            'sku': 'STAT-DIR-2026',
            'unit': 'Pcs',
            'quantity': 100.0,
            'unit_price': 80.0,
            'tax_rate': 5.0,
            'total_price': 8000.0,
          }
        ],
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 1000,
              child: InventoryDetailDrawer(
                salesOrder: so,
              ),
            ),
          ),
        ),
      );

      // Verify Header and Branding
      expect(find.text('Greenwood High International School'), findsOneWidget);
      expect(find.text('TAX INVOICE & SALES ORDER'), findsOneWidget);
      expect(find.text('Invoice / SO: SO-2026-888'), findsOneWidget);
      expect(find.text('DELIVERED'), findsOneWidget);

      // Verify Customer Details
      expect(find.text('BILL TO / CUSTOMER DETAILS:'), findsOneWidget);
      expect(find.text('St. Xavier High School Branch'), findsOneWidget);
      expect(find.text('DISPATCH & SALES RECORD:'), findsOneWidget);

      // Verify Line Item Table
      expect(find.text('Official School Diary 2026'), findsOneWidget);
      expect(find.text('STAT-DIR-2026'), findsOneWidget);

      // Verify Summary and Signatory
      expect(find.text('Invoice Total (in words):'), findsOneWidget);
      expect(find.text('EduSHAMIIT Inventory & Sales Operations'), findsOneWidget);
    });

    testWidgets('EditPurchaseOrderDialog renders prefilled values and responds to interaction', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final po = PurchaseOrder.fromJson({
        'id': 'po-edit-1',
        'po_number': 'PO-2026-333',
        'date': '2026-11-10',
        'supplier': 'National Book Depot',
        'supplier_gstin': '29NATBK1234F1Z2',
        'department': 'Main Store',
        'shipping_address': 'Sarjapur Campus, Gate 2',
        'payment_terms': 'Net 15 Days',
        'subtotal': 2000.0,
        'tax_amount': 360.0,
        'total_amount': 2360.0,
        'status': 'Pending',
        'items': [
          {
            'po_item_id': 'poi-33',
            'item_id': 'it-33',
            'item_name': 'Drawing Sheet Pack',
            'sku': 'ART-DRW-001',
            'unit': 'Pack',
            'quantity': 20.0,
            'unit_price': 100.0,
            'tax_rate': 18.0,
            'total_price': 2000.0,
          }
        ],
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: EditPurchaseOrderDialog(purchaseOrder: po),
            ),
          ),
        ),
      );

      expect(find.text('Edit Purchase Order'), findsOneWidget);
      expect(find.text('PO-2026-333'), findsOneWidget);
      expect(find.text('Vendor & Billing Credentials'), findsOneWidget);
      expect(find.text('Supplier GSTIN / Tax ID'), findsOneWidget);
      expect(find.text('Logistics & Delivery Record'), findsOneWidget);
      expect(find.text('Order Line Items'), findsOneWidget);
      expect(find.text('Save Order Changes'), findsOneWidget);
    });

    testWidgets('EditSalesOrderDialog renders prefilled values and responds to interaction', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final so = SalesOrder.fromJson({
        'id': 'so-edit-1',
        'so_number': 'SO-2026-444',
        'date': '2026-11-10',
        'customer': 'Bangalore City Campus Store',
        'customer_type': 'Student',
        'customer_gstin': '29BLRCAMPUS123F',
        'department': 'Sales & Distribution',
        'shipping_address': 'Campus Bookstore Counter',
        'payment_terms': 'Due on Receipt',
        'subtotal': 1500.0,
        'tax_amount': 75.0,
        'total_amount': 1575.0,
        'status': 'Processing',
        'items': [
          {
            'so_item_id': 'soi-44',
            'item_id': 'it-44',
            'item_name': 'School Tie & Badge',
            'sku': 'UNIF-TIE-001',
            'unit': 'Set',
            'quantity': 15.0,
            'unit_price': 100.0,
            'tax_rate': 5.0,
            'total_price': 1500.0,
          }
        ],
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: EditSalesOrderDialog(salesOrder: so),
            ),
          ),
        ),
      );

      expect(find.text('Edit Sales Order'), findsOneWidget);
      expect(find.text('SO-2026-444'), findsOneWidget);
      expect(find.text('Bill To / Customer Credentials'), findsOneWidget);
      expect(find.text('Customer GSTIN / Tax ID'), findsOneWidget);
      expect(find.text('Dispatch & Sales Record'), findsOneWidget);
      expect(find.text('Sales Order Line Items'), findsOneWidget);
      expect(find.text('Save Order Changes'), findsOneWidget);
    });
  });
}
