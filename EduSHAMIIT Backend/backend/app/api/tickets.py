from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File
from typing import Optional, List
from datetime import datetime, timedelta
import random
import uuid
import httpx
from pydantic import BaseModel

from app.config import settings
from app.middleware.auth import get_current_user, require_any_role
from app.services.supabase_client import get_supabase

router = APIRouter()

require_super_admin_or_director = require_any_role("super_admin", "director")

# ===========================================================
# Schemas
# ===========================================================
class TicketCreate(BaseModel):
    subject: str
    description: Optional[str] = None
    category: str
    priority: str
    school_id: Optional[str] = None
    requested_by_id: str
    assigned_to_id: Optional[str] = None

class TicketUpdate(BaseModel):
    status: Optional[str] = None
    priority: Optional[str] = None
    category: Optional[str] = None
    assigned_to_id: Optional[str] = None

class MessageCreate(BaseModel):
    sender_id: str
    message: str
    message_type: Optional[str] = "conversation" # 'conversation' or 'note'

# ===========================================================
# Endpoints
# ===========================================================

@router.get("/tickets")
async def list_tickets(
    status: Optional[str] = Query(None),
    priority: Optional[str] = Query(None),
    category: Optional[str] = Query(None),
    school_id: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    user=Depends(require_super_admin_or_director)
):
    sb = get_supabase()

    # 1. Fetch counts/stats dynamically
    try:
        counts_res = await sb.table("it_support_tickets").select("status").aexecute()
        all_status = [x.get("status") for x in counts_res.data or []]
    except Exception as ce:
        print(f"Error fetching ticket status counts: {ce}", flush=True)
        all_status = []

    total_t = len(all_status)
    open_t = sum(1 for s in all_status if s == "Open")
    in_prog_t = sum(1 for s in all_status if s == "In Progress")
    pending_t = sum(1 for s in all_status if s == "Pending User")
    resolved_t = sum(1 for s in all_status if s == "Resolved")
    closed_t = sum(1 for s in all_status if s == "Closed")

    stats = {
        "total": {"value": total_t, "trend": "+15.6%", "is_up": True},
        "open": {"value": open_t, "trend": "+8.2%", "is_up": True},
        "in_progress": {"value": in_prog_t, "trend": "+6.1%", "is_up": True},
        "pending": {"value": pending_t, "trend": "-3.4%", "is_up": False},
        "resolved": {"value": resolved_t, "trend": "+18.7%", "is_up": True},
        "closed": {"value": closed_t, "trend": "+12.3%", "is_up": True}
    }

    # 2. Build Query
    q = sb.table("it_support_tickets").select(
        "*, requested_by:profiles!requested_by_id(full_name, role, email, avatar_url), assigned_to:profiles!assigned_to_id(full_name, role, email, avatar_url), school:schools(name)"
    ).count("exact")

    if status and status != "All Status":
        q = q.eq("status", status)
    if priority and priority != "All Priorities":
        q = q.eq("priority", priority)
    if category and category != "All Categories":
        q = q.eq("category", category)
    if school_id and school_id != "All Institutions":
        q = q.eq("school_id", school_id)

    if search:
        search_escaped = f"%{search}%"
        q = q.or_(f"ticket_code.ilike.{search_escaped},subject.ilike.{search_escaped},description.ilike.{search_escaped},category.ilike.{search_escaped}")

    offset = (page - 1) * page_size
    q = q.order("created_at", ascending=False).limit(page_size).offset(offset)

    res = await q.aexecute()
    tickets = res.data or []
    total_records = res.count or len(tickets)

    return {
        "success": True,
        "data": {
            "tickets": tickets,
            "total_records": total_records,
            "stats": stats
        }
    }

@router.get("/tickets/{ticket_id}")
async def get_ticket(ticket_id: str, user=Depends(require_super_admin_or_director)):
    sb = get_supabase()
    res = await sb.table("it_support_tickets").select(
        "*, requested_by:profiles!requested_by_id(*), assigned_to:profiles!assigned_to_id(*), school:schools(*)"
    ).eq("id", ticket_id).maybe_single().aexecute()

    if not res.data:
        raise HTTPException(status_code=404, detail="Ticket not found")
    return {"success": True, "data": res.data}

@router.post("/tickets")
async def create_ticket(ticket: TicketCreate, user=Depends(require_super_admin_or_director)):
    sb = get_supabase()

    # Generate readable ticket code
    year = datetime.utcnow().year
    random_seq = random.randint(1000, 9999)
    ticket_code = f"TKT-{year}-{random_seq}"

    payload = {
        "ticket_code": ticket_code,
        "school_id": ticket.school_id,
        "subject": ticket.subject,
        "description": ticket.description,
        "category": ticket.category,
        "priority": ticket.priority,
        "requested_by_id": ticket.requested_by_id,
        "assigned_to_id": ticket.assigned_to_id,
        "status": "Open"
    }

    res = await sb.table("it_support_tickets").insert(payload).aexecute()
    if not res.data:
        raise HTTPException(status_code=400, detail="Failed to create ticket")

    # Seed initial message with description if provided
    created_ticket = res.data[0]
    if ticket.description:
        await sb.table("it_support_ticket_messages").insert({
            "ticket_id": created_ticket["id"],
            "sender_id": ticket.requested_by_id,
            "message": ticket.description,
            "message_type": "conversation"
        }).aexecute()

    return {"success": True, "data": created_ticket}

@router.put("/tickets/{ticket_id}")
async def update_ticket(ticket_id: str, ticket: TicketUpdate, user=Depends(require_super_admin_or_director)):
    sb = get_supabase()

    # Verify ticket exists
    check_res = await sb.table("it_support_tickets").select("id").eq("id", ticket_id).maybe_single().aexecute()
    if not check_res.data:
        raise HTTPException(status_code=404, detail="Ticket not found")

    update_payload = {}
    if ticket.status is not None:
        update_payload["status"] = ticket.status
    if ticket.priority is not None:
        update_payload["priority"] = ticket.priority
    if ticket.category is not None:
        update_payload["category"] = ticket.category
    if ticket.assigned_to_id is not None:
        update_payload["assigned_to_id"] = ticket.assigned_to_id if ticket.assigned_to_id != "" else None
    
    update_payload["updated_at"] = datetime.utcnow().isoformat()

    res = await sb.table("it_support_tickets").update(update_payload).eq("id", ticket_id).aexecute()
    if not res.data:
        raise HTTPException(status_code=400, detail="Failed to update ticket")
    
    return {"success": True, "data": res.data[0]}

@router.delete("/tickets/{ticket_id}")
async def delete_ticket(ticket_id: str, user=Depends(require_super_admin_or_director)):
    sb = get_supabase()
    res = await sb.table("it_support_tickets").delete().eq("id", ticket_id).aexecute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Ticket not found or delete failed")
    return {"success": True, "detail": "Ticket deleted successfully"}

# ===========================================================
# Conversation Endpoints
# ===========================================================

@router.get("/tickets/{ticket_id}/messages")
async def list_ticket_messages(ticket_id: str, user=Depends(require_super_admin_or_director)):
    sb = get_supabase()
    res = await sb.table("it_support_ticket_messages").select(
        "*, sender:profiles!sender_id(full_name, role, email, avatar_url)"
    ).eq("ticket_id", ticket_id).order("created_at", ascending=True).aexecute()

    return {"success": True, "data": res.data or []}

@router.post("/tickets/{ticket_id}/messages")
async def post_ticket_message(ticket_id: str, msg: MessageCreate, user=Depends(require_super_admin_or_director)):
    sb = get_supabase()

    payload = {
        "ticket_id": ticket_id,
        "sender_id": msg.sender_id,
        "message": msg.message,
        "message_type": msg.message_type
    }

    res = await sb.table("it_support_ticket_messages").insert(payload).aexecute()
    if not res.data:
        raise HTTPException(status_code=400, detail="Failed to post message")

    # Update ticket's updated_at timestamp
    await sb.table("it_support_tickets").update({
        "updated_at": datetime.utcnow().isoformat()
    }).eq("id", ticket_id).aexecute()

    # Query message with sender details to return
    created_msg = res.data[0]
    msg_res = await sb.table("it_support_ticket_messages").select(
        "*, sender:profiles!sender_id(full_name, role, email, avatar_url)"
    ).eq("id", created_msg["id"]).maybe_single().aexecute()

    return {"success": True, "data": msg_res.data}


# ===========================================================
# Attachment Endpoints
# ===========================================================

@router.get("/tickets/{ticket_id}/attachments")
async def list_ticket_attachments(ticket_id: str, user=Depends(require_super_admin_or_director)):
    sb = get_supabase()
    res = await sb.table("it_support_ticket_attachments").select("*").eq("ticket_id", ticket_id).order("created_at", ascending=False).aexecute()
    return {"success": True, "data": res.data or []}


@router.post("/tickets/{ticket_id}/attachments")
async def upload_ticket_attachment(
    ticket_id: str,
    file: UploadFile = File(...),
    user=Depends(require_super_admin_or_director)
):
    sb = get_supabase()
    file_bytes = await file.read()
    file_size = len(file_bytes)
    
    if file_size > 20 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="File too large (max 20 MB)")
        
    safe_name = file.filename or "attachment"
    extension = safe_name.rsplit(".", 1)[-1].lower() if "." in safe_name else "bin"
    attachment_id = str(uuid.uuid4())
    
    # Upload to Supabase Storage
    storage_path = f"documents/support/{ticket_id}/{attachment_id}.{extension}"
    supabase_url = settings.SUPABASE_URL.rstrip("/")
    storage_url = f"{supabase_url}/storage/v1/object/{storage_path}"
    headers = {
        "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
        "Content-Type": file.content_type or "application/octet-stream",
        "x-upsert": "true",
    }
    
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            upload_response = await client.post(storage_url, headers=headers, content=file_bytes)
        
        if upload_response.status_code not in (200, 201):
            raise HTTPException(
                status_code=500,
                detail=f"Storage upload failed: {upload_response.text}"
            )
    except Exception as e:
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(status_code=500, detail=f"Storage upload request failed: {str(e)}")
        
    from app.middleware.auth import get_public_supabase_url
    public_url_base = get_public_supabase_url(supabase_url)
    file_url = f"{public_url_base}/storage/v1/object/public/{storage_path}"
    
    payload = {
        "id": attachment_id,
        "ticket_id": ticket_id,
        "file_name": safe_name,
        "file_url": file_url,
        "file_type": file.content_type or "application/octet-stream",
        "file_size": file_size,
        "uploaded_by": user["id"]
    }
    
    res = await sb.table("it_support_ticket_attachments").insert(payload).aexecute()
    if not res.data:
        raise HTTPException(status_code=400, detail="Failed to register attachment in DB")
        
    return {"success": True, "data": res.data[0]}
