# EduSHAMIIT Enterprise Inventory Management System - API Documentation

## 1. Overview

The Inventory Management API is exposed via FastAPI and mounted under both:
- `/api/v1/inventory`
- `/api/inventory` (backward compatibility alias)

All requests require JWT Bearer authentication or valid session cookies, and are automatically scoped to the user's `school_id` tenant identifier.

Every business mutation and query delegates directly to a dedicated PostgreSQL stored procedure/function (`public.fn_inventory_*`).

---

## 2. Endpoints Summary

| Method | Endpoint | Description | Stored Function Invoked |
|---|---|---|---|
| `GET` | `/api/v1/inventory/metadata` | Fetch dynamic universal lookups, stores, and suppliers | `public.fn_inventory_get_metadata` |
| `GET` | `/api/v1/inventory/overview` | Fetch high-level KPIs, stock valuation, and chart series | `public.fn_inventory_get_overview` |
| `GET` | `/api/v1/inventory/items` | List inventory items with search, filters, pagination | `public.fn_inventory_get_items` |
| `POST` | `/api/v1/inventory/items` | Create new inventory item | `public.fn_inventory_upsert_item` |
| `PUT` | `/api/v1/inventory/items/{item_id}` | Update existing inventory item | `public.fn_inventory_upsert_item` |
| `DELETE` | `/api/v1/inventory/items/{item_id}` | Soft delete inventory item | `public.fn_inventory_delete_item` |
| `POST` | `/api/v1/inventory/stock/receive` | Direct intake or purchase stock receipt | `public.fn_inventory_receive_stock` |
| `POST` | `/api/v1/inventory/stock/issue` | Issue stock to department or recipient | `public.fn_inventory_issue_stock` |
| `POST` | `/api/v1/inventory/stock/adjust` | Record stock damage, loss, count correction | `public.fn_inventory_adjust_stock` |
| `POST` | `/api/v1/inventory/stock/transfer` | Transfer stock between stores atomically | `public.fn_inventory_transfer_stock` |
| `GET` | `/api/v1/inventory/transactions` | Query immutable stock movement ledger | `public.fn_inventory_get_transactions` |
| `POST` | `/api/v1/inventory/transactions/{movement_id}/reverse` | Compensatory transaction reversal | `public.fn_inventory_reverse_transaction` |
| `GET` | `/api/v1/inventory/purchase-orders` | Query purchase orders list and metrics | `public.fn_inventory_get_purchase_orders` |
| `POST` | `/api/v1/inventory/purchase-orders` | Create multi-line purchase order | `public.fn_inventory_create_purchase_order` |
| `POST` | `/api/v1/inventory/purchase-orders/receive` | Process GRN and receive PO goods | `public.fn_inventory_receive_goods_grn` |
| `GET` | `/api/v1/inventory/sales-orders` | Query sales orders list and metrics | `public.fn_inventory_get_sales_orders` |
| `POST` | `/api/v1/inventory/sales-orders` | Create sales order and reserve stock | `public.fn_inventory_create_sales_order` |
| `POST` | `/api/v1/inventory/sales-orders/{so_id}/fulfill` | Fulfill/deliver or cancel sales order | `public.fn_inventory_fulfill_sales_order` |
| `GET` | `/api/v1/inventory/items/{item_id}/details` | 360-degree item details for side drawer | Direct join on stores, balances, movements |
| `GET` | `/api/v1/inventory/export/{entity}` | Stream CSV file for items, transactions, PO, SO | Direct SQL cursor stream |

---

## 3. Detailed Request & Response Schemas

### 3.1 Metadata & Lookups
- **Endpoint**: `GET /api/v1/inventory/metadata`
- **Response**:
```json
{
  "success": true,
  "data": {
    "categories": [
      {"lookup_code": "STATIONERY", "lookup_name": "Stationery"},
      {"lookup_code": "LAB_EQUIPMENT", "lookup_name": "Lab Equipment"}
    ],
    "uom": [
      {"lookup_code": "PCS", "lookup_name": "Pieces (Pcs)"},
      {"lookup_code": "BOX", "lookup_name": "Boxes (Box)"}
    ],
    "item_statuses": [
      {"lookup_code": "IN_STOCK", "lookup_name": "In Stock"},
      {"lookup_code": "LOW_STOCK", "lookup_name": "Low Stock"}
    ],
    "transaction_types": [
      {"lookup_code": "PURCHASE", "lookup_name": "Purchase"},
      {"lookup_code": "ISSUE", "lookup_name": "Stock Issue"}
    ],
    "stores": [
      {"store_id": "...", "store_name": "Main Store", "store_code": "MAIN"}
    ],
    "suppliers": [
      {"supplier_id": "...", "supplier_name": "ABC Enterprises", "supplier_code": "SUP-001"}
    ]
  }
}
```

### 3.2 Create Inventory Item
- **Endpoint**: `POST /api/v1/inventory/items`
- **Request**:
```json
{
  "name": "Classmate Notebook 200 Pages",
  "sku": "NB-CLS-200",
  "barcode": "8901234567890",
  "category_code": "STATIONERY",
  "uom_code": "PCS",
  "stock_status": "IN_STOCK",
  "preferred_store_id": "d0e1a498-4444-4444-4444-000000000001",
  "purchase_price": 45.0,
  "selling_price": 55.0,
  "min_stock_level": 20.0,
  "max_stock_level": 500.0,
  "reorder_quantity": 50.0,
  "tracking_method": "NONE"
}
```
- **Response**:
```json
{
  "success": true,
  "data": {
    "item_id": "a1b2c3d4-...",
    "sku": "NB-CLS-200",
    "name": "Classmate Notebook 200 Pages",
    "message": "Item saved successfully"
  }
}
```

### 3.3 Receive Stock
- **Endpoint**: `POST /api/v1/inventory/stock/receive`
- **Request**:
```json
{
  "item_id": "a1b2c3d4-...",
  "store_id": "d0e1a498-...",
  "quantity": 100.0,
  "unit_cost": 45.0,
  "supplier_id": "...",
  "reference_number": "INV-2026-908",
  "batch_number": "BATCH-2026-04",
  "expiry_date": "2027-12-31",
  "notes": "Annual stationery restock"
}
```
- **Response**:
```json
{
  "success": true,
  "data": {
    "movement_id": "...",
    "new_quantity_on_hand": 350.0,
    "message": "Stock received successfully"
  }
}
```

### 3.4 Issue Stock
- **Endpoint**: `POST /api/v1/inventory/stock/issue`
- **Request**:
```json
{
  "item_id": "a1b2c3d4-...",
  "store_id": "d0e1a498-...",
  "quantity": 25.0,
  "department_name": "Mathematics Dept",
  "recipient_name": "John Doe",
  "purpose": "Classroom teaching aids",
  "notes": "Issued for Grade 10"
}
```
- **Response**:
```json
{
  "success": true,
  "data": {
    "movement_id": "...",
    "new_quantity_on_hand": 325.0,
    "message": "Stock issued successfully"
  }
}
```

---

## 4. Error Handling Conventions

All endpoints adhere to standard HTTP status codes:
- `200 OK`: Successful retrieval or mutation.
- `400 Bad Request`: Validation failure or business rule violation (e.g., attempting to issue stock greater than available on hand).
- `401 Unauthorized`: Missing, expired, or invalid bearer token.
- `403 Forbidden`: User role lacks permission for the given inventory operation.
- `404 Not Found`: Item, PO, SO, or Store does not exist for the current tenant.
- `500 Internal Server Error`: Unhandled database exception or connectivity failure.
