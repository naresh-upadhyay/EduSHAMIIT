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
# Endpoints
# ===========================================================

@router.get("/stats")
async def get_announcement_stats(user=Depends(require_super_admin_or_director)):
    sb = get_supabase()
    try:
        res = await sb.table("announcements").select("status, audience").aexecute()
        rows = res.data or []
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database query failed: {e}")

    total = len(rows)
    published = sum(1 for r in rows if r.get("status") == "Published")
    scheduled = sum(1 for r in rows if r.get("status") == "Scheduled")
    draft = sum(1 for r in rows if r.get("status") == "Draft")
    expired = sum(1 for r in rows if r.get("status") == "Expired")

    # Audience breakdown
    breakdown = {}
    for r in rows:
        aud = r.get("audience")
        if aud:
            if isinstance(aud, list):
                for single_aud in aud:
                    if single_aud:
                        aud_label = str(single_aud).capitalize()
                        breakdown[aud_label] = breakdown.get(aud_label, 0) + 1
            else:
                aud_label = str(aud).capitalize()
                breakdown[aud_label] = breakdown.get(aud_label, 0) + 1

    return {
        "success": True,
        "data": {
            "total": total,
            "published": published,
            "scheduled": scheduled,
            "draft": draft,
            "expired": expired,
            "audience_breakdown": breakdown
        }
    }

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
    q = sb.table("announcements").select("*, school:schools(name)").count("exact")

    if status and status != "All Status":
        q = q.eq("status", status)
    if priority and priority != "All Priority":
        q = q.eq("priority", priority)
    if audience and audience != "All Audience":
        q = q.contains("audience", f"{{{audience.lower()}}}")
    if school_id and school_id != "All Institutions":
        if school_id == "Global":
            q = q.is_("school_id", "null")
        else:
            q = q.eq("school_id", school_id)

    if search:
        search_escaped = f"%{search}%"
        q = q.or_(f"title.ilike.{search_escaped},description.ilike.{search_escaped}")

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
        "description": announcement.description,
        "audience": announcement.audience,
        "school_id": announcement.school_id,
        "priority": announcement.priority,
        "status": announcement.status,
        "scheduled_at": announcement.scheduled_at.isoformat() if announcement.scheduled_at else None,
        "published_at": announcement.published_at.isoformat() if announcement.published_at else None,
        "expires_at": announcement.expires_at.isoformat() if announcement.expires_at else None,
        "created_by_id": user.get("id") if isinstance(user, dict) else getattr(user, "id", None)
    }

    if announcement.status == "Published" and not payload["published_at"]:
        payload["published_at"] = datetime.utcnow().isoformat()

    try:
        res = await sb.table("announcements").insert(payload).aexecute()
        if not res.data:
            raise HTTPException(status_code=500, detail="Failed to create announcement")
        return {"success": True, "data": res.data[0]}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database write failed: {e}")

@router.put("/{id}")
async def update_announcement(id: str, announcement: AnnouncementUpdate, user=Depends(require_super_admin_or_director)):
    sb = get_supabase()
    
    # 1. Fetch current announcement
    try:
        current_res = await sb.table("announcements").select("*").eq("id", id).maybe_single().aexecute()
        if not current_res.data:
            raise HTTPException(status_code=404, detail="Announcement not found")
        current = current_res.data
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database read failed: {e}")

    payload = {}
    if announcement.title is not None:
        payload["title"] = announcement.title
    if announcement.description is not None:
        payload["description"] = announcement.description
    if announcement.audience is not None:
        payload["audience"] = announcement.audience
    if announcement.school_id is not None:
        # Allow clearing school_id to make it global by passing None
        payload["school_id"] = announcement.school_id
    if announcement.priority is not None:
        payload["priority"] = announcement.priority
    if announcement.status is not None:
        payload["status"] = announcement.status
        if announcement.status == "Published" and current.get("status") != "Published":
            payload["published_at"] = datetime.utcnow().isoformat()
    if announcement.scheduled_at is not None:
        payload["scheduled_at"] = announcement.scheduled_at.isoformat() if announcement.scheduled_at else None
    if announcement.published_at is not None:
        payload["published_at"] = announcement.published_at.isoformat() if announcement.published_at else None
    if announcement.expires_at is not None:
        payload["expires_at"] = announcement.expires_at.isoformat() if announcement.expires_at else None

    payload["updated_at"] = datetime.utcnow().isoformat()

    try:
        res = await sb.table("announcements").update(payload).eq("id", id).aexecute()
        if not res.data:
            raise HTTPException(status_code=500, detail="Failed to update announcement")
        return {"success": True, "data": res.data[0]}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database write failed: {e}")

@router.delete("/{id}")
async def delete_announcement(id: str, user=Depends(require_super_admin_or_director)):
    sb = get_supabase()
    try:
        res = await sb.table("announcements").delete().eq("id", id).aexecute()
        if not res.data:
            raise HTTPException(status_code=404, detail="Announcement not found")
        return {"success": True, "message": "Announcement deleted successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database delete failed: {e}")
