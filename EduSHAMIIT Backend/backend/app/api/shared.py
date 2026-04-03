from fastapi import APIRouter, Depends, HTTPException
from typing import Optional

from app.middleware.auth import get_current_user, require_school_id
from app.services.supabase_client import get_supabase

router = APIRouter()


@router.get("/messages")
async def get_messages(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    messages = sb.table("messages").select("*, profiles!sender_id(full_name, avatar_url, role)").eq("school_id", school_id).or_(f"sender_id.eq.{user['id']},receiver_id.eq.{user['id']}").order("created_at", ascending=False).execute().data
    return {"success": True, "school_id": school_id, "data": {"messages": messages}}


@router.post("/messages/send")
async def send_message(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    message = sb.table("messages").insert({"school_id": school_id, "sender_id": user["id"], "receiver_id": request.get("receiver_id"), "content": request.get("content")}).execute()
    return {"success": True, "school_id": school_id, "data": {"message_id": message.data[0]["id"]}}


@router.get("/messages/chat")
async def get_chat(chat_id: str = "", user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    messages = sb.table("messages").select("*, profiles!sender_id(full_name, avatar_url)").eq("school_id", school_id).or_(f"sender_id.eq.{chat_id},receiver_id.eq.{chat_id}").order("created_at").execute().data
    return {"success": True, "school_id": school_id, "data": {"messages": messages}}


@router.get("/notifications")
async def get_notifications(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    notifications = sb.table("notifications").select("*").eq("school_id", school_id).eq("user_id", user["id"]).order("created_at", ascending=False).limit(20).execute().data
    return {"success": True, "school_id": school_id, "data": {"notifications": notifications}}


@router.put("/notifications/{notification_id}/read")
async def mark_notification_read(notification_id: str, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    sb.table("notifications").update({"is_read": True}).eq("id", notification_id).execute()
    return {"success": True}


@router.get("/user/settings")
async def get_settings(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    settings = sb.table("user_settings").select("*").eq("user_id", user["id"]).maybe_single().execute().data
    return {"success": True, "school_id": school_id, "data": {"settings": settings or {}}}


@router.put("/user/settings")
async def update_settings(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    sb.table("user_settings").upsert({"school_id": school_id, "user_id": user["id"], **request}).execute()
    return {"success": True, "message": "Settings updated"}


@router.post("/groups/create")
async def create_group(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    group = sb.table("groups").insert({"school_id": school_id, "name": request.get("name"), "description": request.get("description"), "created_by": user["id"]}).execute()
    return {"success": True, "school_id": school_id, "data": {"group_id": group.data[0]["id"]}}


@router.get("/groups")
async def get_groups(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    groups = sb.table("groups").select("*").eq("school_id", school_id).execute().data
    return {"success": True, "school_id": school_id, "data": {"groups": groups}}