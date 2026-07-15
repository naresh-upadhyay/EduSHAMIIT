from fastapi import APIRouter, Depends, HTTPException, Query
from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel

from app.middleware.auth import require_any_role
from app.services.supabase_client import get_supabase

router = APIRouter()

require_super_admin_or_director = require_any_role("super_admin", "director", "admin")

# ===========================================================
# Schemas
# ===========================================================
class ContactQueryCreate(BaseModel):
    full_name: str
    email: str
    subject: str
    message: str

class ContactQueryUpdate(BaseModel):
    status: str
    response: Optional[str] = None

# ===========================================================
# Public Endpoints
# ===========================================================
@router.post("/submit")
async def submit_contact_query(payload: ContactQueryCreate):
    sb = get_supabase()
    try:
        data = {
            "full_name": payload.full_name,
            "email": payload.email,
            "subject": payload.subject,
            "message": payload.message,
            "status": "Pending"
        }
        res = await sb.table("contact_queries").insert(data).aexecute()
        if not res.data:
            raise HTTPException(status_code=500, detail="Failed to submit query")
        return {"success": True, "message": "Query submitted successfully", "data": res.data[0]}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ===========================================================
# Admin Endpoints
# ===========================================================
@router.get("/admin/queries")
async def list_contact_queries(
    status: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    user=Depends(require_super_admin_or_director)
):
    sb = get_supabase()
    try:
        q = sb.table("contact_queries").select("*", count="exact")
        
        if status:
            q = q.eq("status", status)
            
        if search:
            q = q.or_(f"full_name.ilike.%{search}%,email.ilike.%{search}%,subject.ilike.%{search}%,message.ilike.%{search}%")
            
        q = q.order("created_at", ascending=False)
        
        offset = (page - 1) * page_size
        q = q.limit(page_size).offset(offset)
        
        res = await q.aexecute()
        return {
            "success": True,
            "data": res.data or [],
            "total": res.count or 0,
            "page": page,
            "page_size": page_size
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/admin/queries/{query_id}")
async def update_contact_query(
    query_id: str,
    payload: ContactQueryUpdate,
    user=Depends(require_super_admin_or_director)
):
    sb = get_supabase()
    try:
        update_data = {
            "status": payload.status,
            "updated_at": datetime.utcnow().isoformat() + "Z"
        }
        if payload.response is not None:
            update_data["response"] = payload.response
            
        res = await sb.table("contact_queries").update(update_data).eq("id", query_id).aexecute()
        if not res.data:
            raise HTTPException(status_code=404, detail="Query not found")
        return {"success": True, "message": "Query updated successfully", "data": res.data[0]}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
