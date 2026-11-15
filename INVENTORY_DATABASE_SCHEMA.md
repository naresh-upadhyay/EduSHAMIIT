# EduSHAMIIT Enterprise Inventory Management System - Database Schema Documentation

## 1. Migration Overview

- **Migration File**: `EduSHAMIIT Database/edushamiit-db/migrations/430_enterprise_inventory_management_system.sql`
- **Execution Target**: PostgreSQL 15+ (`postgres` database)
- **Design Paradigm**: Multi-tenant relational schema partitioned logically by `school_id`, protected by Foreign Keys and Check Constraints, fully driven by Stored Procedures.

---

## 2. Table Catalog

### 2.1 `public.inventory_stores`
Represents physical or logical storage warehouses, departments, laboratories, and hostels within a school.
- `store_id` (UUID, PK): Unique store identifier.
- `school_id` (UUID, FK -> `schools.id`): Tenant isolation.
- `store_name` (VARCHAR): Human-readable name (e.g., "Main Store", "Science Laboratory").
- `store_code` (VARCHAR): Unique code within the school (e.g., "MAIN", "SCI_LAB").
- `building`, `floor`, `department` (VARCHAR): Granular spatial attributes.
- `manager_name`, `contact_details` (VARCHAR): Storekeeper custodian metadata.
- `is_active` (BOOLEAN): Soft active state.

### 2.2 `public.inventory_items`
Master catalog of inventory items, equipment, stationery, chemicals, and consumables.
- `item_id` (UUID, PK): Unique item identifier.
- `school_id` (UUID, FK -> `schools.id`): Tenant isolation.
- `sku` (VARCHAR): Unique Stock Keeping Unit across the school.
- `name` (VARCHAR): Full item title.
- `barcode` / `qr_code` (VARCHAR): Machine-readable codes for scanner hardware.
- `category_code` (VARCHAR, FK -> `lookup_values.lookup_code`): Universal lookup category.
- `uom_code` (VARCHAR, FK -> `lookup_values.lookup_code`): Unit of measurement.
- `purchase_price`, `selling_price` (NUMERIC(15,2)): Cost and sales rates.
- `min_stock_level`, `max_stock_level`, `reorder_quantity` (NUMERIC(12,2)): Reorder thresholds.
- `preferred_store_id` (UUID, FK -> `inventory_stores`): Default store for stock intake.
- `default_supplier_id` (UUID, FK -> `inventory_suppliers`): Primary vendor.
- `tracking_method` (VARCHAR): `NONE`, `BATCH`, `EXPIRY`, `SERIAL`.
- `stock_status` (VARCHAR, FK -> `lookup_values.lookup_code`): `IN_STOCK`, `LOW_STOCK`, `OUT_OF_STOCK`.

### 2.3 `public.inventory_stock_balances`
Maintains real-time aggregated inventory levels per store and per item.
- `balance_id` (UUID, PK): Unique balance identifier.
- `school_id` (UUID, FK -> `schools.id`): Tenant isolation.
- `item_id` (UUID, FK -> `inventory_items`): Associated item.
- `store_id` (UUID, FK -> `inventory_stores`): Associated store.
- `quantity_on_hand` (NUMERIC(12,2)): Physical stock present in store.
- `quantity_reserved` (NUMERIC(12,2)): Stock committed to unfulfilled Sales Orders.
- `quantity_available` (GENERATED ALWAYS AS `(quantity_on_hand - quantity_reserved)`): Readily usable stock.
- `quantity_damaged`, `quantity_expired` (NUMERIC(12,2)): Quarantined non-usable items.
- *Constraint*: `quantity_on_hand >= 0`, `quantity_reserved >= 0`. Unique `(store_id, item_id)`.

### 2.4 `public.inventory_stock_movements`
Immutable append-only ledger of every stock transaction in the institution.
- `movement_id` (UUID, PK): Unique transaction identifier.
- `school_id` (UUID, FK -> `schools.id`): Tenant isolation.
- `item_id` (UUID, FK -> `inventory_items`): Item moved.
- `store_id` (UUID, FK -> `inventory_stores`): Originating or destination store.
- `movement_type` (VARCHAR): `PURCHASE`, `SALE`, `ISSUE`, `RETURN`, `ADJUSTMENT`, `TRANSFER_IN`, `TRANSFER_OUT`.
- `quantity` (NUMERIC(12,2)): Signed quantity (+ for intake, - for issue/sale).
- `balance_before`, `balance_after` (NUMERIC(12,2)): Audit snapshot of store balance.
- `unit_cost`, `total_cost` (NUMERIC(15,2)): Financial valuation.
- `reference_type`, `reference_id` (VARCHAR): Link to PO, SO, or GRN.
- `department_name`, `recipient_name` (VARCHAR): Departmental recipient metadata.
- `created_by` (UUID, FK -> `profiles.id`): Authenticated user who performed the action.
- `created_at` (TIMESTAMPTZ): Immutable timestamp.

### 2.5 `public.inventory_suppliers`
Vendor and supplier directory.
- `supplier_id` (UUID, PK): Unique supplier identifier.
- `school_id` (UUID, FK -> `schools.id`): Tenant isolation.
- `supplier_code` (VARCHAR): Unique code (e.g., "SUP-001").
- `supplier_name` (VARCHAR): Corporate entity name.
- `contact_person`, `email`, `phone`, `gstin`, `payment_terms` (VARCHAR).

### 2.6 `public.inventory_purchase_orders` & `inventory_purchase_order_items`
Procurement orders to vendors.
- Statuses: `DRAFT`, `SUBMITTED`, `APPROVED`, `PARTIAL`, `DELIVERED`, `CANCELLED`.
- Line items record `ordered_quantity`, `received_quantity`, `unit_price`, and `tax_amount`.

### 2.7 `public.inventory_goods_receipts`
Goods Receipt Notes (GRN) capturing physical receipts against POs.

### 2.8 `public.inventory_sales_orders` & `inventory_sales_order_items`
Customer/student orders for uniforms, books, stationery, or lab kits.
- Automatically locks `quantity_reserved` upon creation.
- Transitions through `PENDING`, `PROCESSING`, `DELIVERED`, `CANCELLED`.

---

## 3. Stored Functions Catalog

| Function Name | Return Type | Primary Purpose |
|---|---|---|
| `fn_inventory_get_metadata` | `JSONB` | Returns all universal lookups, active stores, and suppliers in a single query |
| `fn_inventory_get_overview` | `JSONB` | Computes KPI counts, stock valuation, line chart and donut chart aggregations |
| `fn_inventory_get_items` | `TABLE(...)` | Paginated search of inventory items with store balances and status badges |
| `fn_inventory_upsert_item` | `JSONB` | Inserts or updates an item and provisions its initial stock balance row |
| `fn_inventory_delete_item` | `JSONB` | Soft-deletes item if no active balances or pending orders exist |
| `fn_inventory_receive_stock` | `JSONB` | Records stock receipt, increments balance, writes immutable ledger movement |
| `fn_inventory_issue_stock` | `JSONB` | Checks available stock, decrements balance, writes issue movement |
| `fn_inventory_adjust_stock` | `JSONB` | Increases or decreases balance based on reason code (damage, theft, audit) |
| `fn_inventory_transfer_stock` | `JSONB` | Atomically transfers stock between two stores; creates in/out movements |
| `fn_inventory_get_transactions` | `TABLE(...)` | Paginated transaction query with filter criteria |
| `fn_inventory_reverse_transaction` | `JSONB` | Issues compensatory reverse transaction without deleting historical records |
| `fn_inventory_get_purchase_orders`| `TABLE(...)` | Paginated PO query with delivery dates, item counts, and status badges |
| `fn_inventory_create_purchase_order`| `JSONB` | Creates PO header and multi-line items atomically |
| `fn_inventory_receive_goods_grn` | `JSONB` | Records GRN, updates line received counts, adjusts PO status, increments stock |
| `fn_inventory_get_sales_orders` | `TABLE(...)` | Paginated SO query with customer details, amounts, and statuses |
| `fn_inventory_create_sales_order`| `JSONB` | Validates stock, reserves quantity on hand, creates SO and lines |
| `fn_inventory_fulfill_sales_order`| `JSONB` | Dispatches stock, decrements on-hand and reserved, marks SO delivered |
