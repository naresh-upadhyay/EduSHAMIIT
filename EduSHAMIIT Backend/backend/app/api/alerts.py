from fastapi import APIRouter, Depends, HTTPException, Query
from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel

from app.middleware.auth import get_current_user, require_any_role
from app.services.supabase_client import get_supabase

router = APIRouter()

require_super_admin = require_any_role("super_admin")

# ===========================================================
# Schemas
# ===========================================================
class AlertCreate(BaseModel):
    title: str
    description: Optional[str] = None
    category: str
    priority: str
    status: Optional[str] = "New"
    school_id: Optional[str] = None

class AlertUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    category: Optional[str] = None
    priority: Optional[str] = None
    status: Optional[str] = None
    is_read: Optional[bool] = None

class BulkUpdateAlerts(BaseModel):
    ids: List[str]
    action: str # 'read', 'unread', 'resolve', 'delete'

class NotificationSettingsUpdate(BaseModel):
    email_notifications: bool
    sms_alerts: bool
    push_notifications: bool
    system_alert_sounds: bool

# ===========================================================
# Endpoints (Using Unified notifications table)
# ===========================================================

from app.utils.sanitizer import sanitize_search_input

@router.get("")
async def get_system_alerts(
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    search: Optional[str] = None,
    category: Optional[str] = None,
    priority: Optional[str] = None,
    status: Optional[str] = None,
    user=Depends(require_super_admin)
):
    sb = get_supabase()
    user_id = user.get("id")
    try:
        # Query unified notifications table filtered by system_alert category
        q = sb.table("notifications").select("*").eq("category", "system_alert").count("exact")
        
        # Apply filters
        if priority and priority != "All Priorities":
            if priority == "Unread":
                q = q.eq("is_read", False)
            elif priority == "Resolved":
                q = q.eq("status", "Resolved")
        if search:
            clean_search = sanitize_search_input(search)
            if clean_search:
                q = q.or_(f"title.ilike.%{clean_search}%,message.ilike.%{clean_search}%")

        
        q = q.order("created_at", ascending=False)
        offset = (page - 1) * page_size
        q = q.limit(page_size).offset(offset)
        
        res = await q.aexecute()
        alerts = res.data or []
        total = res.count or len(alerts)

        # Get summary stats
        stats_res = await sb.table("notifications").select("status, is_read, created_at").eq("category", "system_alert").aexecute()
        all_rows = stats_res.data or []
        
        total_alerts = len(all_rows)
        unread_alerts = sum(1 for r in all_rows if r.get("is_read") is False)
        critical_alerts = sum(1 for r in all_rows if r.get("status") == "Critical")
        resolved_alerts = sum(1 for r in all_rows if r.get("status") == "Resolved")
        in_progress_alerts = sum(1 for r in all_rows if r.get("status") == "In Progress")
        
        profile_res = await sb.table("profiles").select(
            "email_notifications, sms_alerts, push_notifications, system_alert_sounds"
        ).eq("id", user_id).maybe_single().aexecute()
        
        settings = profile_res.data or {
            "email_notifications": True,
            "sms_alerts": False,
            "push_notifications": True,
            "system_alert_sounds": False
        }

        return {
            "success": True,
            "data": {
                "alerts": alerts,
                "total": total,
                "stats": {
                    "total_alerts": total_alerts,
                    "unread_alerts": unread_alerts,
                    "critical_alerts": critical_alerts,
                    "resolved_alerts": resolved_alerts,
                    "in_progress_alerts": in_progress_alerts
                },
                "settings": settings
            }
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("")
async def create_system_alert(request: AlertCreate, user=Depends(require_super_admin)):
    sb = get_supabase()
    try:
        res = await sb.table("notifications").insert({
            "title": request.title,
            "message": request.description or request.title,
            "category": "system_alert",
            "school_id": request.school_id,
            "is_read": False,
            "created_at": datetime.utcnow().isoformat()
        }).aexecute()
        
        if res.data:
            return {"success": True, "data": res.data[0]}
        raise HTTPException(status_code=400, detail="Failed to create alert")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/{alert_id}")
async def update_system_alert(alert_id: str, request: AlertUpdate, user=Depends(require_super_admin)):
    sb = get_supabase()
    try:
        update_data = {}
        if request.title is not None:
            update_data["title"] = request.title
        if request.description is not None:
            update_data["message"] = request.description
        if request.is_read is not None:
            update_data["is_read"] = request.is_read
            
        update_data["updated_at"] = datetime.utcnow().isoformat()
        
        res = await sb.table("notifications").update(update_data).eq("id", alert_id).aexecute()
        if res.data:
            return {"success": True, "data": res.data[0]}
        raise HTTPException(status_code=404, detail="Alert not found")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/{alert_id}")
async def delete_system_alert(alert_id: str, user=Depends(require_super_admin)):
    sb = get_supabase()
    try:
        await sb.table("notifications").delete().eq("id", alert_id).aexecute()
        return {"success": True}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/bulk-update")
async def bulk_update_alerts(request: BulkUpdateAlerts, user=Depends(require_super_admin)):
    sb = get_supabase()
    try:
        if not request.ids:
            return {"success": True}
            
        if request.action == "delete":
            for aid in request.ids:
                await sb.table("notifications").delete().eq("id", aid).aexecute()
        elif request.action == "read":
            for aid in request.ids:
                await sb.table("notifications").update({"is_read": True}).eq("id", aid).aexecute()
        elif request.action == "unread":
            for aid in request.ids:
                await sb.table("notifications").update({"is_read": False}).eq("id", aid).aexecute()
                
        return {"success": True}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/settings/update")
async def update_notification_settings(request: NotificationSettingsUpdate, user=Depends(require_super_admin)):
    sb = get_supabase()
    user_id = user.get("id")
    try:
        await sb.table("profiles").update({
            "email_notifications": request.email_notifications,
            "sms_alerts": request.sms_alerts,
            "push_notifications": request.push_notifications,
            "system_alert_sounds": request.system_alert_sounds
        }).eq("id", user_id).aexecute()
        
        return {"success": True}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
