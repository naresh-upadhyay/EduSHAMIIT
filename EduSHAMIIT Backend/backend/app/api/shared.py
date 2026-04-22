from fastapi import APIRouter, Depends, HTTPException
from typing import Optional

from app.middleware.auth import get_current_user, require_school_id
from app.services.supabase_client import get_supabase

router = APIRouter()


@router.get("/messages")
async def get_messages(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    messages = (await sb.table("messages").select("*, profiles!sender_id(full_name, avatar_url, role)").eq("school_id", school_id).or_(f"sender_id.eq.{user['id']},receiver_id.eq.{user['id']}").order("created_at", ascending=False).aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"messages": messages}}


@router.post("/messages/send")
async def send_message(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    message = await sb.table("messages").insert({"school_id": school_id, "sender_id": user["id"], "receiver_id": request.get("receiver_id"), "content": request.get("content")}).aexecute()
    return {"success": True, "school_id": school_id, "data": {"message_id": message.data[0]["id"]}}


@router.get("/messages/chat")
async def get_chat(chat_id: str = "", user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    messages = (await sb.table("messages").select("*, profiles!sender_id(full_name, avatar_url)").eq("school_id", school_id).or_(f"sender_id.eq.{chat_id},receiver_id.eq.{chat_id}").order("created_at").aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"messages": messages}}


@router.get("/notifications")
async def get_notifications(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    notifications = (await sb.table("notifications").select("*").eq("school_id", school_id).eq("user_id", user["id"]).order("created_at", ascending=False).limit(20).aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"notifications": notifications}}


@router.put("/notifications/{notification_id}/read")
async def mark_notification_read(notification_id: str, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    await sb.table("notifications").update({"is_read": True}).eq("id", notification_id).aexecute()
    return {"success": True}


@router.get("/user/settings")
async def get_settings(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    settings = (await sb.table("user_settings").select("*").eq("user_id", user["id"]).maybe_single().aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"settings": settings or {}}}


@router.put("/user/settings")
async def update_settings(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    await sb.table("user_settings").upsert({"school_id": school_id, "user_id": user["id"], **request}, on_conflict="user_id").aexecute()
    return {"success": True, "message": "Settings updated"}


@router.post("/groups/create")
async def create_group(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    group = await sb.table("groups").insert({"school_id": school_id, "name": request.get("name"), "description": request.get("description"), "created_by": user["id"]}).aexecute()
    return {"success": True, "school_id": school_id, "data": {"group_id": group.data[0]["id"]}}


@router.get("/groups")
async def get_groups(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    groups = (await sb.table("groups").select("*").eq("school_id", school_id).aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"groups": groups}}