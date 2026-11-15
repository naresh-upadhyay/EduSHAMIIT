"""
Enterprise Inventory Management API for EduSHAMIIT ERP.
Provides high-performance endpoints executing PostgreSQL stored procedures and functions:
- Stock Overview, Balances & Real-Time Aggregations
- Inventory Items CRUD & SKU Management
- Goods Receiving (Direct & GRN)
- Departmental Stock Issues & Usable Returns
- Stock Adjustments & Inter-Store Transfers
- Immutable Transaction Ledger & Compensatory Reversals
- Procurement & Purchase Order Lifecycle (Draft, Submit, Approve, Receive)
- Sales Orders & Stock Reservations
- Dynamic Dropdown Metadata from Universal Lookup Management
- High-Speed CSV & Reporting Exports
"""
from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, status
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any, Union
from datetime import datetime, date, time
from decimal import Decimal
import io
import csv
import json
import uuid
import logging
import asyncio
import psycopg2
from psycopg2.extras import RealDictCursor, register_uuid

register_uuid()

from app.config import settings
from app.middleware.auth import get_current_user
from app.services.inventory_invoice_pdf import (
    generate_purchase_order_invoice_pdf,
    generate_sales_order_invoice_pdf,
)

logger = logging.getLogger(__name__)
router = APIRouter()


# ============================================================================
# DATABASE EXECUTION & UTILITY HELPERS
# ============================================================================

async def exec_sql(sql: str, params: tuple = (), fetch: bool = True) -> List[Dict[str, Any]]:
    """Execute raw parameterized SQL query asynchronously via psycopg2."""
    def _run():
        conn = psycopg2.connect(settings.DATABASE_URL, connect_timeout=5)
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(sql, params)
                if fetch and cur.description:
                    rows = cur.fetchall()
                    conn.commit()
                    return [dict(r) for r in rows]
                else:
                    conn.commit()
                    return []
        except Exception as e:
            conn.rollback()
            raise e
        finally:
            conn.close()

    return await asyncio.to_thread(_run)


def _serialize_val(val: Any) -> Any:
    """Format dates, datetimes, decimals, and UUIDs for clean JSON serialization."""
    if isinstance(val, (datetime, date, time)):
        return val.isoformat()
    if isinstance(val, uuid.UUID):
        return str(val)
    if isinstance(val, Decimal):
        return float(val)
    if isinstance(val, list):
        return [_serialize_val(x) for x in val]
    if isinstance(val, dict):
        return {k: _serialize_val(v) for k, v in val.items()}
    return val


def _get_school_id(current_user: Any) -> str:
    """Resolve active multi-tenant school UUID from token or fallback."""
    if not isinstance(current_user, dict):
        return "11111111-1111-1111-1111-111111111111"
    school_id = current_user.get("school_id")
    if not school_id and current_user.get("role") in ("super_admin", "superadmin", "admin"):
        return str(current_user.get("selected_school_id") or "11111111-1111-1111-1111-111111111111")
    return str(school_id or "11111111-1111-1111-1111-111111111111")


def _get_user_id(current_user: Any) -> Optional[str]:
    """Resolve active profile UUID."""
    if not isinstance(current_user, dict):
        return None
    return current_user.get("id") or current_user.get("user_id")


def _is_uuid(val: Any) -> bool:
    """Check if given string is a valid UUID."""
    if not val or not isinstance(val, str):
        return False
    try:
        uuid.UUID(val)
        return True
    except (ValueError, AttributeError):
        return False


# ============================================================================
# PYDANTIC REQUEST SCHEMAS
# ============================================================================

class ItemUpsertRequest(BaseModel):
    id: Optional[str] = None
    item_id: Optional[str] = None
    sku: Optional[str] = None
    barcode: Optional[str] = None
    item_name: Optional[str] = None
    name: Optional[str] = None
    description: Optional[str] = None
    category: Optional[str] = "Stationery"
    category_code: Optional[str] = None
    unit: Optional[str] = "Pcs"
    uom_code: Optional[str] = None
    purchase_price: Optional[float] = 0.0
    selling_price: Optional[float] = 0.0
    min_stock: Optional[int] = 10
    min_stock_level: Optional[float] = None
    max_stock: Optional[int] = 1000
    max_stock_level: Optional[float] = None
    reorder_quantity: Optional[float] = 25.0
    preferred_store_id: Optional[str] = None
    default_supplier_id: Optional[str] = None
    tracking_method: Optional[str] = "NONE"
    image_url: Optional[str] = None
    initial_stock: Optional[float] = 0.0
    stock_status: Optional[str] = None

    class Config:
        extra = "allow"


class ReceiveStockRequest(BaseModel):
    item_id: str
    store_id: str
    quantity: float
    unit_rate: Optional[float] = 0.0
    unit_cost: Optional[float] = None
    supplier_id: Optional[str] = None
    supplier_name: Optional[str] = None
    reference_number: Optional[str] = None
    invoice_reference: Optional[str] = None
    batch_number: Optional[str] = None
    expiry_date: Optional[str] = None
    remarks: Optional[str] = None
    notes: Optional[str] = None


class IssueStockRequest(BaseModel):
    item_id: str
    store_id: str
    quantity: float
    department: Optional[str] = "General"
    recipient_name: Optional[str] = None
    recipient: Optional[str] = None
    remarks: Optional[str] = None
    notes: Optional[str] = None
    purpose: Optional[str] = None


class AdjustStockRequest(BaseModel):
    item_id: str
    store_id: str
    quantity: float
    reason: Optional[str] = "Damage"
    adjustment_type: Optional[str] = None
    remarks: Optional[str] = None
    notes: Optional[str] = None


class TransferStockRequest(BaseModel):
    item_id: str
    source_store_id: str
    destination_store_id: str
    quantity: float
    remarks: Optional[str] = None
    notes: Optional[str] = None


class ReverseTransactionRequest(BaseModel):
    reason: Optional[str] = "Manual reversal correction"


class PurchaseOrderItemRequest(BaseModel):
    item_id: Optional[str] = None
    item_name: Optional[str] = None
    sku: Optional[str] = None
    unit: Optional[str] = "Pcs"
    quantity: float = 1.0
    unit_price: float = 0.0
    tax_rate: Optional[float] = 0.0


class CreatePurchaseOrderRequest(BaseModel):
    supplier_id: Optional[str] = None
    supplier_name: Optional[str] = None
    supplier_gstin: Optional[str] = "29AAACG1234F1Z8"
    store_id: Optional[str] = None
    department: Optional[str] = "Administration"
    delivery_date: Optional[str] = None
    expected_delivery_date: Optional[str] = None
    shipping_address: Optional[str] = "Main Campus Store, Greenwood High"
    payment_terms: Optional[str] = "Net 30 Days"
    notes: Optional[str] = None
    terms_conditions: Optional[str] = None
    subtotal: Optional[float] = None
    tax_amount: Optional[float] = None
    shipping_amount: Optional[float] = 0.0
    discount_amount: Optional[float] = None
    items: List[PurchaseOrderItemRequest]


class UpdatePurchaseOrderItemRequest(BaseModel):
    id: Optional[str] = None
    item_id: Optional[str] = None
    item_name: Optional[str] = None
    sku: Optional[str] = None
    unit: Optional[str] = "Pcs"
    quantity: float = 1.0
    unit_price: float = 0.0
    tax_rate: Optional[float] = 18.0
    total_price: Optional[float] = None


class UpdatePurchaseOrderRequest(BaseModel):
    supplier_id: Optional[str] = None
    supplier_name: Optional[str] = None
    supplier_gstin: Optional[str] = None
    store_id: Optional[str] = None
    department: Optional[str] = None
    delivery_date: Optional[str] = None
    expected_delivery_date: Optional[str] = None
    shipping_address: Optional[str] = None
    payment_terms: Optional[str] = None
    notes: Optional[str] = None
    terms_conditions: Optional[str] = None
    status: Optional[str] = None
    subtotal: Optional[float] = None
    tax_amount: Optional[float] = None
    shipping_amount: Optional[float] = None
    total_amount: Optional[float] = None
    items: Optional[List[UpdatePurchaseOrderItemRequest]] = None


class GRNLineRequest(BaseModel):
    item_id: Optional[str] = None
    po_item_id: Optional[str] = None
    quantity_received: float = 1.0


class ReceiveGRNRequest(BaseModel):
    po_id: Optional[str] = None
    store_id: Optional[str] = None
    notes: Optional[str] = None
    delivery_challan_number: Optional[str] = None
    vehicle_number: Optional[str] = None
    lines: Optional[List[Any]] = None
    items: Optional[List[Any]] = None


class SalesOrderItemRequest(BaseModel):
    item_id: Optional[str] = None
    item_name: Optional[str] = None
    sku: Optional[str] = None
    unit: Optional[str] = "Pcs"
    quantity: float = 1.0
    unit_price: float = 0.0
    tax_rate: Optional[float] = 0.0


class CreateSalesOrderRequest(BaseModel):
    customer_name: Optional[str] = "General Customer"
    customer_type: Optional[str] = "Partner School"
    customer_id: Optional[str] = None
    customer_gstin: Optional[str] = "29AAACG1234F1Z8"
    customer_contact: Optional[str] = None
    contact_phone: Optional[str] = None
    contact_email: Optional[str] = None
    shipping_address: Optional[str] = "Bangalore Center Distribution"
    store_id: Optional[str] = None
    department: Optional[str] = "Sales & Distribution"
    delivery_date: Optional[str] = None
    expected_delivery_date: Optional[str] = None
    payment_terms: Optional[str] = "Due on Receipt"
    notes: Optional[str] = None
    terms_conditions: Optional[str] = None
    tax_amount: Optional[float] = 0.0
    discount_amount: Optional[float] = 0.0
    items: List[SalesOrderItemRequest]


class UpdateSalesOrderItemRequest(BaseModel):
    id: Optional[str] = None
    item_id: Optional[str] = None
    item_name: Optional[str] = None
    sku: Optional[str] = None
    unit: Optional[str] = "Pcs"
    quantity: float = 1.0
    unit_price: float = 0.0
    tax_rate: Optional[float] = 5.0
    total_price: Optional[float] = None


class UpdateSalesOrderRequest(BaseModel):
    customer_id: Optional[str] = None
    customer_name: Optional[str] = None
    customer_type: Optional[str] = None
    customer_gstin: Optional[str] = None
    contact_phone: Optional[str] = None
    contact_email: Optional[str] = None
    store_id: Optional[str] = None
    department: Optional[str] = None
    delivery_date: Optional[str] = None
    expected_delivery_date: Optional[str] = None
    shipping_address: Optional[str] = None
    payment_terms: Optional[str] = None
    notes: Optional[str] = None
    terms_conditions: Optional[str] = None
    status: Optional[str] = None
    subtotal: Optional[float] = None
    tax_amount: Optional[float] = None
    discount_amount: Optional[float] = None
    total_amount: Optional[float] = None
    items: Optional[List[UpdateSalesOrderItemRequest]] = None



class FulfillSalesOrderRequest(BaseModel):
    action: str = Field(..., description="'deliver' or 'cancel'")


class CancelOrderRequest(BaseModel):
    reason: Optional[str] = Field("Cancelled by authority", description="Audit reason for cancellation")


class QuickAddLookupRequest(BaseModel):
    key_code: str
    value_name: str
    description: Optional[str] = None
    extra_data: Optional[Dict[str, Any]] = None


class QuickAddItemRequest(BaseModel):
    item_name: str
    category: Optional[str] = "Stationery"
    unit: Optional[str] = "Pcs"
    purchase_price: Optional[float] = 50.0
    selling_price: Optional[float] = 65.0
    store_id: Optional[str] = None


# ============================================================================
# API ENDPOINTS
# ============================================================================

# ----------------------------------------------------------------------------
# 1. TAB 1: STOCK OVERVIEW & DASHBOARD KPIS
# ----------------------------------------------------------------------------
@router.get("/overview")
async def get_inventory_overview(
    interval: Optional[str] = Query("6m"),
    user=Depends(get_current_user),
):
    """
    Returns dashboard KPI cards, category distribution, rolling stock trend by interval ('30d', '6m', '1y'),
    low stock alerts, and recent activities via PostgreSQL stored function.
    """
    school_id = _get_school_id(user)
    try:
        sql = "SELECT public.fn_inventory_get_overview(%s::UUID, %s) AS res;"
        rows = await exec_sql(sql, (school_id, interval or "6m"))
        if rows and rows[0].get("res"):
            return _serialize_val(rows[0]["res"])
        raise HTTPException(status_code=500, detail="Failed to retrieve overview")
    except Exception as e:
        logger.error(f"[Inventory] Overview error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))




@router.get("/metadata")
async def get_inventory_metadata(
    user=Depends(get_current_user),
):
    """
    Returns dynamic dropdown metadata: categories and units from Universal Lookups,
    active stores, suppliers, customers, and transaction/order statuses.
    """
    school_id = _get_school_id(user)
    try:
        sql = "SELECT public.fn_inventory_get_metadata(%s::UUID) AS res;"
        rows = await exec_sql(sql, (school_id,))
        if rows and rows[0].get("res"):
            return _serialize_val(rows[0]["res"])
        raise HTTPException(status_code=500, detail="Failed to retrieve metadata")
    except Exception as e:
        logger.error(f"[Inventory] Metadata error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))




@router.get("/catalog-items")
async def get_inventory_catalog_items(
    search: Optional[str] = Query(None),
    user=Depends(get_current_user),
):
    """Returns the complete unpaginated active items catalog for dropdowns and typeahead."""
    school_id = _get_school_id(user)
    try:
        sql = "SELECT public.fn_inventory_get_catalog_items(%s::UUID, %s) AS res;"
        rows = await exec_sql(sql, (school_id, search))
        if rows and rows[0].get("res"):
            return _serialize_val(rows[0]["res"])
        return {"success": True, "items": [], "total": 0}
    except Exception as e:
        logger.error(f"[Inventory] Catalog items error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))




@router.post("/lookups/quick-add")
async def quick_add_inventory_lookup(
    req: QuickAddLookupRequest,
    user=Depends(get_current_user),
):
    """
    On-the-fly lookup value creator: adds to lookup_values and syncs
    to suppliers, stores, or customers table accordingly.
    """
    school_id = _get_school_id(user)
    user_id = _get_user_id(user)
    try:
        sql = """
            SELECT public.fn_inventory_add_lookup_value(
                %s::UUID, %s::UUID, %s, %s, %s, %s::JSONB
            ) AS res;
        """
        rows = await exec_sql(sql, (
            school_id, user_id, req.key_code, req.value_name, req.description, json.dumps(req.extra_data or {})
        ))
        if rows and rows[0].get("res"):
            res = rows[0]["res"]
            if not res.get("success"):
                raise HTTPException(status_code=400, detail=res.get("error", "Failed to add lookup value"))
            return _serialize_val(res)
        raise HTTPException(status_code=500, detail="Failed to add lookup value")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Inventory] Quick add lookup error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))




@router.post("/items/quick-add")
async def quick_add_inventory_item(
    req: QuickAddItemRequest,
    user=Depends(get_current_user),
):
    """
    Quick creates a catalog item on the fly with auto-generated SKU and adds to lookups.
    """
    school_id = _get_school_id(user)
    user_id = _get_user_id(user)
    extra_data = {
        "category": req.category or "Stationery",
        "unit": req.unit or "Pcs",
        "purchase_price": req.purchase_price or 50.0,
        "selling_price": req.selling_price or 65.0,
        "store_id": req.store_id,
    }
    try:
        sql = """
            SELECT public.fn_inventory_add_lookup_value(
                %s::UUID, %s::UUID, 'INVENTORY_ITEMS', %s, NULL, %s::JSONB
            ) AS res;
        """
        rows = await exec_sql(sql, (school_id, user_id, req.item_name, json.dumps(extra_data)))
        if rows and rows[0].get("res"):
            res = rows[0]["res"]
            if not res.get("success"):
                raise HTTPException(status_code=400, detail=res.get("error", "Failed to quick create item"))
            item_rows = await exec_sql(
                "SELECT * FROM public.inventory_items WHERE id = %s::UUID;", (res["id"],)
            )
            if item_rows:
                return {"success": True, "item": _serialize_val(item_rows[0])}
            return _serialize_val(res)
        raise HTTPException(status_code=500, detail="Failed to quick create item")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Inventory] Quick add item error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))




# ----------------------------------------------------------------------------
# 2. INVENTORY ITEMS (CRUD & STOCK BALANCES)
# ----------------------------------------------------------------------------
@router.get("/items")
async def get_inventory_items(
    search: Optional[str] = Query(None),
    category: Optional[str] = Query(None),
    store_id: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    sort_by: Optional[str] = Query(None),
    sort_order: Optional[str] = Query("desc"),
    user=Depends(get_current_user),
):
    """Paginated items with stock levels, reorder thresholds, and dynamic status."""
    school_id = _get_school_id(user)
    try:
        clean_store_id = store_id if _is_uuid(store_id) else None
        sql = """
            SELECT public.fn_inventory_get_items(
                %s::UUID, %s, %s, %s::UUID, %s, %s::INT, %s::INT, %s, %s
            ) AS res;
        """
        rows = await exec_sql(sql, (
            school_id, search, category, clean_store_id, status, page, page_size, sort_by or "created_at", sort_order or "desc"
        ))
        if rows and rows[0].get("res"):
            return _serialize_val(rows[0]["res"])
        return {"success": True, "total": 0, "items": []}
    except Exception as e:
        logger.error(f"[Inventory] Get items error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))




@router.post("/items")
async def create_inventory_item(
    payload: ItemUpsertRequest,
    user=Depends(get_current_user),
):
    """Create a new inventory item with initial stock balance."""
    school_id = _get_school_id(user)
    user_id = _get_user_id(user)
    data = payload.dict()
    if not data.get("item_name") and data.get("name"):
        data["item_name"] = data["name"]
    if not data.get("id") and data.get("item_id"):
        data["id"] = data["item_id"]
    if not data.get("item_name"):
        raise HTTPException(status_code=400, detail="Item name is required")
    if data.get("min_stock_level") is not None and not data.get("min_stock"):
        data["min_stock"] = int(float(data["min_stock_level"]))
    elif data.get("min_stock") is not None:
        data["min_stock"] = int(float(data["min_stock"]))
    if data.get("max_stock_level") is not None and not data.get("max_stock"):
        data["max_stock"] = int(float(data["max_stock_level"]))
    elif data.get("max_stock") is not None:
        data["max_stock"] = int(float(data["max_stock"]))
    if data.get("reorder_quantity") is not None:
        data["reorder_quantity"] = int(float(data["reorder_quantity"]))

    try:
        sql = "SELECT public.fn_inventory_upsert_item(%s::UUID, %s::JSONB, %s::UUID) AS res;"
        rows = await exec_sql(sql, (school_id, json.dumps(data), user_id))
        if rows and rows[0].get("res"):
            res = rows[0]["res"]
            if not res.get("success"):
                raise HTTPException(status_code=400, detail=res.get("error", "Failed to save item"))
            return _serialize_val(res)
        raise HTTPException(status_code=500, detail="Database function returned empty response")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Inventory] Create item error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))




@router.put("/items/{item_id}")
async def update_inventory_item(
    item_id: str,
    payload: ItemUpsertRequest,
    user=Depends(get_current_user),
):
    """Update existing inventory item."""
    school_id = _get_school_id(user)
    user_id = _get_user_id(user)
    data = payload.dict()
    data["id"] = item_id
    if not data.get("item_name") and data.get("name"):
        data["item_name"] = data["name"]
    if not data.get("item_name"):
        raise HTTPException(status_code=400, detail="Item name is required")
    if data.get("min_stock_level") is not None and not data.get("min_stock"):
        data["min_stock"] = int(float(data["min_stock_level"]))
    elif data.get("min_stock") is not None:
        data["min_stock"] = int(float(data["min_stock"]))
    if data.get("max_stock_level") is not None and not data.get("max_stock"):
        data["max_stock"] = int(float(data["max_stock_level"]))
    elif data.get("max_stock") is not None:
        data["max_stock"] = int(float(data["max_stock"]))
    if data.get("reorder_quantity") is not None:
        data["reorder_quantity"] = int(float(data["reorder_quantity"]))

    try:
        sql = "SELECT public.fn_inventory_upsert_item(%s::UUID, %s::JSONB, %s::UUID) AS res;"
        rows = await exec_sql(sql, (school_id, json.dumps(data), user_id))
        if rows and rows[0].get("res"):
            res = rows[0]["res"]
            if not res.get("success"):
                raise HTTPException(status_code=400, detail=res.get("error", "Failed to update item"))
            return _serialize_val(res)
        raise HTTPException(status_code=500, detail="Database function returned empty response")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Inventory] Update item error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))




@router.delete("/items/{item_id}")
async def delete_inventory_item(
    item_id: str,
    user=Depends(get_current_user),
):
    """Deactivate inventory item safely."""
    school_id = _get_school_id(user)
    user_id = _get_user_id(user)
    try:
        sql = "SELECT public.fn_inventory_delete_item(%s::UUID, %s::UUID, %s::UUID) AS res;"
        rows = await exec_sql(sql, (school_id, item_id, user_id))
        if rows and rows[0].get("res"):
            return _serialize_val(rows[0]["res"])
        raise HTTPException(status_code=500, detail="Database function returned empty response")
    except Exception as e:
        logger.error(f"[Inventory] Delete item error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))




# ----------------------------------------------------------------------------
# 3. STOCK OPERATIONS (RECEIVE, ISSUE, ADJUST, TRANSFER)
# ----------------------------------------------------------------------------
@router.post("/receive")
async def receive_stock(
    payload: ReceiveStockRequest,
    user=Depends(get_current_user),
):
    """Direct stock intake into store balance with movement ledger entry."""
    school_id = _get_school_id(user)
    user_id = _get_user_id(user)
    try:
        payload_dict = payload.dict()
        if payload_dict.get("unit_cost") and not payload_dict.get("unit_rate"):
            payload_dict["unit_rate"] = payload_dict["unit_cost"]
        if payload_dict.get("invoice_reference") and not payload_dict.get("reference_number"):
            payload_dict["reference_number"] = payload_dict["invoice_reference"]
        if payload_dict.get("notes") and not payload_dict.get("remarks"):
            payload_dict["remarks"] = payload_dict["notes"]
        if not payload_dict.get("supplier_name") and payload_dict.get("supplier_id"):
            if _is_uuid(payload_dict["supplier_id"]):
                sup_rows = await exec_sql("SELECT supplier_name FROM public.inventory_suppliers WHERE id = %s::UUID LIMIT 1;", (payload_dict["supplier_id"],))
                if sup_rows:
                    payload_dict["supplier_name"] = sup_rows[0].get("supplier_name")
            else:
                payload_dict["supplier_name"] = str(payload_dict["supplier_id"])
        sql = "SELECT public.fn_inventory_receive_stock(%s::UUID, %s::JSONB, %s::UUID) AS res;"
        rows = await exec_sql(sql, (school_id, json.dumps(payload_dict), user_id))
        if rows and rows[0].get("res"):
            res = rows[0]["res"]
            if not res.get("success"):
                raise HTTPException(status_code=400, detail=res.get("error"))
            return _serialize_val(res)
        raise HTTPException(status_code=500, detail="Database function error")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Inventory] Receive stock error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))




@router.post("/issue")
async def issue_stock(
    payload: IssueStockRequest,
    user=Depends(get_current_user),
):
    """Issue stock to department or teacher with sufficiency checks."""
    school_id = _get_school_id(user)
    user_id = _get_user_id(user)
    try:
        payload_dict = payload.dict()
        if payload_dict.get("recipient") and not payload_dict.get("recipient_name"):
            payload_dict["recipient_name"] = payload_dict["recipient"]
        if payload_dict.get("notes") and not payload_dict.get("remarks"):
            payload_dict["remarks"] = payload_dict["notes"]
        sql = "SELECT public.fn_inventory_issue_stock(%s::UUID, %s::JSONB, %s::UUID) AS res;"
        rows = await exec_sql(sql, (school_id, json.dumps(payload_dict), user_id))
        if rows and rows[0].get("res"):
            res = rows[0]["res"]
            if not res.get("success"):
                raise HTTPException(status_code=400, detail=res.get("error"))
            return _serialize_val(res)
        raise HTTPException(status_code=500, detail="Database function error")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Inventory] Issue stock error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))




@router.post("/adjust")
async def adjust_stock(
    payload: AdjustStockRequest,
    user=Depends(get_current_user),
):
    """Adjust stock for audit discrepancy, breakage, or expiry."""
    school_id = _get_school_id(user)
    user_id = _get_user_id(user)
    try:
        payload_dict = payload.dict()
        if payload_dict.get("adjustment_type") and not payload_dict.get("reason"):
            payload_dict["reason"] = payload_dict["adjustment_type"]
        if payload_dict.get("notes") and not payload_dict.get("remarks"):
            payload_dict["remarks"] = payload_dict["notes"]
        sql = "SELECT public.fn_inventory_adjust_stock(%s::UUID, %s::JSONB, %s::UUID) AS res;"
        rows = await exec_sql(sql, (school_id, json.dumps(payload_dict), user_id))
        if rows and rows[0].get("res"):
            res = rows[0]["res"]
            if not res.get("success"):
                raise HTTPException(status_code=400, detail=res.get("error"))
            return _serialize_val(res)
        raise HTTPException(status_code=500, detail="Database function error")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Inventory] Adjust stock error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))




@router.post("/transfer")
async def transfer_stock(
    payload: TransferStockRequest,
    user=Depends(get_current_user),
):
    """Atomically transfer inventory between stores without quantity destruction."""
    school_id = _get_school_id(user)
    user_id = _get_user_id(user)
    try:
        payload_dict = payload.dict()
        if payload_dict.get("notes") and not payload_dict.get("remarks"):
            payload_dict["remarks"] = payload_dict["notes"]
        sql = "SELECT public.fn_inventory_transfer_stock(%s::UUID, %s::JSONB, %s::UUID) AS res;"
        rows = await exec_sql(sql, (school_id, json.dumps(payload_dict), user_id))
        if rows and rows[0].get("res"):
            res = rows[0]["res"]
            if not res.get("success"):
                raise HTTPException(status_code=400, detail=res.get("error"))
            return _serialize_val(res)
        raise HTTPException(status_code=500, detail="Database function error")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Inventory] Transfer stock error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))




# ----------------------------------------------------------------------------
# 4. TAB 2: RECENT TRANSACTIONS (LEDGER & REVERSAL)
# ----------------------------------------------------------------------------
@router.get("/transactions")
async def get_transactions(
    search: Optional[str] = Query(None),
    type: Optional[str] = Query(None),
    item_id: Optional[str] = Query(None),
    store_id: Optional[str] = Query(None),
    start_date: Optional[str] = Query(None),
    end_date: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    sort_by: Optional[str] = Query(None),
    sort_order: Optional[str] = Query("desc"),
    user=Depends(get_current_user),
):
    """Paginated stock movement ledger with monthly summary bar chart data."""
    school_id = _get_school_id(user)
    try:
        sql = """
            SELECT public.fn_inventory_get_transactions(
                %s::UUID, %s, %s, %s::UUID, %s::UUID, %s::DATE, %s::DATE, %s::INT, %s::INT, %s, %s
            ) AS res;
        """
        rows = await exec_sql(sql, (
            school_id, search, type, item_id, store_id, start_date, end_date, page, page_size, sort_by or "created_at", sort_order or "desc"
        ))
        if rows and rows[0].get("res"):
            return _serialize_val(rows[0]["res"])
        return {"success": True, "total": 0, "transactions": []}
    except Exception as e:
        logger.error(f"[Inventory] Transactions error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))




@router.post("/transactions/{movement_id}/reverse")
async def reverse_transaction(
    movement_id: str,
    payload: ReverseTransactionRequest,
    user=Depends(get_current_user),
):
    """
    Reverse completed transaction via an immutable compensatory movement ledger record.
    Preserves audit history without editing original completed records.
    """
    school_id = _get_school_id(user)
    user_id = _get_user_id(user)
    try:
        sql = "SELECT public.fn_inventory_reverse_transaction(%s::UUID, %s::UUID, %s, %s::UUID) AS res;"
        rows = await exec_sql(sql, (school_id, movement_id, payload.reason, user_id))
        if rows and rows[0].get("res"):
            res = rows[0]["res"]
            if not res.get("success"):
                raise HTTPException(status_code=400, detail=res.get("error"))
            return _serialize_val(res)
        raise HTTPException(status_code=500, detail="Database function error")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Inventory] Reverse transaction error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))




# ----------------------------------------------------------------------------
# 5. TAB 3: PURCHASE ORDERS & GRN
# ----------------------------------------------------------------------------
@router.get("/purchase-orders")
async def get_purchase_orders(
    search: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    supplier_id: Optional[str] = Query(None),
    start_date: Optional[str] = Query(None),
    end_date: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    sort_by: Optional[str] = Query(None),
    sort_order: Optional[str] = Query("desc"),
    user=Depends(get_current_user),
):
    """Paginated purchase orders with procurement KPIs and trend charts."""
    school_id = _get_school_id(user)
    try:
        sql = """
            SELECT public.fn_inventory_get_purchase_orders(
                %s::UUID, %s, %s, %s, %s::DATE, %s::DATE, %s::INT, %s::INT, %s, %s
            ) AS res;
        """
        rows = await exec_sql(sql, (
            school_id, search, status, supplier_id, start_date, end_date, page, page_size, sort_by or "order_date", sort_order or "desc"
        ))
        if rows and rows[0].get("res"):
            return _serialize_val(rows[0]["res"])
        return {"success": True, "total": 0, "purchase_orders": []}
    except Exception as e:
        logger.error(f"[Inventory] Purchase orders error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))




@router.post("/purchase-orders")
async def create_purchase_order(
    payload: CreatePurchaseOrderRequest,
    user=Depends(get_current_user),
):
    """Create a new purchase order with multi-line items and backend amount calculations."""
    school_id = _get_school_id(user)
    user_id = _get_user_id(user)
    try:
        payload_dict = payload.dict()
        if not payload_dict.get("delivery_date") and payload_dict.get("expected_delivery_date"):
            payload_dict["delivery_date"] = payload_dict["expected_delivery_date"]
        
        # Auto-resolve supplier_name if missing
        if not payload_dict.get("supplier_name") and payload_dict.get("supplier_id"):
            if _is_uuid(payload_dict["supplier_id"]):
                sup_rows = await exec_sql("SELECT supplier_name FROM public.inventory_suppliers WHERE id = %s::UUID LIMIT 1;", (payload_dict["supplier_id"],))
                if sup_rows and sup_rows[0].get("supplier_name"):
                    payload_dict["supplier_name"] = sup_rows[0]["supplier_name"]
                else:
                    payload_dict["supplier_name"] = "General Vendor"
            else:
                payload_dict["supplier_name"] = str(payload_dict["supplier_id"])
        elif not payload_dict.get("supplier_name"):
            payload_dict["supplier_name"] = "General Vendor"
                
        # Auto-resolve item_name and sku for items if missing
        for it in payload_dict.get("items", []):
            if not it.get("item_name") and it.get("item_id"):
                if _is_uuid(it["item_id"]):
                    item_rows = await exec_sql("SELECT item_name, sku, unit, purchase_price FROM public.inventory_items WHERE id = %s::UUID LIMIT 1;", (it["item_id"],))
                    if item_rows:
                        it["item_name"] = item_rows[0]["item_name"]
                        if not it.get("sku"):
                            it["sku"] = item_rows[0].get("sku", "")
                        if not it.get("unit"):
                            it["unit"] = item_rows[0].get("unit", "Pcs")
                        if not it.get("unit_price") and item_rows[0].get("purchase_price"):
                            it["unit_price"] = float(item_rows[0]["purchase_price"])
                else:
                    it["item_name"] = str(it["item_id"])
            elif not it.get("item_name"):
                it["item_name"] = "General Item"

        sql = "SELECT public.fn_inventory_create_purchase_order(%s::UUID, %s::JSONB, %s::UUID) AS res;"
        rows = await exec_sql(sql, (school_id, json.dumps(payload_dict), user_id))
        if rows and rows[0].get("res"):
            res = rows[0]["res"]
            if not res.get("success"):
                raise HTTPException(status_code=400, detail=res.get("error"))
            return _serialize_val(res)
        raise HTTPException(status_code=500, detail="Database function error")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Inventory] Create purchase order error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))




@router.post("/purchase-orders/receive-grn")
@router.post("/purchase-orders/{po_id}/receive")
async def receive_goods_grn(
    payload: ReceiveGRNRequest,
    po_id: Optional[str] = None,
    user=Depends(get_current_user),
):
    """Post Goods Received Note (GRN) and update stock balance into inventory."""
    school_id = _get_school_id(user)
    user_id = _get_user_id(user)
    try:
        payload_dict = payload.dict()
        if po_id:
            payload_dict["po_id"] = po_id
        if not payload_dict.get("lines") and payload_dict.get("items"):
            payload_dict["lines"] = payload_dict["items"]
        if not payload_dict.get("lines"):
            target_po = po_id or payload_dict.get("po_id")
            if target_po:
                rem_rows = await exec_sql(
                    "SELECT item_id, GREATEST(0, quantity_ordered - quantity_received) as quantity_received FROM public.inventory_purchase_order_items WHERE po_id = %s::UUID AND (quantity_ordered - quantity_received) > 0;",
                    (target_po,)
                )
                payload_dict["lines"] = [
                    {"item_id": str(r["item_id"]), "quantity_received": float(r["quantity_received"])}
                    for r in rem_rows
                ]
            else:
                payload_dict["lines"] = []
        if payload_dict.get("lines"):
            for l in payload_dict["lines"]:
                if isinstance(l, dict):
                    if "received_quantity" in l and "quantity_received" not in l:
                        l["quantity_received"] = l["received_quantity"]
                    elif "quantity_received" in l and "received_quantity" not in l:
                        l["received_quantity"] = l["quantity_received"]
        sql = "SELECT public.fn_inventory_receive_goods_grn(%s::UUID, %s::JSONB, %s::UUID) AS res;"
        rows = await exec_sql(sql, (school_id, json.dumps(payload_dict), user_id))
        if rows and rows[0].get("res"):
            res = rows[0]["res"]
            if not res.get("success"):
                raise HTTPException(status_code=400, detail=res.get("error"))
            return _serialize_val(res)
        raise HTTPException(status_code=500, detail="Database function error")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Inventory] Receive GRN error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/purchase-orders/{po_id}")
async def get_purchase_order_by_id(
    po_id: str,
    user=Depends(get_current_user),
):
    """Retrieve full purchase order details including line items, counterparty, and billing attributes."""
    school_id = _get_school_id(user)
    try:
        if _is_uuid(po_id):
            po_rows = await exec_sql(
                "SELECT * FROM public.inventory_purchase_orders WHERE id = %s::UUID AND school_id = %s::UUID LIMIT 1;",
                (po_id, school_id)
            )
        else:
            po_rows = await exec_sql(
                "SELECT * FROM public.inventory_purchase_orders WHERE po_number = %s AND school_id = %s::UUID LIMIT 1;",
                (po_id, school_id)
            )
        
        if not po_rows:
            po_rows = await exec_sql(
                "SELECT * FROM public.inventory_purchase_orders WHERE id = %s::UUID OR po_number = %s LIMIT 1;"
                if _is_uuid(po_id) else "SELECT * FROM public.inventory_purchase_orders WHERE po_number = %s LIMIT 1;",
                (po_id, po_id) if _is_uuid(po_id) else (po_id,)
            )

        if not po_rows:
            raise HTTPException(status_code=404, detail=f"Purchase order '{po_id}' not found.")
        
        po = dict(po_rows[0])
        actual_id = str(po["id"])
        items = await exec_sql(
            "SELECT * FROM public.inventory_purchase_order_items WHERE po_id = %s::UUID ORDER BY created_at ASC;",
            (actual_id,)
        )
        po["items"] = items or []
        return {"success": True, "purchase_order": _serialize_val(po)}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Inventory] Get purchase order error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/purchase-orders/{po_id}")
async def update_purchase_order(
    po_id: str,
    payload: UpdatePurchaseOrderRequest,
    user=Depends(get_current_user),
):
    """Update purchase order details, supplier/counterparty info, logistics, notes, terms, and line items."""
    school_id = _get_school_id(user)
    try:
        # 1. Resolve order
        if _is_uuid(po_id):
            po_rows = await exec_sql(
                "SELECT * FROM public.inventory_purchase_orders WHERE id = %s::UUID AND school_id = %s::UUID LIMIT 1;",
                (po_id, school_id)
            )
        else:
            po_rows = await exec_sql(
                "SELECT * FROM public.inventory_purchase_orders WHERE po_number = %s AND school_id = %s::UUID LIMIT 1;",
                (po_id, school_id)
            )
        
        if not po_rows:
            po_rows = await exec_sql(
                "SELECT * FROM public.inventory_purchase_orders WHERE id = %s::UUID OR po_number = %s LIMIT 1;"
                if _is_uuid(po_id) else "SELECT * FROM public.inventory_purchase_orders WHERE po_number = %s LIMIT 1;",
                (po_id, po_id) if _is_uuid(po_id) else (po_id,)
            )

        if not po_rows:
            raise HTTPException(status_code=404, detail=f"Purchase order '{po_id}' not found.")

        current_po = dict(po_rows[0])
        actual_id = str(current_po["id"])
        data = payload.dict(exclude_unset=True)

        delivery_date = data.get("delivery_date") or data.get("expected_delivery_date")
        supplier_name = data.get("supplier_name")
        supplier_id = data.get("supplier_id") if _is_uuid(data.get("supplier_id")) else None
        supplier_gstin = data.get("supplier_gstin")
        store_id = data.get("store_id") if _is_uuid(data.get("store_id")) else None
        department = data.get("department")
        shipping_address = data.get("shipping_address")
        payment_terms = data.get("payment_terms")
        notes = data.get("notes")
        terms_conditions = data.get("terms_conditions")
        order_status = data.get("status")

        # 2. Update line items if provided
        items = data.get("items")
        subtotal = data.get("subtotal")
        tax_amount = data.get("tax_amount")
        shipping_amount = data.get("shipping_amount")
        total_amount = data.get("total_amount")

        if items is not None:
            del_sql = "DELETE FROM public.inventory_purchase_order_items WHERE po_id = %s::UUID;"
            await exec_sql(del_sql, (actual_id,), fetch=False)
            
            calc_subtotal = 0.0
            calc_tax = 0.0
            for it in items:
                it_name = it.get("item_name") or "General Item"
                it_sku = it.get("sku") or ""
                it_unit = it.get("unit") or "Pcs"
                it_qty = float(it.get("quantity") or 1.0)
                it_price = float(it.get("unit_price") or 0.0)
                it_tax_rate = float(it.get("tax_rate") or 18.0)
                it_total = it.get("total_price")
                if it_total is None:
                    it_total = it_qty * it_price
                else:
                    it_total = float(it_total)
                
                calc_subtotal += it_total
                calc_tax += (it_total * it_tax_rate / 100.0)
                
                item_id_val = it.get("item_id") if _is_uuid(it.get("item_id")) else None
                ins_item = """
                    INSERT INTO public.inventory_purchase_order_items (
                        id, school_id, po_id, item_id, item_name, sku, unit, quantity_ordered, quantity_received, unit_price, tax_rate, line_total, created_at
                    ) VALUES (
                        gen_random_uuid(), %s::UUID, %s::UUID, %s, %s, %s, %s, %s, 0.0, %s, %s, %s, NOW()
                    );
                """
                await exec_sql(ins_item, (school_id, actual_id, item_id_val, it_name, it_sku, it_unit, it_qty, it_price, it_tax_rate, it_total), fetch=False)
            
            if subtotal is None:
                subtotal = calc_subtotal
            if tax_amount is None:
                tax_amount = calc_tax
            if shipping_amount is None:
                shipping_amount = float(current_po.get("shipping_amount") or 0.0)
            if total_amount is None:
                total_amount = subtotal + tax_amount + shipping_amount

        # 3. Dynamic UPDATE on inventory_purchase_orders
        upd_fields = ["updated_at = NOW()"]
        upd_params = []

        if supplier_name is not None:
            upd_fields.append("supplier_name = %s")
            upd_params.append(supplier_name)
        if supplier_id is not None:
            upd_fields.append("supplier_id = %s::UUID")
            upd_params.append(supplier_id)
        if supplier_gstin is not None:
            upd_fields.append("supplier_gstin = %s")
            upd_params.append(supplier_gstin)
        if store_id is not None:
            upd_fields.append("store_id = %s::UUID")
            upd_params.append(store_id)
        if department is not None:
            upd_fields.append("department = %s")
            upd_params.append(department)
        if shipping_address is not None:
            upd_fields.append("shipping_address = %s")
            upd_params.append(shipping_address)
        if payment_terms is not None:
            upd_fields.append("payment_terms = %s")
            upd_params.append(payment_terms)
        if delivery_date is not None:
            upd_fields.append("delivery_date = %s::DATE")
            upd_params.append(delivery_date)
        if notes is not None:
            upd_fields.append("notes = %s")
            upd_params.append(notes)
        if terms_conditions is not None:
            upd_fields.append("terms_conditions = %s")
            upd_params.append(terms_conditions)
        if order_status is not None:
            upd_fields.append("status = %s")
            upd_params.append(order_status)
        if subtotal is not None:
            upd_fields.append("subtotal = %s")
            upd_params.append(subtotal)
        if tax_amount is not None:
            upd_fields.append("tax_amount = %s")
            upd_params.append(tax_amount)
        if shipping_amount is not None:
            upd_fields.append("shipping_amount = %s")
            upd_params.append(shipping_amount)
        if total_amount is not None:
            upd_fields.append("total_amount = %s")
            upd_params.append(total_amount)
        if items is not None:
            upd_fields.append("total_items = %s")
            upd_params.append(len(items))

        upd_sql = f"UPDATE public.inventory_purchase_orders SET {', '.join(upd_fields)} WHERE id = %s::UUID RETURNING *;"
        upd_params.append(actual_id)
        res_rows = await exec_sql(upd_sql, tuple(upd_params))
        updated_po = dict(res_rows[0]) if res_rows else current_po
        
        updated_items = await exec_sql(
            "SELECT * FROM public.inventory_purchase_order_items WHERE po_id = %s::UUID ORDER BY created_at ASC;",
            (actual_id,)
        )
        updated_po["items"] = updated_items or []
        return {
            "success": True,
            "message": "Purchase order updated successfully",
            "purchase_order": _serialize_val(updated_po)
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Inventory] Update purchase order error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/purchase-orders/{po_id}/cancel")
async def cancel_purchase_order(
    po_id: str,
    payload: CancelOrderRequest = CancelOrderRequest(),
    user=Depends(get_current_user),
):
    """Cancel a pending purchase order atomically via stored procedure."""
    school_id = _get_school_id(user)
    try:
        # Resolve order id (support po_number or UUID)
        actual_id = po_id
        if not _is_uuid(po_id):
            row = await exec_sql("SELECT id FROM public.inventory_purchase_orders WHERE po_number = %s AND school_id = %s::UUID LIMIT 1;", (po_id, school_id))
            if not row:
                raise HTTPException(status_code=404, detail=f"Purchase order '{po_id}' not found.")
            actual_id = str(row[0]["id"])
        
        sql = "SELECT public.fn_inventory_cancel_purchase_order(%s::UUID, %s::UUID, %s) AS res;"
        rows = await exec_sql(sql, (school_id, actual_id, payload.reason or "Cancelled by authority"))
        if rows and rows[0].get("res"):
            res = rows[0]["res"]
            if not res.get("success"):
                raise HTTPException(status_code=400, detail=res.get("error"))
            return _serialize_val(res)
        raise HTTPException(status_code=500, detail="Cancellation function error")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Inventory] Cancel purchase order error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/purchase-orders/{po_id}/pdf")
async def download_purchase_order_pdf(
    po_id: str,
    user=Depends(get_current_user),
):
    """Generate and download a high-resolution, print-ready Purchase Order Tax Invoice PDF."""
    school_id = _get_school_id(user)
    try:
        # 1. Fetch order details (supporting both UUID and po_number)
        if _is_uuid(po_id):
            po_rows = await exec_sql(
                "SELECT * FROM public.inventory_purchase_orders WHERE id = %s::UUID AND school_id = %s::UUID LIMIT 1;",
                (po_id, school_id)
            )
        else:
            po_rows = await exec_sql(
                "SELECT * FROM public.inventory_purchase_orders WHERE po_number = %s AND school_id = %s::UUID LIMIT 1;",
                (po_id, school_id)
            )
        
        if not po_rows:
            po_rows = await exec_sql(
                "SELECT * FROM public.inventory_purchase_orders WHERE id = %s::UUID OR po_number = %s LIMIT 1;"
                if _is_uuid(po_id) else "SELECT * FROM public.inventory_purchase_orders WHERE po_number = %s LIMIT 1;",
                (po_id, po_id) if _is_uuid(po_id) else (po_id,)
            )

        if not po_rows:
            raise HTTPException(status_code=404, detail=f"Purchase order {po_id} not found.")

        order = dict(po_rows[0])
        real_po_id = order["id"]

        # 2. Fetch line items
        it_rows = await exec_sql(
            "SELECT * FROM public.inventory_purchase_order_items WHERE po_id = %s::UUID ORDER BY created_at ASC;",
            (real_po_id,)
        )
        items = [dict(r) for r in (it_rows or [])]

        # 3. Generate PDF
        pdf_bytes = generate_purchase_order_invoice_pdf(order, items)
        filename = f"Invoice-{order.get('po_number', 'PO')}.pdf"

        return Response(
            content=pdf_bytes,
            media_type="application/pdf",
            headers={
                "Content-Disposition": f'attachment; filename="{filename}"',
                "Content-Type": "application/pdf"
            }
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Inventory] Download PO PDF error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


# ----------------------------------------------------------------------------
# 6. TAB 4: SALES ORDERS & FULFILLMENT
# ----------------------------------------------------------------------------
@router.get("/sales-orders")
async def get_sales_orders(
    search: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    customer: Optional[str] = Query(None),
    start_date: Optional[str] = Query(None),
    end_date: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    sort_by: Optional[str] = Query(None),
    sort_order: Optional[str] = Query("desc"),
    user=Depends(get_current_user),
):
    """Paginated sales orders with sales KPIs and monthly trend chart data."""
    school_id = _get_school_id(user)
    try:
        sql = """
            SELECT public.fn_inventory_get_sales_orders(
                %s::UUID, %s, %s, %s, %s::DATE, %s::DATE, %s::INT, %s::INT, %s, %s
            ) AS res;
        """
        rows = await exec_sql(sql, (
            school_id, search, status, customer, start_date, end_date, page, page_size, sort_by or "order_date", sort_order or "desc"
        ))
        if rows and rows[0].get("res"):
            return _serialize_val(rows[0]["res"])
        return {"success": True, "total": 0, "sales_orders": []}
    except Exception as e:
        logger.error(f"[Inventory] Sales orders error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))




@router.post("/sales-orders")
async def create_sales_order(
    payload: CreateSalesOrderRequest,
    user=Depends(get_current_user),
):
    """Create a sales order and reserve stock."""
    school_id = _get_school_id(user)
    user_id = _get_user_id(user)
    try:
        payload_dict = payload.dict()
        if not payload_dict.get("delivery_date") and payload_dict.get("expected_delivery_date"):
            payload_dict["delivery_date"] = payload_dict["expected_delivery_date"]
        if not payload_dict.get("customer_name") and payload_dict.get("customer_id"):
            if _is_uuid(payload_dict["customer_id"]):
                cust_rows = await exec_sql("SELECT full_name FROM public.profiles WHERE id = %s::UUID LIMIT 1;", (payload_dict["customer_id"],))
                if cust_rows and cust_rows[0].get("full_name"):
                    payload_dict["customer_name"] = cust_rows[0]["full_name"]
                else:
                    lv_rows = await exec_sql("SELECT value_name FROM public.lookup_values WHERE id = %s::UUID LIMIT 1;", (payload_dict["customer_id"],))
                    if lv_rows and lv_rows[0].get("value_name"):
                        payload_dict["customer_name"] = lv_rows[0]["value_name"]
                    else:
                        payload_dict["customer_name"] = "Direct Buyer"
            else:
                payload_dict["customer_name"] = str(payload_dict["customer_id"])
        elif not payload_dict.get("customer_name"):
            payload_dict["customer_name"] = "Direct Buyer"

        for it in payload_dict.get("items", []):
            if not it.get("item_name") and it.get("item_id"):
                if _is_uuid(it["item_id"]):
                    item_rows = await exec_sql("SELECT item_name, sku, unit, selling_price, purchase_price FROM public.inventory_items WHERE id = %s::UUID LIMIT 1;", (it["item_id"],))
                    if item_rows:
                        it["item_name"] = item_rows[0]["item_name"]
                        if not it.get("sku"):
                            it["sku"] = item_rows[0].get("sku", "")
                        if not it.get("unit"):
                            it["unit"] = item_rows[0].get("unit", "Pcs")
                        if not it.get("unit_price"):
                            sp = item_rows[0].get("selling_price")
                            it["unit_price"] = float(sp) if sp else float(item_rows[0].get("purchase_price", 0))
                else:
                    it["item_name"] = str(it["item_id"])
            elif not it.get("item_name"):
                it["item_name"] = "General Item"
        sql = "SELECT public.fn_inventory_create_sales_order(%s::UUID, %s::JSONB, %s::UUID) AS res;"
        rows = await exec_sql(sql, (school_id, json.dumps(payload_dict), user_id))
        if rows and rows[0].get("res"):
            res = rows[0]["res"]
            if not res.get("success"):
                raise HTTPException(status_code=400, detail=res.get("error"))
            return _serialize_val(res)
        raise HTTPException(status_code=500, detail="Database function error")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Inventory] Create sales order error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))




@router.post("/sales-orders/{so_id}/fulfill")
async def fulfill_sales_order(
    so_id: str,
    payload: FulfillSalesOrderRequest,
    user=Depends(get_current_user),
):
    """Fulfill (Deliver) or Cancel a sales order with stock ledger deduction or reservation release."""
    school_id = _get_school_id(user)
    user_id = _get_user_id(user)
    try:
        act = payload.action.lower() if payload and payload.action else "deliver"
        if act in ("deliver", "fulfill", "delivery", "completed"):
            act = "deliver"
        elif act in ("cancel", "cancelled"):
            act = "cancel"
        sql = "SELECT public.fn_inventory_fulfill_sales_order(%s::UUID, %s::UUID, %s, %s::UUID) AS res;"
        rows = await exec_sql(sql, (school_id, so_id, act, user_id))
        if rows and rows[0].get("res"):
            res = rows[0]["res"]
            if not res.get("success"):
                raise HTTPException(status_code=400, detail=res.get("error"))
            return _serialize_val(res)
        raise HTTPException(status_code=500, detail="Database function error")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Inventory] Fulfill sales order error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/sales-orders/{so_id}")
async def get_sales_order_by_id(
    so_id: str,
    user=Depends(get_current_user),
):
    """Retrieve full sales order details including line items, customer classification, and billing attributes."""
    school_id = _get_school_id(user)
    try:
        if _is_uuid(so_id):
            so_rows = await exec_sql(
                "SELECT * FROM public.inventory_sales_orders WHERE id = %s::UUID AND school_id = %s::UUID LIMIT 1;",
                (so_id, school_id)
            )
        else:
            so_rows = await exec_sql(
                "SELECT * FROM public.inventory_sales_orders WHERE so_number = %s AND school_id = %s::UUID LIMIT 1;",
                (so_id, school_id)
            )
        
        if not so_rows:
            so_rows = await exec_sql(
                "SELECT * FROM public.inventory_sales_orders WHERE id = %s::UUID OR so_number = %s LIMIT 1;"
                if _is_uuid(so_id) else "SELECT * FROM public.inventory_sales_orders WHERE so_number = %s LIMIT 1;",
                (so_id, so_id) if _is_uuid(so_id) else (so_id,)
            )

        if not so_rows:
            raise HTTPException(status_code=404, detail=f"Sales order '{so_id}' not found.")
        
        so = dict(so_rows[0])
        actual_id = str(so["id"])
        items = await exec_sql(
            "SELECT * FROM public.inventory_sales_order_items WHERE so_id = %s::UUID ORDER BY created_at ASC;",
            (actual_id,)
        )
        so["items"] = items or []
        return {"success": True, "sales_order": _serialize_val(so)}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Inventory] Get sales order error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/sales-orders/{so_id}")
async def update_sales_order(
    so_id: str,
    payload: UpdateSalesOrderRequest,
    user=Depends(get_current_user),
):
    """Update sales order details, customer info, fulfillment dates, payment terms, notes, terms, and line items."""
    school_id = _get_school_id(user)
    try:
        if _is_uuid(so_id):
            so_rows = await exec_sql(
                "SELECT * FROM public.inventory_sales_orders WHERE id = %s::UUID AND school_id = %s::UUID LIMIT 1;",
                (so_id, school_id)
            )
        else:
            so_rows = await exec_sql(
                "SELECT * FROM public.inventory_sales_orders WHERE so_number = %s AND school_id = %s::UUID LIMIT 1;",
                (so_id, school_id)
            )
        
        if not so_rows:
            so_rows = await exec_sql(
                "SELECT * FROM public.inventory_sales_orders WHERE id = %s::UUID OR so_number = %s LIMIT 1;"
                if _is_uuid(so_id) else "SELECT * FROM public.inventory_sales_orders WHERE so_number = %s LIMIT 1;",
                (so_id, so_id) if _is_uuid(so_id) else (so_id,)
            )

        if not so_rows:
            raise HTTPException(status_code=404, detail=f"Sales order '{so_id}' not found.")

        current_so = dict(so_rows[0])
        actual_id = str(current_so["id"])
        data = payload.dict(exclude_unset=True)

        customer_name = data.get("customer_name")
        customer_id = data.get("customer_id") if _is_uuid(data.get("customer_id")) else None
        customer_type = data.get("customer_type")
        customer_gstin = data.get("customer_gstin")
        contact_phone = data.get("contact_phone")
        contact_email = data.get("contact_email")
        delivery_date = data.get("delivery_date") or data.get("expected_delivery_date")
        store_id = data.get("store_id") if _is_uuid(data.get("store_id")) else None
        department = data.get("department")
        shipping_address = data.get("shipping_address")
        payment_terms = data.get("payment_terms")
        notes = data.get("notes")
        terms_conditions = data.get("terms_conditions")
        order_status = data.get("status")

        items = data.get("items")
        subtotal = data.get("subtotal")
        tax_amount = data.get("tax_amount")
        discount_amount = data.get("discount_amount")
        total_amount = data.get("total_amount")

        if items is not None:
            del_sql = "DELETE FROM public.inventory_sales_order_items WHERE so_id = %s::UUID;"
            await exec_sql(del_sql, (actual_id,), fetch=False)
            
            calc_subtotal = 0.0
            calc_tax = 0.0
            for it in items:
                it_name = it.get("item_name") or "Standard Item"
                it_sku = it.get("sku") or ""
                it_unit = it.get("unit") or "Pcs"
                it_qty = float(it.get("quantity") or 1.0)
                it_price = float(it.get("unit_price") or 0.0)
                it_tax_rate = float(it.get("tax_rate") or 5.0)
                it_total = it.get("total_price")
                if it_total is None:
                    it_total = it_qty * it_price
                else:
                    it_total = float(it_total)
                
                calc_subtotal += it_total
                calc_tax += (it_total * it_tax_rate / 100.0)
                
                item_id_val = it.get("item_id") if _is_uuid(it.get("item_id")) else None
                ins_item = """
                    INSERT INTO public.inventory_sales_order_items (
                        id, school_id, so_id, item_id, item_name, sku, unit, quantity_ordered, quantity_fulfilled, unit_price, tax_rate, line_total, created_at
                    ) VALUES (
                        gen_random_uuid(), %s::UUID, %s::UUID, %s, %s, %s, %s, %s, 0.0, %s, %s, %s, NOW()
                    );
                """
                await exec_sql(ins_item, (school_id, actual_id, item_id_val, it_name, it_sku, it_unit, it_qty, it_price, it_tax_rate, it_total), fetch=False)
            
            if subtotal is None:
                subtotal = calc_subtotal
            if tax_amount is None:
                tax_amount = calc_tax
            if discount_amount is None:
                discount_amount = float(current_so.get("discount_amount") or 0.0)
            if total_amount is None:
                total_amount = max(0.0, subtotal + tax_amount - discount_amount)

        upd_fields = ["updated_at = NOW()"]
        upd_params = []

        if customer_name is not None:
            upd_fields.append("customer_name = %s")
            upd_params.append(customer_name)
        if customer_id is not None:
            upd_fields.append("customer_id = %s::UUID")
            upd_params.append(customer_id)
        if customer_type is not None:
            upd_fields.append("customer_type = %s")
            upd_params.append(customer_type)
        if customer_gstin is not None:
            upd_fields.append("customer_gstin = %s")
            upd_params.append(customer_gstin)
        if contact_phone is not None:
            upd_fields.append("contact_phone = %s")
            upd_params.append(contact_phone)
        if contact_email is not None:
            upd_fields.append("contact_email = %s")
            upd_params.append(contact_email)
        if store_id is not None:
            upd_fields.append("store_id = %s::UUID")
            upd_params.append(store_id)
        if department is not None:
            upd_fields.append("department = %s")
            upd_params.append(department)
        if shipping_address is not None:
            upd_fields.append("shipping_address = %s")
            upd_params.append(shipping_address)
        if payment_terms is not None:
            upd_fields.append("payment_terms = %s")
            upd_params.append(payment_terms)
        if delivery_date is not None:
            upd_fields.append("delivery_date = %s::DATE")
            upd_params.append(delivery_date)
        if notes is not None:
            upd_fields.append("notes = %s")
            upd_params.append(notes)
        if terms_conditions is not None:
            upd_fields.append("terms_conditions = %s")
            upd_params.append(terms_conditions)
        if order_status is not None:
            upd_fields.append("status = %s")
            upd_params.append(order_status)
        if subtotal is not None:
            upd_fields.append("subtotal = %s")
            upd_params.append(subtotal)
        if tax_amount is not None:
            upd_fields.append("tax_amount = %s")
            upd_params.append(tax_amount)
        if discount_amount is not None:
            upd_fields.append("discount_amount = %s")
            upd_params.append(discount_amount)
        if total_amount is not None:
            upd_fields.append("total_amount = %s")
            upd_params.append(total_amount)
        if items is not None:
            upd_fields.append("total_items = %s")
            upd_params.append(len(items))

        upd_sql = f"UPDATE public.inventory_sales_orders SET {', '.join(upd_fields)} WHERE id = %s::UUID RETURNING *;"
        upd_params.append(actual_id)
        res_rows = await exec_sql(upd_sql, tuple(upd_params))
        updated_so = dict(res_rows[0]) if res_rows else current_so

        updated_items = await exec_sql(
            "SELECT * FROM public.inventory_sales_order_items WHERE so_id = %s::UUID ORDER BY created_at ASC;",
            (actual_id,)
        )
        updated_so["items"] = updated_items or []
        return {
            "success": True,
            "message": "Sales order updated successfully",
            "sales_order": _serialize_val(updated_so)
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Inventory] Update sales order error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/sales-orders/{so_id}/cancel")
async def cancel_sales_order(
    so_id: str,
    payload: CancelOrderRequest = CancelOrderRequest(),
    user=Depends(get_current_user),
):
    """Cancel a pending sales order and release reserved stock balances."""
    school_id = _get_school_id(user)
    try:
        actual_id = so_id
        if not _is_uuid(so_id):
            row = await exec_sql("SELECT id FROM public.inventory_sales_orders WHERE so_number = %s AND school_id = %s::UUID LIMIT 1;", (so_id, school_id))
            if not row:
                raise HTTPException(status_code=404, detail=f"Sales order '{so_id}' not found.")
            actual_id = str(row[0]["id"])
        
        sql = "SELECT public.fn_inventory_cancel_sales_order(%s::UUID, %s::UUID, %s) AS res;"
        rows = await exec_sql(sql, (school_id, actual_id, payload.reason or "Cancelled by authority"))
        if rows and rows[0].get("res"):
            res = rows[0]["res"]
            if not res.get("success"):
                raise HTTPException(status_code=400, detail=res.get("error"))
            return _serialize_val(res)
        raise HTTPException(status_code=500, detail="Cancellation function error")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Inventory] Cancel sales order error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/sales-orders/{so_id}/pdf")
async def download_sales_order_pdf(
    so_id: str,
    user=Depends(get_current_user),
):
    """Generate and download a high-resolution, print-ready Sales Order Tax Invoice PDF."""
    school_id = _get_school_id(user)
    try:
        # 1. Fetch order details (supporting both UUID and so_number)
        if _is_uuid(so_id):
            so_rows = await exec_sql(
                "SELECT * FROM public.inventory_sales_orders WHERE id = %s::UUID AND school_id = %s::UUID LIMIT 1;",
                (so_id, school_id)
            )
        else:
            so_rows = await exec_sql(
                "SELECT * FROM public.inventory_sales_orders WHERE so_number = %s AND school_id = %s::UUID LIMIT 1;",
                (so_id, school_id)
            )
        
        if not so_rows:
            so_rows = await exec_sql(
                "SELECT * FROM public.inventory_sales_orders WHERE id = %s::UUID OR so_number = %s LIMIT 1;"
                if _is_uuid(so_id) else "SELECT * FROM public.inventory_sales_orders WHERE so_number = %s LIMIT 1;",
                (so_id, so_id) if _is_uuid(so_id) else (so_id,)
            )

        if not so_rows:
            raise HTTPException(status_code=404, detail=f"Sales order {so_id} not found.")

        order = dict(so_rows[0])
        real_so_id = order["id"]

        # 2. Fetch line items
        it_rows = await exec_sql(
            "SELECT * FROM public.inventory_sales_order_items WHERE so_id = %s::UUID ORDER BY created_at ASC;",
            (real_so_id,)
        )
        items = [dict(r) for r in (it_rows or [])]

        # 3. Generate PDF
        pdf_bytes = generate_sales_order_invoice_pdf(order, items)
        filename = f"Invoice-{order.get('so_number', 'SO')}.pdf"

        return Response(
            content=pdf_bytes,
            media_type="application/pdf",
            headers={
                "Content-Disposition": f'attachment; filename="{filename}"',
                "Content-Type": "application/pdf"
            }
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Inventory] Download SO PDF error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


# ----------------------------------------------------------------------------
# 7. EXPORT ENDPOINTS (CSV / EXCEL DATA DUMP)
# ----------------------------------------------------------------------------
@router.get("/export/{entity}")
async def export_inventory_data(
    entity: str,
    ids: Optional[str] = Query(None, description="Optional comma-separated IDs to export only selected rows"),
    user=Depends(get_current_user),
):
    """Export tabular datasets (items, transactions, purchase-orders, sales-orders) into CSV."""
    school_id = _get_school_id(user)
    output = io.StringIO()
    writer = csv.writer(output)
    
    id_list = [x.strip() for x in ids.split(",") if x.strip()] if ids else None

    try:
        if entity == "items":
            writer.writerow(["SKU", "Item Name", "Category", "Unit", "Current Stock", "Min Stock", "Purchase Price", "Selling Price", "Status"])
            if id_list:
                sql = "SELECT sku, item_name, category, unit, min_stock, purchase_price, selling_price, status FROM public.inventory_items WHERE school_id = %s::UUID AND id = ANY(%s::UUID[]) ORDER BY item_name ASC;"
                rows = await exec_sql(sql, (school_id, id_list))
            else:
                sql = "SELECT sku, item_name, category, unit, min_stock, purchase_price, selling_price, status FROM public.inventory_items WHERE school_id = %s::UUID ORDER BY item_name ASC;"
                rows = await exec_sql(sql, (school_id,))
            for r in rows:
                writer.writerow([r['sku'], r['item_name'], r['category'], r['unit'], r.get('min_stock', 10), r['min_stock'], r['purchase_price'], r['selling_price'], r['status']])
            filename = "inventory_items_report.csv"

        elif entity == "transactions":
            writer.writerow(["Transaction ID", "Date", "Type", "Item", "Quantity", "Rate", "Total", "Location", "Remarks"])
            if id_list:
                sql = """
                    SELECT m.movement_number, m.created_at, m.transaction_type, i.item_name, m.quantity, m.unit_rate, m.total_value, m.location_name, m.remarks
                    FROM public.inventory_stock_movements m
                    JOIN public.inventory_items i ON m.item_id = i.id
                    WHERE m.school_id = %s::UUID AND m.id = ANY(%s::UUID[]) ORDER BY m.created_at DESC;
                """
                rows = await exec_sql(sql, (school_id, id_list))
            else:
                sql = """
                    SELECT m.movement_number, m.created_at, m.transaction_type, i.item_name, m.quantity, m.unit_rate, m.total_value, m.location_name, m.remarks
                    FROM public.inventory_stock_movements m
                    JOIN public.inventory_items i ON m.item_id = i.id
                    WHERE m.school_id = %s::UUID ORDER BY m.created_at DESC;
                """
                rows = await exec_sql(sql, (school_id,))
            for r in rows:
                writer.writerow([r['movement_number'], r['created_at'].strftime('%Y-%m-%d %H:%M'), r['transaction_type'], r['item_name'], r['quantity'], r['unit_rate'], r['total_value'], r['location_name'], r['remarks']])
            filename = "inventory_transactions_report.csv"

        elif entity in ("purchase-orders", "purchases"):
            writer.writerow(["PO Number", "Date", "Supplier", "Items Count", "Total Amount", "Status", "Delivery Date"])
            if id_list:
                sql = "SELECT po_number, order_date, supplier_name, total_items, total_amount, status, delivery_date FROM public.inventory_purchase_orders WHERE school_id = %s::UUID AND id = ANY(%s::UUID[]) ORDER BY order_date DESC;"
                rows = await exec_sql(sql, (school_id, id_list))
            else:
                sql = "SELECT po_number, order_date, supplier_name, total_items, total_amount, status, delivery_date FROM public.inventory_purchase_orders WHERE school_id = %s::UUID ORDER BY order_date DESC;"
                rows = await exec_sql(sql, (school_id,))
            for r in rows:
                writer.writerow([r['po_number'], r['order_date'], r['supplier_name'], r['total_items'], r['total_amount'], r['status'], r['delivery_date']])
            filename = "purchase_orders_report.csv"

        elif entity in ("sales-orders", "sales"):
            writer.writerow(["SO Number", "Date", "Customer", "Items Count", "Total Amount", "Status", "Delivery Date"])
            if id_list:
                sql = "SELECT so_number, order_date, customer_name, total_items, total_amount, status, delivery_date FROM public.inventory_sales_orders WHERE school_id = %s::UUID AND id = ANY(%s::UUID[]) ORDER BY order_date DESC;"
                rows = await exec_sql(sql, (school_id, id_list))
            else:
                sql = "SELECT so_number, order_date, customer_name, total_items, total_amount, status, delivery_date FROM public.inventory_sales_orders WHERE school_id = %s::UUID ORDER BY order_date DESC;"
                rows = await exec_sql(sql, (school_id,))
            for r in rows:
                writer.writerow([r['so_number'], r['order_date'], r['customer_name'], r['total_items'], r['total_amount'], r['status'], r['delivery_date']])
            filename = "sales_orders_report.csv"
        else:
            raise HTTPException(status_code=400, detail=f"Unsupported entity type: {entity}")

        output.seek(0)
        return StreamingResponse(
            io.BytesIO(output.getvalue().encode('utf-8-sig')),
            media_type="text/csv",
            headers={"Content-Disposition": f"attachment; filename={filename}"}
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Inventory] Export error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


