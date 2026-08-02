from fastapi import APIRouter, Depends, HTTPException, Query
from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel

from app.middleware.auth import get_current_user, require_any_role
from app.services.supabase_client import get_supabase

router = APIRouter()

require_super_admin_or_director = require_any_role("super_admin", "director")

# ===========================================================
# Schemas
# ===========================================================
class AnnouncementCreate(BaseModel):
    title: str
    description: Optional[str] = None
    audience: List[str]
    school_id: Optional[str] = None # NULL means 'All Institutions'
    priority: Optional[str] = "Medium"
    status: Optional[str] = "Draft"
    scheduled_at: Optional[datetime] = None
    published_at: Optional[datetime] = None
    expires_at: Optional[datetime] = None

class AnnouncementUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    audience: Optional[List[str]] = None
    school_id: Optional[str] = None
    priority: Optional[str] = None
    status: Optional[str] = None
    scheduled_at: Optional[datetime] = None
    published_at: Optional[datetime] = None
    expires_at: Optional[datetime] = None

# ===========================================================
# Endpoints (Using Unified notifications table)
# ===========================================================

@router.get("/stats")
async def get_announcement_stats(user=Depends(require_super_admin_or_director)):
    sb = get_supabase()
    try:
        res = await sb.table("notifications").select("id, status").eq("category", "announcement").aexecute()
        rows = res.data or []
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database query failed: {e}")

    total = len(rows)
    published = sum(1 for r in rows if r.get("status") == "Published")
    draft = sum(1 for r in rows if r.get("status") == "Draft")

    return {
        "success": True,
        "data": {
            "total": total,
            "published": published,
            "scheduled": 0,
            "draft": draft,
            "expired": 0,
            "audience_breakdown": {"All": total}
        }
    }

from app.utils.sanitizer import sanitize_search_input

@router.get("")
async def list_announcements(
    status: Optional[str] = Query(None),
    priority: Optional[str] = Query(None),
    audience: Optional[str] = Query(None),
    school_id: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    user=Depends(require_super_admin_or_director)
):
    sb = get_supabase()
    q = sb.table("notifications").select("*").eq("category", "announcement").count("exact")

    if school_id and school_id != "All Institutions":
        if school_id != "Global":
            q = q.eq("school_id", school_id)

    if search:
        clean_search = sanitize_search_input(search)
        if clean_search:
            search_escaped = f"%{clean_search}%"
            q = q.or_(f"title.ilike.{search_escaped},message.ilike.{search_escaped}")

    offset = (page - 1) * page_size

    q = q.order("created_at", ascending=False).limit(page_size).offset(offset)

    try:
        res = await q.aexecute()
        announcements = res.data or []
        total_records = res.count or len(announcements)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database query failed: {e}")

    return {
        "success": True,
        "data": {
            "announcements": announcements,
            "total_records": total_records
        }
    }

@router.post("")
async def create_announcement(announcement: AnnouncementCreate, user=Depends(require_super_admin_or_director)):
    sb = get_supabase()

    payload = {
        "title": announcement.title,
        "message": announcement.description or announcement.title,
        "category": "announcement",
        "school_id": announcement.school_id,
        "is_read": False,
        "created_at": datetime.utcnow().isoformat()
    }

    try:
        res = await sb.table("notifications").insert(payload).aexecute()
        if not res.data:
            raise HTTPException(status_code=500, detail="Failed to create announcement")
        return {"success": True, "data": res.data[0]}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database write failed: {e}")

@router.put("/{id}")
async def update_announcement(id: str, announcement: AnnouncementUpdate, user=Depends(require_super_admin_or_director)):
    sb = get_supabase()

    payload = {}
    if announcement.title is not None:
        payload["title"] = announcement.title
    if announcement.description is not None:
        payload["message"] = announcement.description
    if announcement.school_id is not None:
        payload["school_id"] = announcement.school_id

    payload["updated_at"] = datetime.utcnow().isoformat()

    try:
        res = await sb.table("notifications").update(payload).eq("id", id).aexecute()
        if not res.data:
            raise HTTPException(status_code=500, detail="Failed to update announcement")
        return {"success": True, "data": res.data[0]}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database write failed: {e}")

@router.delete("/{id}")
async def delete_announcement(id: str, user=Depends(require_super_admin_or_director)):
    sb = get_supabase()
    try:
        await sb.table("notifications").delete().eq("id", id).aexecute()
        return {"success": True, "message": "Announcement deleted successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database delete failed: {e}")
