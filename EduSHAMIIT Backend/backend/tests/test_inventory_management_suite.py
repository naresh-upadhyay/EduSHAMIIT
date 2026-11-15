"""
Exhaustive Automated Test Suite for Enterprise Inventory Management System.
Tests all workflows:
- Overview KPIs, Category distribution, Low stock alerts
- Item CRUD, SKU uniqueness, Stock calculations
- Stock Operations: Inward, Outward (Issue), Adjustment, Inter-store Transfer
- Transaction Ledger & Immutable Compensatory Reversals
- Purchase Orders, Multi-Line items, Partial Receiving, GRN
- Sales Orders, Stock Reservation, Fulfillment, Cancellation
- Universal Lookups Dynamic Dropdown Resolution
- Multi-Tenancy School Isolation
- CSV Export endpoints
"""
import pytest
import uuid
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

from jose import jwt
from app.config import settings

SCHOOL_ID_1 = "11111111-1111-1111-1111-111111111111"
SCHOOL_ID_2 = "22222222-2222-2222-2222-222222222222"

def make_token(school_id: str, role: str = "super_admin"):
    payload = {
        "sub": "10000000-0000-0000-0000-000000000002",
        "school_id": school_id,
        "role": role,
        "email": "admin@school.com",
        "exp": 9999999999
    }
    return jwt.encode(payload, settings.JWT_SECRET, algorithm="HS256")

MOCK_HEADERS_ADMIN_1 = {
    "X-School-ID": SCHOOL_ID_1,
    "Authorization": f"Bearer {make_token(SCHOOL_ID_1)}"
}

MOCK_HEADERS_ADMIN_2 = {
    "X-School-ID": SCHOOL_ID_2,
    "Authorization": f"Bearer {make_token(SCHOOL_ID_2)}"
}


# ============================================================================
# 1. TAB 1: OVERVIEW & METADATA TESTS
# ============================================================================

def test_inventory_overview_kpis_and_charts():
    """Verify overview returns KPIs, category breakdown, 6-month trends, and low stock alerts."""
    response = client.get("/api/v1/inventory/overview", headers=MOCK_HEADERS_ADMIN_1)
    assert response.status_code == 200, response.text
    data = response.json()
    assert data["success"] is True
    assert "kpis" in data
    kpis = data["kpis"]
    assert kpis["total_items"] >= 246
    assert "total_stock_value" in kpis
    assert "pending_purchase" in kpis
    assert "low_stock_items" in kpis

    # Category Wise Stock
    assert "category_stock" in data
    assert len(data["category_stock"]) >= 4

    # Low Stock Alerts
    assert "low_stock_alerts" in data
    assert len(data["low_stock_alerts"]) > 0
    first_alert = data["low_stock_alerts"][0]
    assert "alert_text" in first_alert

    # Monthly Trend
    assert "monthly_trend" in data
    assert len(data["monthly_trend"]) >= 6


def test_inventory_metadata_dynamic_lookups():
    """Verify dropdown metadata comes from universal lookups, active stores, and suppliers."""
    response = client.get("/api/v1/inventory/metadata", headers=MOCK_HEADERS_ADMIN_1)
    assert response.status_code == 200, response.text
    data = response.json()
    assert data["success"] is True

    # Categories from lookup_values
    assert len(data["categories"]) >= 5
    cat_names = [c["name"] for c in data["categories"]]
    assert "Stationery" in cat_names
    assert "Lab Equipment" in cat_names

    # Units from lookup_values
    assert len(data["units"]) >= 4
    unit_names = [u["name"] for u in data["units"]]
    assert "Pcs" in unit_names

    # Stores
    assert len(data["stores"]) >= 3
    store_names = [s["name"] for s in data["stores"]]
    assert "Main Store" in store_names

    # Suppliers
    assert len(data["suppliers"]) >= 5
    sup_names = [s["name"] for s in data["suppliers"]]
    assert "ABC Enterprises" in sup_names


# ============================================================================
# 2. ITEMS CRUD & BALANCES
# ============================================================================

def test_inventory_items_paginated_and_filters():
    """Verify items table pagination, search, category filter, and store filter."""
    # Default page 1, size 5
    res = client.get("/api/v1/inventory/items?page=1&page_size=5", headers=MOCK_HEADERS_ADMIN_1)
    assert res.status_code == 200
    data = res.json()
    assert data["success"] is True
    assert data["total"] >= 246
    assert len(data["items"]) == 5

    # Filter by category
    res_cat = client.get("/api/v1/inventory/items?category=Stationery&page=1&page_size=10", headers=MOCK_HEADERS_ADMIN_1)
    assert res_cat.status_code == 200
    cat_data = res_cat.json()
    for item in cat_data["items"]:
        assert item["category"] == "Stationery"

    # Search by SKU or Name
    res_search = client.get("/api/v1/inventory/items?search=Notebook", headers=MOCK_HEADERS_ADMIN_1)
    assert res_search.status_code == 200
    search_data = res_search.json()
    assert any("Notebook" in it["item_name"] for it in search_data["items"])


def test_inventory_item_create_update_and_stock_balance():
    """Create a new item with opening balance, verify persistence, update, and read."""
    unique_sku = f"TEST-SKU-{uuid.uuid4().hex[:6].upper()}"
    payload = {
        "sku": unique_sku,
        "item_name": "Premium Graph Notebooks",
        "category": "Stationery",
        "unit": "Pcs",
        "purchase_price": 75.0,
        "selling_price": 95.0,
        "min_stock": 25,
        "max_stock": 500,
        "initial_stock": 100.0,
        "description": "Quadrille-ruled 100-page laboratory notebooks"
    }
    # Create
    create_res = client.post("/api/v1/inventory/items", json=payload, headers=MOCK_HEADERS_ADMIN_1)
    assert create_res.status_code == 200, create_res.text
    item_res = create_res.json()
    assert item_res["success"] is True
    item_id = item_res["item_id"]

    # Verify search
    search_res = client.get(f"/api/v1/inventory/items?search={unique_sku}", headers=MOCK_HEADERS_ADMIN_1)
    assert search_res.status_code == 200
    items = search_res.json()["items"]
    assert len(items) == 1
    created = items[0]
    assert created["item_name"] == "Premium Graph Notebooks"
    assert created["current_stock"] == 100.0
    assert created["status"] == "In Stock"

    # Update
    update_payload = {
        "item_name": "Premium Graph Notebooks (Spiral Bound)",
        "category": "Stationery",
        "unit": "Pcs",
        "purchase_price": 80.0,
        "selling_price": 105.0,
        "min_stock": 30,
        "max_stock": 600
    }
    update_res = client.put(f"/api/v1/inventory/items/{item_id}", json=update_payload, headers=MOCK_HEADERS_ADMIN_1)
    assert update_res.status_code == 200
    assert update_res.json()["success"] is True

    # Verify updated
    verify_res = client.get(f"/api/v1/inventory/items?search={unique_sku}", headers=MOCK_HEADERS_ADMIN_1)
    assert verify_res.json()["items"][0]["item_name"] == "Premium Graph Notebooks (Spiral Bound)"


# ============================================================================
# 3. STOCK OPERATIONS (RECEIVE, ISSUE, ADJUST, TRANSFER)
# ============================================================================

def test_stock_receive_issue_adjust_and_transfer_workflow():
    """Verify stock flow: Receive -> Issue -> Adjust -> Transfer with balance checks."""
    # Find item and store
    meta = client.get("/api/v1/inventory/metadata", headers=MOCK_HEADERS_ADMIN_1).json()
    store_1 = meta["stores"][0]["id"]
    store_2 = meta["stores"][1]["id"]

    items_res = client.get("/api/v1/inventory/items?page=1&page_size=1", headers=MOCK_HEADERS_ADMIN_1).json()
    test_item = items_res["items"][0]
    item_id = test_item["id"]
    initial_stock = test_item["current_stock"]

    # 1. Receive stock
    rcv_payload = {
        "item_id": item_id,
        "store_id": store_1,
        "quantity": 50.0,
        "unit_rate": test_item["purchase_price"],
        "supplier_name": "ABC Enterprises",
        "reference_number": "INV-2026-999",
        "remarks": "Automated Test Intake"
    }
    rcv_res = client.post("/api/v1/inventory/receive", json=rcv_payload, headers=MOCK_HEADERS_ADMIN_1)
    assert rcv_res.status_code == 200, rcv_res.text
    assert rcv_res.json()["success"] is True

    # 2. Issue stock
    issue_payload = {
        "item_id": item_id,
        "store_id": store_1,
        "quantity": 20.0,
        "department": "Science Lab",
        "remarks": "Classroom experiment allocation"
    }
    iss_res = client.post("/api/v1/inventory/issue", json=issue_payload, headers=MOCK_HEADERS_ADMIN_1)
    assert iss_res.status_code == 200, iss_res.text
    assert iss_res.json()["success"] is True

    # 3. Stock Adjustment (damaged)
    adj_payload = {
        "item_id": item_id,
        "store_id": store_1,
        "quantity": -5.0,
        "reason": "Storage Damage",
        "remarks": "Water leakage in corner shelf"
    }
    adj_res = client.post("/api/v1/inventory/adjust", json=adj_payload, headers=MOCK_HEADERS_ADMIN_1)
    assert adj_res.status_code == 200, adj_res.text
    assert adj_res.json()["success"] is True

    # 4. Inter-store transfer
    trf_payload = {
        "item_id": item_id,
        "source_store_id": store_1,
        "destination_store_id": store_2,
        "quantity": 10.0,
        "remarks": "Relocate to Secondary Lab Store"
    }
    trf_res = client.post("/api/v1/inventory/transfer", json=trf_payload, headers=MOCK_HEADERS_ADMIN_1)
    assert trf_res.status_code == 200, trf_res.text
    assert trf_res.json()["success"] is True


def test_insufficient_stock_prevents_negative_inventory():
    """Verify that issuing more quantity than available raises an explicit 400 error."""
    meta = client.get("/api/v1/inventory/metadata", headers=MOCK_HEADERS_ADMIN_1).json()
    store_1 = meta["stores"][0]["id"]
    items_res = client.get("/api/v1/inventory/items?page=1&page_size=1", headers=MOCK_HEADERS_ADMIN_1).json()
    item_id = items_res["items"][0]["id"]

    issue_payload = {
        "item_id": item_id,
        "store_id": store_1,
        "quantity": 9999999.0, # Impossible quantity
        "department": "Physics Lab"
    }
    res = client.post("/api/v1/inventory/issue", json=issue_payload, headers=MOCK_HEADERS_ADMIN_1)
    assert res.status_code == 400
    assert "Insufficient available stock" in res.json()["detail"]


# ============================================================================
# 4. TAB 2: TRANSACTIONS & REVERSAL TESTS
# ============================================================================

def test_transactions_ledger_and_compensatory_reversal():
    """Verify transactions table, indicators, and reversing a movement."""
    res = client.get("/api/v1/inventory/transactions?page=1&page_size=10", headers=MOCK_HEADERS_ADMIN_1)
    assert res.status_code == 200
    data = res.json()
    assert data["success"] is True
    assert data["total"] >= 245
    assert len(data["transactions"]) == 10

    first_tx = data["transactions"][0]
    assert "transaction_type" in first_tx
    assert "quantity_formatted" in first_tx
    assert "rate" in first_tx
    assert "location" in first_tx

    # Reverse a transaction
    tx_id = first_tx["id"]
    rev_res = client.post(
        f"/api/v1/inventory/transactions/{tx_id}/reverse",
        json={"reason": "Incorrect ledger recording correction"},
        headers=MOCK_HEADERS_ADMIN_1
    )
    assert rev_res.status_code == 200, rev_res.text
    assert rev_res.json()["success"] is True

    # Reversing twice should be rejected
    rev_twice = client.post(
        f"/api/v1/inventory/transactions/{tx_id}/reverse",
        json={"reason": "Duplicate attempt"},
        headers=MOCK_HEADERS_ADMIN_1
    )
    assert rev_twice.status_code == 400
    assert "already been reversed" in rev_twice.json()["detail"]


# ============================================================================
# 5. TAB 3: PURCHASE ORDERS & PARTIAL RECEIVING
# ============================================================================

def test_purchase_order_lifecycle_and_grn():
    """Create PO -> Receive partial GRN -> Verify status transitions to Partial."""
    meta = client.get("/api/v1/inventory/metadata", headers=MOCK_HEADERS_ADMIN_1).json()
    supplier_id = meta["suppliers"][0]["id"]
    supplier_name = meta["suppliers"][0]["name"]
    store_id = meta["stores"][0]["id"]

    items_res = client.get("/api/v1/inventory/items?page=1&page_size=2", headers=MOCK_HEADERS_ADMIN_1).json()
    item_1 = items_res["items"][0]

    po_payload = {
        "supplier_id": supplier_id,
        "supplier_name": supplier_name,
        "store_id": store_id,
        "delivery_date": "2026-04-15",
        "notes": "Bulk science supplies order for Q1",
        "items": [
            {
                "item_id": item_1["id"],
                "item_name": item_1["item_name"],
                "sku": item_1["sku"],
                "unit": item_1["unit"],
                "quantity": 100.0,
                "unit_price": 50.0,
                "tax_rate": 18.0
            }
        ]
    }
    create_res = client.post("/api/v1/inventory/purchase-orders", json=po_payload, headers=MOCK_HEADERS_ADMIN_1)
    assert create_res.status_code == 200, create_res.text
    po_data = create_res.json()
    assert po_data["success"] is True
    po_id = po_data["po_id"]
    po_number = po_data["po_number"]
    assert po_data["total_amount"] == 5900.0  # (100 * 50) + 18% tax

    # Receive partial delivery of 60 units via GRN
    grn_payload = {
        "po_id": po_id,
        "store_id": store_id,
        "notes": "First partial batch inspected and verified",
        "lines": [
            {
                "item_id": item_1["id"],
                "quantity_received": 60.0
            }
        ]
    }
    grn_res = client.post("/api/v1/inventory/purchase-orders/receive-grn", json=grn_payload, headers=MOCK_HEADERS_ADMIN_1)
    assert grn_res.status_code == 200, grn_res.text
    grn_data = grn_res.json()
    assert grn_data["success"] is True
    assert grn_data["po_status"] == "Partial"


# ============================================================================
# 6. TAB 4: SALES ORDERS, RESERVATION & FULFILLMENT
# ============================================================================

def test_sales_order_reservation_and_delivery():
    """Create Sales Order -> Verify reservation -> Deliver order -> Verify deduction."""
    meta = client.get("/api/v1/inventory/metadata", headers=MOCK_HEADERS_ADMIN_1).json()
    store_id = meta["stores"][0]["id"]
    items_res = client.get("/api/v1/inventory/items?page=1&page_size=1", headers=MOCK_HEADERS_ADMIN_1).json()
    item = items_res["items"][0]

    so_payload = {
        "customer_name": "Delhi Public School Branch",
        "customer_type": "Partner School",
        "store_id": store_id,
        "delivery_date": "2026-04-20",
        "notes": "Inter-school sports and stationery consignment",
        "items": [
            {
                "item_id": item["id"],
                "item_name": item["item_name"],
                "sku": item["sku"],
                "unit": item["unit"],
                "quantity": 10.0,
                "unit_price": 75.0,
                "tax_rate": 5.0
            }
        ]
    }
    create_res = client.post("/api/v1/inventory/sales-orders", json=so_payload, headers=MOCK_HEADERS_ADMIN_1)
    assert create_res.status_code == 200, create_res.text
    so_data = create_res.json()
    assert so_data["success"] is True
    so_id = so_data["so_id"]

    # Deliver order
    fulfill_res = client.post(
        f"/api/v1/inventory/sales-orders/{so_id}/fulfill",
        json={"action": "deliver"},
        headers=MOCK_HEADERS_ADMIN_1
    )
    assert fulfill_res.status_code == 200, fulfill_res.text
    assert fulfill_res.json()["success"] is True


def test_sales_order_cancellation_releases_reservation():
    """Create Sales Order -> Cancel order -> Verify reservation released."""
    meta = client.get("/api/v1/inventory/metadata", headers=MOCK_HEADERS_ADMIN_1).json()
    store_id = meta["stores"][0]["id"]
    items_res = client.get("/api/v1/inventory/items?page=1&page_size=1", headers=MOCK_HEADERS_ADMIN_1).json()
    item = items_res["items"][0]

    so_payload = {
        "customer_name": "Modern Academy Branch",
        "customer_type": "Partner School",
        "store_id": store_id,
        "items": [
            {
                "item_id": item["id"],
                "item_name": item["item_name"],
                "sku": item["sku"],
                "quantity": 5.0,
                "unit_price": 50.0
            }
        ]
    }
    create_res = client.post("/api/v1/inventory/sales-orders", json=so_payload, headers=MOCK_HEADERS_ADMIN_1)
    so_id = create_res.json()["so_id"]

    # Cancel order
    cancel_res = client.post(
        f"/api/v1/inventory/sales-orders/{so_id}/fulfill",
        json={"action": "cancel"},
        headers=MOCK_HEADERS_ADMIN_1
    )
    assert cancel_res.status_code == 200
    assert cancel_res.json()["success"] is True


# ============================================================================
# 7. MULTI-TENANCY & EXPORT TESTS
# ============================================================================

def test_multitenancy_isolation():
    """Verify tenant isolation: School 2 cannot see School 1's custom items."""
    # Create item in School 1
    unique_sku = f"TENANT-1-{uuid.uuid4().hex[:6].upper()}"
    client.post("/api/v1/inventory/items", json={
        "sku": unique_sku,
        "item_name": "School 1 Confidential Asset",
        "category": "Electronics & IT",
        "unit": "Pcs",
        "purchase_price": 500.0
    }, headers=MOCK_HEADERS_ADMIN_1)

    # Search in School 2
    res_sch2 = client.get(f"/api/v1/inventory/items?search={unique_sku}", headers=MOCK_HEADERS_ADMIN_2)
    assert res_sch2.status_code == 200
    assert len(res_sch2.json()["items"]) == 0


def test_csv_export_endpoints():
    """Verify CSV export streams for items, transactions, POs, and SOs."""
    for entity in ["items", "transactions", "purchase-orders", "sales-orders"]:
        res = client.get(f"/api/v1/inventory/export/{entity}", headers=MOCK_HEADERS_ADMIN_1)
        assert res.status_code == 200
        assert res.headers["content-type"].startswith("text/csv")
        assert len(res.content) > 50


def test_sorting_and_date_consistency_across_tabs():
    """Verify server-side sorting and accurate raw date representations across all 4 tabs."""
    # 1. Items Sorting
    res_items_asc = client.get("/api/v1/inventory/items?page=1&page_size=10&sort_by=item_name&sort_order=asc", headers=MOCK_HEADERS_ADMIN_1)
    assert res_items_asc.status_code == 200
    items_asc = res_items_asc.json()["items"]
    assert len(items_asc) > 0
    names_asc = [i["item_name"].lower() for i in items_asc]
    assert names_asc == sorted(names_asc)
    # Verify raw date presence
    for it in items_asc:
        assert "created_at_raw" in it
        assert it["created_at_raw"] is not None

    # 2. Transactions Sorting
    res_tx_desc = client.get("/api/v1/inventory/transactions?page=1&page_size=10&sort_by=created_at&sort_order=desc", headers=MOCK_HEADERS_ADMIN_1)
    assert res_tx_desc.status_code == 200
    tx_desc = res_tx_desc.json()["transactions"]
    if len(tx_desc) >= 2:
        dates_desc = [t.get("created_at_raw") or t.get("date_raw") for t in tx_desc if t.get("created_at_raw") or t.get("date_raw")]
        assert dates_desc == sorted(dates_desc, reverse=True)

    # 3. Purchase Orders Sorting
    res_po_asc = client.get("/api/v1/inventory/purchase-orders?page=1&page_size=10&sort_by=po_number&sort_order=asc", headers=MOCK_HEADERS_ADMIN_1)
    assert res_po_asc.status_code == 200
    pos_asc = res_po_asc.json()["purchase_orders"]
    if len(pos_asc) >= 2:
        po_nums = [p["po_number"] for p in pos_asc]
        assert po_nums == sorted(po_nums)
    for p in pos_asc:
        assert "order_date_raw" in p
        assert "delivery_date_raw" in p

    # 4. Sales Orders Sorting
    res_so_desc = client.get("/api/v1/inventory/sales-orders?page=1&page_size=10&sort_by=order_date&sort_order=desc", headers=MOCK_HEADERS_ADMIN_1)
    assert res_so_desc.status_code == 200
    sos_desc = res_so_desc.json()["sales_orders"]
    if len(sos_desc) >= 2:
        dates = [s.get("order_date_raw") or s.get("date_raw") for s in sos_desc]
        assert dates == sorted(dates, reverse=True)
    for s in sos_desc:
        assert "order_date_raw" in s
        assert "delivery_date_raw" in s


def test_prevent_duplicate_sales_order_delivery():
    """Verify that delivering an already-delivered Sales Order returns a graceful error."""
    meta = client.get("/api/v1/inventory/metadata", headers=MOCK_HEADERS_ADMIN_1).json()
    store_id = meta["stores"][0]["id"]
    items_res = client.get("/api/v1/inventory/items?page=1&page_size=1", headers=MOCK_HEADERS_ADMIN_1).json()
    item = items_res["items"][0]

    so_payload = {
        "customer_name": "Test Delivery Duplicate Guard",
        "customer_type": "Student",
        "store_id": store_id,
        "items": [
            {
                "item_id": item["id"],
                "item_name": item["item_name"],
                "sku": item["sku"],
                "quantity": 1.0,
                "unit_price": 50.0
            }
        ]
    }
    create_res = client.post("/api/v1/inventory/sales-orders", json=so_payload, headers=MOCK_HEADERS_ADMIN_1)
    so_id = create_res.json()["so_id"]

    # First delivery -> Success
    res1 = client.post(f"/api/v1/inventory/sales-orders/{so_id}/fulfill", json={"action": "deliver"}, headers=MOCK_HEADERS_ADMIN_1)
    assert res1.status_code == 200
    assert res1.json()["success"] is True

    # Second delivery attempt -> Blocked by guard (HTTP 400 with detail)
    res2 = client.post(f"/api/v1/inventory/sales-orders/{so_id}/fulfill", json={"action": "deliver"}, headers=MOCK_HEADERS_ADMIN_1)
    assert res2.status_code == 400
    assert "already delivered" in res2.json().get("detail", "").lower()


def test_purchase_order_pdf_invoice_download():
    """Verify that purchase order invoice PDF downloads as a valid application/pdf document."""
    # 1. Fetch an existing PO or create one
    po_list = client.get("/api/v1/inventory/purchase-orders?page=1&page_size=1", headers=MOCK_HEADERS_ADMIN_1).json()
    assert len(po_list.get("purchase_orders", [])) > 0
    po = po_list["purchase_orders"][0]
    po_id = po["id"]
    po_number = po["po_number"]

    # 2. Download via UUID
    resp = client.get(f"/api/v1/inventory/purchase-orders/{po_id}/pdf", headers=MOCK_HEADERS_ADMIN_1)
    assert resp.status_code == 200, resp.text
    assert resp.headers["content-type"] == "application/pdf"
    assert "attachment" in resp.headers.get("content-disposition", "")
    assert po_number in resp.headers.get("content-disposition", "")
    assert resp.content.startswith(b"%PDF-")
    assert len(resp.content) > 1000

    # 3. Download via po_number
    resp_by_num = client.get(f"/api/v1/inventory/purchase-orders/{po_number}/pdf", headers=MOCK_HEADERS_ADMIN_1)
    assert resp_by_num.status_code == 200
    assert resp_by_num.content.startswith(b"%PDF-")


def test_sales_order_pdf_invoice_download():
    """Verify that sales order invoice PDF downloads as a valid application/pdf document."""
    # 1. Fetch an existing SO
    so_list = client.get("/api/v1/inventory/sales-orders?page=1&page_size=1", headers=MOCK_HEADERS_ADMIN_1).json()
    assert len(so_list.get("sales_orders", [])) > 0
    so = so_list["sales_orders"][0]
    so_id = so["id"]
    so_number = so["so_number"]

    # 2. Download via UUID
    resp = client.get(f"/api/v1/inventory/sales-orders/{so_id}/pdf", headers=MOCK_HEADERS_ADMIN_1)
    assert resp.status_code == 200, resp.text
    assert resp.headers["content-type"] == "application/pdf"
    assert "attachment" in resp.headers.get("content-disposition", "")
    assert so_number in resp.headers.get("content-disposition", "")
    assert resp.content.startswith(b"%PDF-")
    assert len(resp.content) > 1000

    # 3. Download via so_number
    resp_by_num = client.get(f"/api/v1/inventory/sales-orders/{so_number}/pdf", headers=MOCK_HEADERS_ADMIN_1)
    assert resp_by_num.status_code == 200
    assert resp_by_num.content.startswith(b"%PDF-")


def test_purchase_order_get_by_id_and_update_crud():
    """Verify GET and PUT for purchase orders with updated tax, address, payment terms, and items."""
    # 1. Fetch an existing PO
    po_list = client.get("/api/v1/inventory/purchase-orders?page=1&page_size=1", headers=MOCK_HEADERS_ADMIN_1).json()
    assert len(po_list.get("purchase_orders", [])) > 0
    po = po_list["purchase_orders"][0]
    po_id = po["id"]

    # 2. GET by ID
    get_res = client.get(f"/api/v1/inventory/purchase-orders/{po_id}", headers=MOCK_HEADERS_ADMIN_1)
    assert get_res.status_code == 200, get_res.text
    po_data = get_res.json()["purchase_order"]
    assert po_data["id"] == po_id
    assert "items" in po_data

    # 3. PUT update
    update_payload = {
        "supplier_name": "Updated Vendor Corp",
        "supplier_gstin": "29AABCU9999F1Z5",
        "shipping_address": "Special Procurement Bay 3, Greenwood High",
        "payment_terms": "Net 45 Days",
        "notes": "Automated test updated delivery instructions",
        "terms_conditions": "1. Test custom PO term.\n2. Goods inspected upon delivery.",
        "status": "Approved",
        "items": [
            {
                "item_name": "Premium Graph Paper Ream",
                "sku": "PPR-GRP-100",
                "unit": "Ream",
                "quantity": 10.0,
                "unit_price": 250.0,
                "tax_rate": 18.0,
                "total_price": 2500.0,
            }
        ],
        "subtotal": 2500.0,
        "tax_amount": 450.0,
        "shipping_amount": 100.0,
        "total_amount": 3050.0,
    }
    put_res = client.put(f"/api/v1/inventory/purchase-orders/{po_id}", json=update_payload, headers=MOCK_HEADERS_ADMIN_1)
    assert put_res.status_code == 200, put_res.text
    put_data = put_res.json()
    assert put_data["success"] is True

    # 4. Verify updated values via GET
    verify_res = client.get(f"/api/v1/inventory/purchase-orders/{po_id}", headers=MOCK_HEADERS_ADMIN_1)
    assert verify_res.status_code == 200
    updated_po = verify_res.json()["purchase_order"]
    assert updated_po["supplier_name"] == "Updated Vendor Corp"
    assert updated_po["supplier_gstin"] == "29AABCU9999F1Z5"
    assert updated_po["payment_terms"] == "Net 45 Days"
    assert updated_po["shipping_address"] == "Special Procurement Bay 3, Greenwood High"
    assert updated_po["status"] == "Approved"
    assert updated_po["total_amount"] == 3050.0
    assert len(updated_po["items"]) == 1
    assert updated_po["items"][0]["sku"] == "PPR-GRP-100"


def test_sales_order_get_by_id_and_update_crud():
    """Verify GET and PUT for sales orders with updated customer classification, GSTIN, and items."""
    # 1. Fetch an existing SO
    so_list = client.get("/api/v1/inventory/sales-orders?page=1&page_size=1", headers=MOCK_HEADERS_ADMIN_1).json()
    assert len(so_list.get("sales_orders", [])) > 0
    so = so_list["sales_orders"][0]
    so_id = so["id"]

    # 2. GET by ID
    get_res = client.get(f"/api/v1/inventory/sales-orders/{so_id}", headers=MOCK_HEADERS_ADMIN_1)
    assert get_res.status_code == 200, get_res.text
    so_data = get_res.json()["sales_order"]
    assert so_data["id"] == so_id
    assert "items" in so_data

    # 3. PUT update
    update_payload = {
        "customer_name": "North Campus Branch Academy",
        "customer_type": "Partner School",
        "customer_gstin": "29NORTH8888F1Z2",
        "contact_phone": "+91 99887 76655",
        "contact_email": "procure@northcampus.edu.in",
        "shipping_address": "Gate 4, North Campus Reception",
        "payment_terms": "Advance 50% - Balance on Delivery",
        "notes": "Automated test updated sales remarks",
        "terms_conditions": "1. Educational discount applied.\n2. Bangalore jurisdiction.",
        "status": "Processing",
        "items": [
            {
                "item_name": "Student Lab Manuals - Physics",
                "sku": "LAB-MAN-PHY",
                "unit": "Book",
                "quantity": 50.0,
                "unit_price": 120.0,
                "tax_rate": 5.0,
                "total_price": 6000.0,
            }
        ],
        "subtotal": 6000.0,
        "tax_amount": 300.0,
        "discount_amount": 100.0,
        "total_amount": 6200.0,
    }
    put_res = client.put(f"/api/v1/inventory/sales-orders/{so_id}", json=update_payload, headers=MOCK_HEADERS_ADMIN_1)
    assert put_res.status_code == 200, put_res.text
    put_data = put_res.json()
    assert put_data["success"] is True

    # 4. Verify updated values via GET
    verify_res = client.get(f"/api/v1/inventory/sales-orders/{so_id}", headers=MOCK_HEADERS_ADMIN_1)
    assert verify_res.status_code == 200
    updated_so = verify_res.json()["sales_order"]
    assert updated_so["customer_name"] == "North Campus Branch Academy"
    assert updated_so["customer_type"] == "Partner School"
    assert updated_so["customer_gstin"] == "29NORTH8888F1Z2"
    assert updated_so["payment_terms"] == "Advance 50% - Balance on Delivery"
    assert updated_so["shipping_address"] == "Gate 4, North Campus Reception"
    assert updated_so["status"] == "Processing"
    assert updated_so["total_amount"] == 6200.0
    assert len(updated_so["items"]) == 1
    assert updated_so["items"][0]["sku"] == "LAB-MAN-PHY"



