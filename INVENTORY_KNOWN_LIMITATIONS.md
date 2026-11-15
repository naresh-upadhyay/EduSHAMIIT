# EduSHAMIIT Enterprise Inventory Management System - Known Limitations & Deployment Guidelines

## 1. Hardware Scanner Integration
- **Barcode & QR Scanning**: The data models and UI forms are designed with `barcode` and `qr_code` fields. In web browsers, USB barcode scanners acting as HID keyboard wedges function out-of-the-box (by typing the scanned code into the active input and hitting Return).
- **Mobile Camera Scanning**: On mobile or tablet platforms, future iterations can bind the `mobile_scanner` package to the camera icon in `InventoryHeaderBar` and the dialog inputs to directly scan serial numbers and barcodes.

## 2. Multi-Store Automated Replenishment
- Currently, low-stock thresholds generate alert cards on the dashboard and trigger in-app warnings.
- Automated creation of Draft Purchase Orders when stock reaches the `reorder_quantity` can be scheduled via a background cron or `pg_cron` job calling `fn_inventory_create_purchase_order`.

## 3. Financial Ledger Integration
- Current stock valuation records `unit_cost * quantity` on every movement and stores FIFO/Weighted Average costs in `inventory_items.average_cost`.
- If an institute requires double-entry General Ledger postings in the Finance module upon Goods Receipt Note generation (Debit: Inventory Asset, Credit: Accounts Payable), a database trigger or FastAPI event listener can be registered against `inventory_goods_receipts`.

## 4. Audit & Data Retention
- The `inventory_stock_movements` table is strictly append-only. No records are ever deleted.
- For institutions generating tens of thousands of movements monthly, table partitioning by `school_id` and `created_at` (range partition per quarter/year) is recommended after 12 months in production.

## 5. Production Deployment Checklist
1. Ensure `migrations/430_enterprise_inventory_management_system.sql` has been executed on the production PostgreSQL cluster.
2. Confirm universal lookup values are active in `public.lookup_values`.
3. Verify that institute user roles have been granted permissions for:
   - `inventory:view`
   - `inventory:item:create` / `inventory:item:update` / `inventory:item:delete`
   - `inventory:stock:receive` / `inventory:stock:issue` / `inventory:stock:adjust` / `inventory:stock:transfer`
   - `inventory:po:create` / `inventory:po:receive`
   - `inventory:so:create` / `inventory:so:deliver`
   - `inventory:export`
