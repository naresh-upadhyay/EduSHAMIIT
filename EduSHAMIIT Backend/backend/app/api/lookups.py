"""
Universal Enterprise Lookup Management API for EduSHAMIIT ERP.
Multi-tenant, independent Key -> Multiple Values engine with Creator-Based Ownership,
Auditing, Optimistic Concurrency, Bulk Imports/Exports, Usage Safety, and Generic Module Resolution.
"""
from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any, Union
from datetime import datetime, date, time
import json
import uuid
import logging
import asyncio
import psycopg2
from psycopg2.extras import RealDictCursor

from app.config import settings
from app.middleware.auth import get_current_user, require_school_id

logger = logging.getLogger(__name__)
router = APIRouter()


# ============================================================================
# HELPER FUNCTIONS & DATABASE EXECUTION
# ============================================================================

async def exec_sql(sql: str, params: tuple = (), fetch: bool = True) -> List[Dict[str, Any]]:
    """Execute raw parameterized SQL query asynchronously via psycopg2."""
    def _run():
        conn = psycopg2.connect(settings.DATABASE_URL, connect_timeout=5)
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(sql, params)
                if fetch:
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


def _serialize_datetime(val: Any) -> Any:
    """Format dates, datetimes, and UUIDs for clean JSON serialization."""
    if isinstance(val, (datetime, date, time)):
        return val.isoformat()
    if isinstance(val, uuid.UUID):
        return str(val)
    if isinstance(val, dict):
        return {k: _serialize_datetime(v) for k, v in val.items()}
    if isinstance(val, list):
        return [_serialize_datetime(item) for item in val]
    return val


# ============================================================================
# REQUEST & RESPONSE SCHEMAS
# ============================================================================

class LookupValueInitialItem(BaseModel):
    value_name: str
    value_code: Optional[str] = None
    description: Optional[str] = None
    status: Optional[str] = "ACTIVE"
    sort_order: Optional[int] = None


class LookupKeyCreateRequest(BaseModel):
    key_name: str
    key_code: Optional[str] = None
    description: Optional[str] = None
    key_type: Optional[str] = "CUSTOM"  # 'SYSTEM', 'CUSTOM'
    icon: Optional[str] = "folder_outlined"
    status: Optional[str] = "ACTIVE"
    initial_values: Optional[List[LookupValueInitialItem]] = None


class LookupKeyUpdateRequest(BaseModel):
    key_name: Optional[str] = None
    description: Optional[str] = None
    icon: Optional[str] = None
    status: Optional[str] = None
    version: Optional[int] = None


class LookupValueCreateRequest(BaseModel):
    value_name: str
    value_code: Optional[str] = None
    description: Optional[str] = None
    status: Optional[str] = "ACTIVE"
    sort_order: Optional[int] = None


class LookupValueUpdateRequest(BaseModel):
    value_name: Optional[str] = None
    description: Optional[str] = None
    status: Optional[str] = None
    sort_order: Optional[int] = None


class LookupValueBulkCreateRequest(BaseModel):
    values: List[Dict[str, Any]]


class LookupReorderRequest(BaseModel):
    ordered_value_ids: List[str]


class LookupImportRequest(BaseModel):
    csv_content: Optional[str] = None
    values: Optional[List[Dict[str, Any]]] = None


# ============================================================================
# API ENDPOINTS
# ============================================================================

# ----------------------------------------------------------------------------
# 1. Generic Module Lookup Code Resolver (Read-Heavy / Public to ERP Modules)
# ----------------------------------------------------------------------------
@router.get("/code/{key_code}")
async def get_lookup_by_code(
    key_code: str,
    include_inactive: bool = Query(False, description="Include inactive values"),
    school_id=Depends(require_school_id),
):
    """
    Generic lookup resolver for any ERP module (Calendar, Transport, Notices, Users).
    Returns active key-values sorted by sort_order.
    """
    try:
        sql = "SELECT public.fn_get_lookup_by_code(%s::UUID, %s, %s::BOOLEAN) AS result;"
        rows = await exec_sql(sql, (school_id, key_code, include_inactive))
        if rows and rows[0].get("result"):
            res = rows[0]["result"]
            if not res.get("success"):
                raise HTTPException(status_code=404, detail=res.get("error", "Lookup key not found"))
            return _serialize_datetime(res)
        raise HTTPException(status_code=404, detail="Lookup key not found")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Lookups] Failed to resolve code {key_code}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


# ----------------------------------------------------------------------------
# 2. Export All Lookups to CSV
# ----------------------------------------------------------------------------
@router.get("/export/all")
async def export_all_lookups(
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Export all lookup keys and values for the institution into a standardized CSV."""
    try:
        sql = """
            SELECT 
                k.key_name,
                k.key_code,
                k.key_type,
                k.status AS key_status,
                v.value_name,
                v.value_code,
                v.status AS value_status,
                v.sort_order,
                COALESCE(v.description, '') AS description
            FROM public.lookup_keys k
            LEFT JOIN public.lookup_values v ON v.lookup_key_id = k.id AND v.deleted_at IS NULL
            WHERE k.school_id = %s::UUID AND k.deleted_at IS NULL
            ORDER BY k.key_name ASC, v.sort_order ASC;
        """
        rows = await exec_sql(sql, (school_id,))
        lines = ["key_name,key_code,key_type,key_status,value_name,value_code,value_status,sort_order,description"]
        for r in rows:
            lines.append(
                f'"{r.get("key_name","")}","{r.get("key_code","")}","{r.get("key_type","")}","{r.get("key_status","")}","{r.get("value_name") or ""}","{r.get("value_code") or ""}","{r.get("value_status") or ""}","{r.get("sort_order") or 0}","{r.get("description") or ""}"'
            )
        csv_content = "\n".join(lines)
        return Response(
            content=csv_content,
            media_type="text/csv",
            headers={"Content-Disposition": f"attachment; filename=all_lookups_{datetime.now().strftime('%Y%m%d')}.csv"}
        )
    except Exception as e:
        logger.error(f"[Lookups] Failed to export all lookups: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


# ----------------------------------------------------------------------------
# 3. List Paginated Lookup Keys (Search, Filter, Tab, Ownership)
# ----------------------------------------------------------------------------
@router.get("")
@router.get("/")
async def get_lookup_keys(
    tab: str = Query("all", description="Tab filter: all, active, inactive, system, custom"),
    search: str = Query("", description="Search term for key name, code, description"),
    status: str = Query("", description="Status filter: ACTIVE, INACTIVE"),
    created_by: str = Query("all", description="Created by filter: all, my_keys, others, system"),
    key_type: str = Query("", description="Key type: SYSTEM, CUSTOM"),
    sort_by: str = Query("created_at", description="Sort field"),
    sort_order: str = Query("DESC", description="Sort direction"),
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(10, ge=1, le=100, description="Page size"),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Retrieve paginated lookup keys matching search, tabs, filters, and user context."""
    user_id = user.get("id")
    try:
        sql = "SELECT public.fn_get_lookup_keys(%s::UUID, %s::UUID, %s, %s, %s, %s, %s, %s::INT, %s::INT, %s, %s) AS result;"
        rows = await exec_sql(sql, (
            school_id, user_id, tab, search, status, created_by, key_type, page, page_size, sort_by, sort_order
        ))
        if rows and rows[0].get("result"):
            return _serialize_datetime(rows[0]["result"])
        return {"success": True, "page": page, "page_size": page_size, "total_records": 0, "total_pages": 0, "data": []}
    except Exception as e:
        logger.error(f"[Lookups] Failed to fetch lookup keys: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


# ----------------------------------------------------------------------------
# 4. Create Lookup Key + Optional Initial Values
# ----------------------------------------------------------------------------
@router.post("")
@router.post("/")
async def create_lookup_key(
    req: LookupKeyCreateRequest,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Create a new lookup key and optional initial values."""
    user_id = user.get("id")
    payload = req.dict()
    try:
        sql = "SELECT public.fn_create_lookup_key(%s::UUID, %s::UUID, %s::JSONB) AS result;"
        rows = await exec_sql(sql, (school_id, user_id, json.dumps(payload)))
        if rows and rows[0].get("result"):
            res = rows[0]["result"]
            if not res.get("success"):
                status_code = res.get("code", 400)
                raise HTTPException(status_code=status_code, detail=res.get("error", "Failed to create lookup key"))
            return _serialize_datetime(res)
        raise HTTPException(status_code=500, detail="Failed to create lookup key")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Lookups] Failed to create lookup key: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


# ----------------------------------------------------------------------------
# 5. Get Lookup Key Detail & Statistics
# ----------------------------------------------------------------------------
@router.get("/{lookup_id}")
async def get_lookup_key_detail(
    lookup_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Get single lookup key detail, creator info, KPI stats, and cross-module usage."""
    user_id = user.get("id")
    try:
        sql = "SELECT public.fn_get_lookup_key_detail(%s::UUID, %s::UUID, %s::UUID) AS result;"
        rows = await exec_sql(sql, (school_id, user_id, lookup_id))
        if rows and rows[0].get("result"):
            res = rows[0]["result"]
            if not res.get("success"):
                raise HTTPException(status_code=404, detail=res.get("error", "Lookup key not found"))
            return _serialize_datetime(res)
        raise HTTPException(status_code=404, detail="Lookup key not found")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Lookups] Failed to fetch lookup detail: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


# ----------------------------------------------------------------------------
# 6. Update Lookup Key (Creator Ownership & Version Lock Enforced)
# ----------------------------------------------------------------------------
@router.patch("/{lookup_id}")
async def update_lookup_key(
    lookup_id: str,
    req: LookupKeyUpdateRequest,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Update lookup key metadata (Creator/Owner only, with optimistic locking)."""
    user_id = user.get("id")
    payload = {k: v for k, v in req.dict().items() if v is not None}
    version = req.version
    try:
        sql = "SELECT public.fn_update_lookup_key(%s::UUID, %s::UUID, %s::UUID, %s::JSONB, %s::INT) AS result;"
        rows = await exec_sql(sql, (school_id, user_id, lookup_id, json.dumps(payload), version))
        if rows and rows[0].get("result"):
            res = rows[0]["result"]
            if not res.get("success"):
                status_code = res.get("code", 400)
                raise HTTPException(status_code=status_code, detail=res.get("error", "Failed to update lookup key"))
            return _serialize_datetime(res)
        raise HTTPException(status_code=500, detail="Failed to update lookup key")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Lookups] Failed to update lookup key: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


# ----------------------------------------------------------------------------
# 7. Delete / Deactivate Lookup Key (Creator Ownership & Usage Check Enforced)
# ----------------------------------------------------------------------------
@router.delete("/{lookup_id}")
async def delete_lookup_key(
    lookup_id: str,
    force_deactivate: bool = Query(False, description="Deactivate instead of deleting if in use"),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Delete or deactivate lookup key (Creator/Owner only, checks cross-module usage)."""
    user_id = user.get("id")
    try:
        sql = "SELECT public.fn_delete_lookup_key(%s::UUID, %s::UUID, %s::UUID, %s::BOOLEAN) AS result;"
        rows = await exec_sql(sql, (school_id, user_id, lookup_id, force_deactivate))
        if rows and rows[0].get("result"):
            res = rows[0]["result"]
            if not res.get("success"):
                status_code = res.get("code", 400)
                raise HTTPException(status_code=status_code, detail=res.get("error", "Failed to delete lookup key"))
            return _serialize_datetime(res)
        raise HTTPException(status_code=500, detail="Failed to delete lookup key")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Lookups] Failed to delete lookup key: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


# ----------------------------------------------------------------------------
# 8. List Values for a Lookup Key
# ----------------------------------------------------------------------------
@router.get("/{lookup_id}/values")
async def get_lookup_values(
    lookup_id: str,
    search: str = Query("", description="Search term for value name, code"),
    status: str = Query("", description="Status filter: ACTIVE, INACTIVE"),
    sort_by: str = Query("sort_order", description="Sort field: sort_order, value_name, value_code"),
    sort_order: str = Query("ASC", description="Sort direction: ASC, DESC"),
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(10, ge=1, le=100, description="Page size"),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Retrieve paginated values for a lookup key with sorting and search."""
    user_id = user.get("id")
    try:
        sql = "SELECT public.fn_get_lookup_values(%s::UUID, %s::UUID, %s::UUID, %s, %s, %s::INT, %s::INT, %s, %s) AS result;"
        rows = await exec_sql(sql, (
            school_id, user_id, lookup_id, search, status, page, page_size, sort_by, sort_order
        ))
        if rows and rows[0].get("result"):
            res = rows[0]["result"]
            if not res.get("success"):
                raise HTTPException(status_code=404, detail=res.get("error", "Lookup Key not found"))
            return _serialize_datetime(res)
        return {"success": True, "page": page, "page_size": page_size, "total_records": 0, "total_pages": 0, "data": []}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Lookups] Failed to fetch lookup values: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


# ----------------------------------------------------------------------------
# 9. Add Single Value to a Lookup Key (Creator Ownership Enforced)
# ----------------------------------------------------------------------------
@router.post("/{lookup_id}/values")
async def create_lookup_value(
    lookup_id: str,
    req: LookupValueCreateRequest,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Add a new value to a lookup key (Creator/Owner only)."""
    user_id = user.get("id")
    payload = req.dict()
    try:
        sql = "SELECT public.fn_create_lookup_value(%s::UUID, %s::UUID, %s::UUID, %s::JSONB) AS result;"
        rows = await exec_sql(sql, (school_id, user_id, lookup_id, json.dumps(payload)))
        if rows and rows[0].get("result"):
            res = rows[0]["result"]
            if not res.get("success"):
                status_code = res.get("code", 400)
                raise HTTPException(status_code=status_code, detail=res.get("error", "Failed to add lookup value"))
            return _serialize_datetime(res)
        raise HTTPException(status_code=500, detail="Failed to add lookup value")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Lookups] Failed to add lookup value: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


# ----------------------------------------------------------------------------
# 10. Bulk Add Values to a Lookup Key (Creator Ownership Enforced)
# ----------------------------------------------------------------------------
@router.post("/{lookup_id}/values/bulk")
async def bulk_create_lookup_values(
    lookup_id: str,
    req: LookupValueBulkCreateRequest,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Batch add multiple values from pasted list or structured array (Creator/Owner only)."""
    user_id = user.get("id")
    try:
        sql = "SELECT public.fn_bulk_create_lookup_values(%s::UUID, %s::UUID, %s::UUID, %s::JSONB) AS result;"
        rows = await exec_sql(sql, (school_id, user_id, lookup_id, json.dumps(req.values)))
        if rows and rows[0].get("result"):
            res = rows[0]["result"]
            if not res.get("success") and not res.get("imported_count"):
                status_code = res.get("code", 400)
                raise HTTPException(status_code=status_code, detail=res.get("error", "Failed to bulk create values"))
            return {
                "success": res.get("success", False),
                "message": f"Successfully imported {res.get('imported_count', 0)} of {res.get('total_rows', 0)} values",
                "data": res
            }
        raise HTTPException(status_code=500, detail="Failed to bulk create values")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Lookups] Failed to bulk create values: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


# ----------------------------------------------------------------------------
# 11. Reorder Values (Drag & Drop Persistence, Creator Ownership Enforced)
# ----------------------------------------------------------------------------
@router.patch("/{lookup_id}/values/reorder")
async def reorder_lookup_values(
    lookup_id: str,
    req: LookupReorderRequest,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Persist new sort order sequence for values in a lookup key (Creator/Owner only)."""
    user_id = user.get("id")
    try:
        sql = "SELECT public.fn_reorder_lookup_values(%s::UUID, %s::UUID, %s::UUID, %s::UUID[]) AS result;"
        rows = await exec_sql(sql, (school_id, user_id, lookup_id, req.ordered_value_ids))
        if rows and rows[0].get("result"):
            res = rows[0]["result"]
            if not res.get("success"):
                status_code = res.get("code", 400)
                raise HTTPException(status_code=status_code, detail=res.get("error", "Failed to reorder values"))
            return _serialize_datetime(res)
        raise HTTPException(status_code=500, detail="Failed to reorder values")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Lookups] Failed to reorder values: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


# ----------------------------------------------------------------------------
# 12. Update Single Value (Creator Ownership Enforced)
# ----------------------------------------------------------------------------
@router.patch("/{lookup_id}/values/{value_id}")
async def update_lookup_value(
    lookup_id: str,
    value_id: str,
    req: LookupValueUpdateRequest,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Update a lookup value's name, description, status, or sort order (Creator/Owner only)."""
    user_id = user.get("id")
    payload = {k: v for k, v in req.dict().items() if v is not None}
    try:
        sql = "SELECT public.fn_update_lookup_value(%s::UUID, %s::UUID, %s::UUID, %s::JSONB) AS result;"
        rows = await exec_sql(sql, (school_id, user_id, value_id, json.dumps(payload)))
        if rows and rows[0].get("result"):
            res = rows[0]["result"]
            if not res.get("success"):
                status_code = res.get("code", 400)
                raise HTTPException(status_code=status_code, detail=res.get("error", "Failed to update value"))
            return _serialize_datetime(res)
        raise HTTPException(status_code=500, detail="Failed to update value")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Lookups] Failed to update value: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


# ----------------------------------------------------------------------------
# 13. Delete / Deactivate Single Value (Creator Ownership & Usage Check Enforced)
# ----------------------------------------------------------------------------
@router.delete("/{lookup_id}/values/{value_id}")
async def delete_lookup_value(
    lookup_id: str,
    value_id: str,
    force_deactivate: bool = Query(False, description="Deactivate instead of deleting if in use"),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Delete or deactivate a single value (Creator/Owner only, checks cross-module usage)."""
    user_id = user.get("id")
    try:
        sql = "SELECT public.fn_delete_lookup_value(%s::UUID, %s::UUID, %s::UUID, %s::BOOLEAN) AS result;"
        rows = await exec_sql(sql, (school_id, user_id, value_id, force_deactivate))
        if rows and rows[0].get("result"):
            res = rows[0]["result"]
            if not res.get("success"):
                status_code = res.get("code", 400)
                raise HTTPException(status_code=status_code, detail=res.get("error", "Failed to delete value"))
            return _serialize_datetime(res)
        raise HTTPException(status_code=500, detail="Failed to delete value")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Lookups] Failed to delete value: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


# ----------------------------------------------------------------------------
# 14. Export Selected Lookup Key Values to CSV
# ----------------------------------------------------------------------------
@router.get("/{lookup_id}/export")
async def export_lookup_key(
    lookup_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Export all values for the selected lookup key as a CSV spreadsheet."""
    try:
        # Fetch Key Name
        key_rows = await exec_sql(
            "SELECT key_name, key_code FROM public.lookup_keys WHERE id = %s::UUID AND school_id = %s::UUID;",
            (lookup_id, school_id)
        )
        if not key_rows:
            raise HTTPException(status_code=404, detail="Lookup key not found")
        
        key_name = key_rows[0]["key_name"]
        key_code = key_rows[0]["key_code"]

        # Fetch Values
        val_rows = await exec_sql(
            "SELECT value_name, value_code, status, sort_order, COALESCE(description, '') AS description "
            "FROM public.lookup_values WHERE lookup_key_id = %s::UUID AND school_id = %s::UUID AND deleted_at IS NULL "
            "ORDER BY sort_order ASC;",
            (lookup_id, school_id)
        )

        lines = ["value_name,value_code,status,sort_order,description"]
        for r in val_rows:
            lines.append(f'"{r["value_name"]}","{r["value_code"]}","{r["status"]}","{r["sort_order"]}","{r["description"]}"')

        csv_content = "\n".join(lines)
        filename = f"{key_code.lower()}_values_{datetime.now().strftime('%Y%m%d')}.csv"
        return Response(
            content=csv_content,
            media_type="text/csv",
            headers={"Content-Disposition": f"attachment; filename={filename}"}
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Lookups] Failed to export lookup key {lookup_id}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


# ----------------------------------------------------------------------------
# 15. Import Values into a Lookup Key from CSV Content
# ----------------------------------------------------------------------------
@router.post("/{lookup_id}/import")
async def import_lookup_values(
    lookup_id: str,
    req: LookupImportRequest,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Import values from raw CSV string or parsed array with validation & error report."""
    user_id = user.get("id")
    values_to_import = []

    if req.values:
        values_to_import = req.values
    elif req.csv_content:
        # Parse CSV lines
        lines = [l.strip() for l in req.csv_content.splitlines() if l.strip()]
        if lines:
            headers = [h.strip().lower() for h in lines[0].split(",")]
            for l in lines[1:]:
                parts = [p.strip().strip('"') for p in l.split(",")]
                if parts and parts[0]:
                    item = {"value_name": parts[0]}
                    if len(parts) > 1 and parts[1]:
                        item["value_code"] = parts[1]
                    if len(parts) > 2 and parts[2]:
                        item["status"] = parts[2]
                    if len(parts) > 3 and parts[3] and parts[3].isdigit():
                        item["sort_order"] = int(parts[3])
                    if len(parts) > 4:
                        item["description"] = parts[4]
                    values_to_import.append(item)

    if not values_to_import:
        raise HTTPException(status_code=400, detail="No values found to import")

    try:
        sql = "SELECT public.fn_bulk_create_lookup_values(%s::UUID, %s::UUID, %s::UUID, %s::JSONB) AS result;"
        rows = await exec_sql(sql, (school_id, user_id, lookup_id, json.dumps(values_to_import)))
        if rows and rows[0].get("result"):
            res = rows[0]["result"]
            if not res.get("success") and not res.get("imported_count"):
                status_code = res.get("code", 400)
                raise HTTPException(status_code=status_code, detail=res.get("error", "Import failed"))
            return {
                "success": res.get("success", False),
                "message": f"Successfully imported {res.get('imported_count', 0)} of {res.get('total_rows', 0)} values",
                "data": res
            }
        raise HTTPException(status_code=500, detail="Import failed")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Lookups] Failed to import values for {lookup_id}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


# ----------------------------------------------------------------------------
# 16. Get Audit Logs Timeline for a Lookup Key
# ----------------------------------------------------------------------------
@router.get("/{lookup_id}/audit-logs")
async def get_lookup_audit_logs(
    lookup_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Retrieve complete audit mutation timeline (action, user, timestamps, diffs) for a lookup key."""
    try:
        sql = "SELECT public.fn_get_lookup_audit_logs(%s::UUID, %s::UUID) AS result;"
        rows = await exec_sql(sql, (school_id, lookup_id))
        if rows and rows[0].get("result"):
            return _serialize_datetime(rows[0]["result"])
        return {"success": True, "data": []}
    except Exception as e:
        logger.error(f"[Lookups] Failed to fetch audit logs for {lookup_id}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))
