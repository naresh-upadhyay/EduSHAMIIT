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
    sort_by: Optional[str] = Query("created_at"),
    sort_order: Optional[str] = Query("desc"),
    user=Depends(require_super_admin)
):
    sb = get_supabase()
    user_id = user.get("id")
    try:
        # Query unified notifications table filtered by system_alert category
        q = sb.table("notifications").select("*").eq("category", "system_alert").count("exact")
        
        # Apply filters
        if priority and priority != "All Priorities" and priority != "All Alerts":
            if priority == "Unread":
                q = q.eq("is_read", False)
            elif priority == "Resolved":
                q = q.ilike("status", "%resolved%")
            elif priority in ["Critical", "High", "Warning", "Info"]:
                q = q.ilike("priority", f"%{priority}%")
        if status and status != "All Status":
            q = q.ilike("status", f"%{status}%")
        if search:
            clean_search = sanitize_search_input(search)
            if clean_search:
                q = q.or_(f"title.ilike.%{clean_search}%,message.ilike.%{clean_search}%")

        
        sort_col_map = {
            "title": "title",
            "category": "category",
            "priority": "priority",
            "status": "status",
            "created_at": "created_at",
        }
        sort_col = sort_col_map.get(sort_by or "created_at", "created_at")
        sort_asc = (sort_order or "desc").lower() == "asc"

        q = q.order(sort_col, ascending=sort_asc)
        offset = (page - 1) * page_size
        q = q.limit(page_size).offset(offset)
        
        res = await q.aexecute()
        alerts = res.data or []
        total = res.count or len(alerts)

        # Ensure each alert has a status field fallback for UI and message mapped to description
        for alert in alerts:
            if not alert.get("status"):
                alert["status"] = "New"
            if not alert.get("description") and alert.get("message"):
                alert["description"] = alert.get("message")

        # Get summary stats
        try:
            stats_res = await sb.table("notifications").select("id, is_read, priority, status, created_at, updated_at").eq("category", "system_alert").aexecute()
        except Exception:
            stats_res = await sb.table("notifications").select("id, is_read, created_at").aexecute()
        all_rows = stats_res.data or []
        
        total_alerts = len(all_rows)
        unread_alerts = sum(1 for r in all_rows if r.get("is_read") is False)
        crit_count = sum(1 for r in all_rows if (r.get("priority") or "").lower() == "critical")
        high_count = sum(1 for r in all_rows if (r.get("priority") or "").lower() == "high")
        warn_count = sum(1 for r in all_rows if (r.get("priority") or "").lower() == "warning")
        info_count = sum(1 for r in all_rows if (r.get("priority") or "").lower() in ["info", "normal", "low", ""])
        
        resolved_alerts = sum(1 for r in all_rows if (r.get("status") or "").lower() == "resolved")
        in_progress_alerts = sum(1 for r in all_rows if (r.get("status") or "").lower() in ["in progress", "in_progress"])
        new_alerts = sum(1 for r in all_rows if (r.get("status") or "").lower() == "new")
        
        today_str = datetime.utcnow().date().isoformat()
        resolved_today_alerts = sum(1 for r in all_rows if (r.get("status") or "").lower() == "resolved" and str(r.get("updated_at") or r.get("created_at") or "").startswith(today_str))
        
        breakdown = {
            "critical": crit_count,
            "high": high_count,
            "warning": warn_count,
            "info": info_count
        }
        
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
                    "critical_alerts": crit_count,
                    "high_alerts": high_count,
                    "warning_alerts": warn_count,
                    "info_alerts": info_count,
                    "resolved_alerts": resolved_alerts,
                    "in_progress_alerts": in_progress_alerts,
                    "resolved_today_alerts": resolved_today_alerts
                },
                "breakdown": breakdown,
                "settings": settings
            }
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("")
async def create_system_alert(request: AlertCreate, user=Depends(require_super_admin)):
    sb = get_supabase()
    try:
        priority_val = (request.priority or "normal").lower()
        if priority_val == "critical":
            priority_val = "critical"
        elif priority_val == "high":
            priority_val = "high"
        elif priority_val == "warning":
            priority_val = "warning"
        else:
            priority_val = "normal"

        is_read_val = (request.status or "").lower() == "resolved"

        insert_data = {
            "title": request.title,
            "message": request.description or request.title,
            "category": "system_alert",
            "school_id": request.school_id,
            "priority": priority_val,
            "status": request.status or "New",
            "is_read": is_read_val,
            "created_at": datetime.utcnow().isoformat()
        }
        res = await sb.table("notifications").insert(insert_data).aexecute()
        
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
        if request.priority is not None:
            p_val = request.priority.lower()
            if p_val in ["critical", "high", "warning"]:
                update_data["priority"] = p_val
            else:
                update_data["priority"] = "normal"
        if request.status is not None:
            update_data["status"] = request.status
            if request.status.lower() == "resolved":
                update_data["is_read"] = True
            elif request.status.lower() == "new":
                update_data["is_read"] = False
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
        elif request.action == "resolve":
            for aid in request.ids:
                await sb.table("notifications").update({"is_read": True, "status": "Resolved"}).eq("id", aid).aexecute()
                
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
