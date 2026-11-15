from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from typing import Optional, Any
import httpx
import os
import uuid
from datetime import datetime

from app.middleware.auth import get_current_user, require_school_id
from app.services.supabase_client import get_supabase
from app.config import settings

router = APIRouter()


def _is_uuid(val: Any) -> bool:
    if not val:
        return False
    try:
        uuid.UUID(str(val).strip())
        return True
    except (ValueError, AttributeError, TypeError):
        return False


async def _resolve_profile_id(raw_id: Any, sb) -> Optional[str]:
    """Resolves any identifier (profile UUID, user_id string, auth UUID, email) to a valid profiles.id (UUID)."""
    if not raw_id:
        return None
    s = str(raw_id).strip()
    if not s:
        return None

    # 1. Direct UUID lookup in profiles.id
    if _is_uuid(s):
        try:
            res = await sb.table("profiles").select("id").eq("id", s).maybe_single().aexecute()
            if res.data and res.data.get("id"):
                return str(res.data["id"])
        except Exception:
            pass

    # 2. Lookup by profiles.user_id (e.g., SUP-A699FB, STU-9E9847, TEA-F78F76)
    try:
        res = await sb.table("profiles").select("id").eq("user_id", s).maybe_single().aexecute()
        if res.data and res.data.get("id"):
            return str(res.data["id"])
    except Exception:
        pass

    # 3. Lookup by email
    if "@" in s:
        try:
            res = await sb.table("profiles").select("id").ilike("email", s).maybe_single().aexecute()
            if res.data and res.data.get("id"):
                return str(res.data["id"])
        except Exception:
            pass

    return s if _is_uuid(s) else None


async def _get_caller_profile(user: dict, sb) -> dict:
    """Returns caller profile dictionary with validated UUID id, user_id, role, etc."""
    raw_id = user.get("id") or user.get("sub") or ""
    resolved_uuid = await _resolve_profile_id(raw_id, sb)
    if resolved_uuid:
        try:
            res = await sb.table("profiles").select("*").eq("id", resolved_uuid).maybe_single().aexecute()
            if res.data:
                return res.data
        except Exception:
            pass

    # Try lookup by email
    email = user.get("email")
    if email:
        try:
            res = await sb.table("profiles").select("*").ilike("email", email).maybe_single().aexecute()
            if res.data:
                return res.data
        except Exception:
            pass

    return {
        "id": resolved_uuid or raw_id,
        "user_id": raw_id,
        "full_name": user.get("name") or user.get("full_name") or "User",
        "role": user.get("role", "student"),
        "email": user.get("email"),
    }



@router.get("/messages")
async def get_messages(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    caller = await _get_caller_profile(user, sb)
    caller_id = str(caller.get("id") or user.get("id"))
    
    # 1. Fetch all groups caller is currently an active member of
    m_res = await sb.table("group_members").select("group_id, role, groups!group_id(*)").or_(
        f"member_id.eq.{caller_id},user_id.eq.{caller_id}"
    ).aexecute()
    memberships = m_res.data or []
    
    # Also if caller is creator of any group in this school, include that group
    c_res = await sb.table("groups").select("*").eq("school_id", school_id).eq("created_by", caller_id).aexecute()
    creator_groups = c_res.data or []
    
    group_ids = list({m['group_id'] for m in memberships if m.get('group_id')})
    for cg in creator_groups:
        if cg["id"] not in group_ids:
            group_ids.append(cg["id"])
            
    # 2. Build the initial set of active group conversation placeholders
    conversations = {}
    for m in memberships:
        g = m.get("groups")
        if g:
            conversations[f"group_{g['id']}"] = {
                "id": g["id"],
                "name": g["name"],
                "avatar_url": g.get("avatar_url"),
                "description": g.get("description"),
                "type": "group",
                "role": "group",
                "is_verified": True,
                "is_online": True,
                "last_message": "No messages yet",
                "last_message_time": g["created_at"],
                "unread_count": 0
            }
    for cg in creator_groups:
        key = f"group_{cg['id']}"
        if key not in conversations:
            conversations[key] = {
                "id": cg["id"],
                "name": cg["name"],
                "avatar_url": cg.get("avatar_url"),
                "description": cg.get("description"),
                "type": "group",
                "role": "group",
                "is_verified": True,
                "is_online": True,
                "last_message": "No messages yet",
                "last_message_time": cg["created_at"],
                "unread_count": 0
            }
            
    # 3. Construct OR query to fetch relevant messages
    # Either user is sender, user is receiver, or the message belongs to an active group the user is in
    or_cond = f"sender_id.eq.{caller_id},receiver_id.eq.{caller_id}"
    if group_ids:
        group_conds = ",".join([f"group_id.eq.{gid}" for gid in group_ids])
        or_cond += f",{group_conds}"
        
    messages = (await sb.table("messages")
                .select("*, sender:profiles!sender_id(id, full_name, avatar_url, role, phone, email, is_verified, is_online, class, ward_student_id), receiver:profiles!receiver_id(id, full_name, avatar_url, role, phone, email, is_verified, is_online, class, ward_student_id), groups:groups!group_id(id, name, avatar_url, description)")
                .eq("school_id", school_id)
                .or_(or_cond)
                .order("created_at", ascending=False)
                .aexecute()).data or []

    # Collect ward_student_ids for parents
    ward_student_ids = []
    for msg in messages:
        for p in (msg.get("sender"), msg.get("receiver")):
            if p and p.get("ward_student_id") and p.get("ward_student_id") not in ward_student_ids:
                ward_student_ids.append(p.get("ward_student_id"))
    
    ward_map = {}
    if ward_student_ids:
        try:
            wards_res = await sb.table("profiles").select("id, full_name, class, avatar_url").in_("id", ward_student_ids).aexecute()
            if wards_res.data:
                for w in wards_res.data:
                    ward_map[w["id"]] = w
        except Exception as e:
            print(f"Error fetching wards: {e}")
                
    # 4. Aggregate messages into conversation buckets
    for msg in messages:
        is_read = msg.get("is_read", False)
        sender_id = str(msg.get("sender_id") or "")
        receiver_id = str(msg.get("receiver_id") or "")
        group_id = msg.get("group_id")
        created_at = msg.get("created_at")
        content = msg.get("content")
        
        # Skip if soft-deleted for this caller
        deleted_for = msg.get("deleted_for") or []
        if caller_id in deleted_for or user["id"] in deleted_for:
            continue
        
        if not receiver_id and not group_id:
            continue
        
        if group_id:
            # If user has exited the group (not in active group memberships), NEVER include it!
            if group_id not in group_ids:
                continue
            key = f"group_{group_id}"
            if key in conversations:
                # If placeholder has not been replaced by a real message, replace it
                if conversations[key]["last_message"] == "No messages yet":
                    conversations[key]["last_message"] = content
                    conversations[key]["last_message_time"] = created_at
                # Count unread group messages (sent by others)
                if sender_id != caller_id and not is_read:
                    conversations[key]["unread_count"] += 1
            else:
                g = msg.get("groups")
                name = g.get("name", "Unknown Group") if g else "Unknown Group"
                avatar = g.get("avatar_url") if g else None
                desc = g.get("description") if g else None
                conversations[key] = {
                    "id": group_id,
                    "name": name,
                    "avatar_url": avatar,
                    "description": desc,
                    "type": "group",
                    "role": "group",
                    "is_verified": True,
                    "is_online": True,
                    "last_message": content,
                    "last_message_time": created_at,
                    "unread_count": 1 if (sender_id != caller_id and not is_read) else 0
                }
        else:
            contact_id = receiver_id if sender_id == caller_id else sender_id
            if not contact_id:
                continue
            key = f"user_{contact_id}"
            
            p = msg.get("receiver") if sender_id == caller_id else msg.get("sender")
            name = p.get("full_name", "Unknown User") if p else "Unknown User"
            avatar = p.get("avatar_url") if p else None
            role = p.get("role", "student") if p else "student"
            phone = p.get("phone") if p else None
            email = p.get("email") if p else None
            is_verified = p.get("is_verified", False) if p else False
            is_online = p.get("is_online", False) if p else False

            ward_id = p.get("ward_student_id") if p else None
            ward = ward_map.get(ward_id) if ward_id else None
            student_name = ward.get("full_name") if ward else (p.get("full_name") if role == "student" else None)
            student_class = ward.get("class") if ward else (p.get("class") if role == "student" else None)
            student_avatar = ward.get("avatar_url") if ward else (p.get("avatar_url") if role == "student" else None)
            
            if key not in conversations:
                conversations[key] = {
                    "id": contact_id,
                    "name": name,
                    "avatar_url": avatar,
                    "role": role,
                    "phone": phone,
                    "email": email,
                    "is_verified": is_verified,
                    "is_online": is_online,
                    "type": "direct",
                    "student_name": student_name,
                    "student_class": student_class,
                    "student_avatar": student_avatar,
                    "last_message": content,
                    "last_message_time": created_at,
                    "unread_count": 0
                }
                
            if sender_id == contact_id and not is_read:
                conversations[key]["unread_count"] += 1
                
    # Sort conversations by last message timestamp descending
    conversations_list = list(conversations.values())
    conversations_list.sort(key=lambda x: x["last_message_time"], reverse=True)
    
    return {"success": True, "school_id": school_id, "data": {"conversations": conversations_list}}


@router.post("/messages/send")
async def send_message(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    caller = await _get_caller_profile(user, sb)
    caller_id = str(caller.get("id") or user.get("id"))
    
    receiver_id = request.get("receiver_id")
    group_id = request.get("group_id")
    content = request.get("content")
    
    if not content or not str(content).strip():
        raise HTTPException(status_code=400, detail="Content cannot be empty")
        
    if not receiver_id and not group_id:
        raise HTTPException(status_code=400, detail="Either receiver_id or group_id must be provided")
        
    payload = {
        "school_id": school_id,
        "sender_id": caller_id,
        "content": str(content).strip(),
        "message_type": request.get("message_type", "text"),
    }
    
    if request.get("attachment_url"):
        payload["attachment_url"] = request.get("attachment_url")
    if request.get("file_name"):
        payload["file_name"] = request.get("file_name")
    if request.get("file_size"):
        payload["file_size"] = request.get("file_size")
    if request.get("reply_to_id"):
        payload["reply_to_id"] = request.get("reply_to_id")
    
    if group_id:
        # Check active membership
        mem_check = await sb.table("group_members").select("id").eq("group_id", group_id).or_(
            f"member_id.eq.{caller_id},user_id.eq.{caller_id}"
        ).maybe_single().aexecute()
        
        is_creator = False
        group_check = await sb.table("groups").select("created_by").eq("id", group_id).maybe_single().aexecute()
        if group_check.data and str(group_check.data.get("created_by")) == caller_id:
            is_creator = True
            
        is_app_admin = caller.get("role") in ("admin", "super_admin", "principal") or user.get("role") in ("admin", "super_admin", "principal")
        
        if not (mem_check.data or is_creator or is_app_admin):
            raise HTTPException(status_code=403, detail="You are no longer a member of this group. Exited or non-members cannot send messages.")
            
        payload["group_id"] = group_id
    else:
        target_uuid = await _resolve_profile_id(receiver_id, sb)
        if not target_uuid:
            raise HTTPException(status_code=404, detail="Receiver user profile not found")
            
        try:
            blocks_res = await sb.table("blocked_users").select("blocker_id, blocked_id").or_(
                f"blocker_id.eq.{caller_id},blocked_id.eq.{caller_id}"
            ).aexecute()
            if blocks_res.data:
                blocked_user_ids = {row["blocker_id"] for row in blocks_res.data} | {row["blocked_id"] for row in blocks_res.data}
                if target_uuid in blocked_user_ids:
                    raise HTTPException(status_code=403, detail="Messaging is blocked with this user")
        except HTTPException:
            raise
        except Exception as e:
            print(f"Error checking blocks in send_message: {e}")
            
        payload["receiver_id"] = target_uuid
        
    message = await sb.table("messages").insert(payload).aexecute()
    if not message.data:
        raise HTTPException(status_code=500, detail="Failed to send message")
        
    return {"success": True, "school_id": school_id, "data": {"message": message.data[0]}}


@router.get("/messages/chat")
async def get_chat(chat_id: str = "", user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    if not chat_id:
        return {"success": True, "school_id": school_id, "data": {"messages": []}}
        
    caller = await _get_caller_profile(user, sb)
    caller_id = str(caller.get("id") or user.get("id"))
    
    # Check if chat_id matches a group
    group_res = await sb.table("groups").select("*").eq("id", chat_id).maybe_single().aexecute()
    
    if group_res.data:
        # Mark group messages sent by others as read
        await sb.table("messages").update({"is_read": True, "read_at": "now()"}).eq("group_id", chat_id).neq("sender_id", caller_id).eq("is_read", False).aexecute()
        # Fetch group messages and include sender profiles
        messages = (await sb.table("messages")
                    .select("*, profiles!sender_id(id, full_name, avatar_url, role, phone, email, is_verified)")
                    .eq("group_id", chat_id)
                    .order("created_at")
                    .aexecute()).data or []
    else:
        # Fetch private direct messages between user and contact
        contact_uuid = await _resolve_profile_id(chat_id, sb) or chat_id
        res1 = await sb.table("messages").select("*, profiles!sender_id(id, full_name, avatar_url, role, phone, email, is_verified)").eq("school_id", school_id).eq("sender_id", caller_id).eq("receiver_id", contact_uuid).aexecute()
        res2 = await sb.table("messages").select("*, profiles!sender_id(id, full_name, avatar_url, role, phone, email, is_verified)").eq("school_id", school_id).eq("sender_id", contact_uuid).eq("receiver_id", caller_id).aexecute()
        messages = (res1.data or []) + (res2.data or [])
        messages.sort(key=lambda x: x['created_at'])
        
        # Mark incoming messages as read
        await sb.table("messages").update({"is_read": True, "read_at": "now()"}).eq("sender_id", contact_uuid).eq("receiver_id", caller_id).eq("is_read", False).aexecute()
        
    # Format messages
    result = []
    for m in messages:
        deleted_for = m.get("deleted_for") or []
        if caller_id in deleted_for or user["id"] in deleted_for:
            continue
        sender = m.get("profiles") or m.get("sender") or {}
        result.append({
            "id": m["id"],
            "sender_id": m["sender_id"],
            "receiver_id": m.get("receiver_id"),
            "group_id": m.get("group_id"),
            "content": m.get("content", ""),
            "message_type": m.get("message_type", "text"),
            "attachment_url": m.get("attachment_url"),
            "file_name": m.get("file_name"),
            "file_size": m.get("file_size"),
            "reply_to_id": m.get("reply_to_id"),
            "is_read": m.get("is_read", False),
            "created_at": m["created_at"],
            "sender_name": sender.get("full_name"),
            "sender_avatar": sender.get("avatar_url"),
            "sender_role": sender.get("role"),
        })
        
    return {"success": True, "school_id": school_id, "data": {"messages": result}}


@router.post("/messages/react")
async def react_message(request: dict, user=Depends(get_current_user)):
    sb = get_supabase()
    message_id = request.get("message_id")
    emoji = request.get("emoji", "❤️")
    if not message_id:
        raise HTTPException(status_code=400, detail="message_id is required")
        
    msg_res = await sb.table("messages").select("id, reactions").eq("id", message_id).maybe_single().aexecute()
    if not msg_res.data:
        raise HTTPException(status_code=404, detail="Message not found")
        
    reactions = msg_res.data.get("reactions") or {}
    user_id = user["id"]
    
    users_for_emoji = reactions.get(emoji, [])
    if user_id in users_for_emoji:
        users_for_emoji.remove(user_id)
        if not users_for_emoji:
            reactions.pop(emoji, None)
        else:
            reactions[emoji] = users_for_emoji
    else:
        users_for_emoji.append(user_id)
        reactions[emoji] = users_for_emoji
        
    await sb.table("messages").update({"reactions": reactions}).eq("id", message_id).aexecute()
    return {"success": True, "reactions": reactions}


@router.post("/messages/pin")
async def pin_message(request: dict, user=Depends(get_current_user)):
    sb = get_supabase()
    message_id = request.get("message_id")
    is_pinned = request.get("is_pinned", True)
    if not message_id:
        raise HTTPException(status_code=400, detail="message_id is required")
        
    await sb.table("messages").update({"is_pinned": is_pinned}).eq("id", message_id).aexecute()
    return {"success": True, "is_pinned": is_pinned}


@router.get("/messages/contact-details/{contact_id}")
async def get_contact_details(contact_id: str, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    
    # Check if group
    group_res = await sb.table("groups").select("*, group_members(*, profiles(id, full_name, avatar_url, role))").eq("id", contact_id).maybe_single().aexecute()
    if group_res.data:
        return {"success": True, "type": "group", "data": group_res.data}
        
    # Otherwise profile
    prof_res = await sb.table("profiles").select("*, ward_student:profiles!ward_student_id(id, full_name, class, avatar_url, phone, email)").eq("id", contact_id).maybe_single().aexecute()
    if not prof_res.data:
        raise HTTPException(status_code=404, detail="Contact not found")
        
    return {"success": True, "type": "contact", "data": prof_res.data}


@router.get("/users/search")
async def search_users(q: str = "", user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    query_builder = sb.table("profiles").select("id, full_name, avatar_url, role, class, phone, email").eq("school_id", school_id).neq("id", user["id"])
    if q.strip():
        query_builder = query_builder.ilike("full_name", f"%{q.strip()}%")
    res = await query_builder.limit(100).aexecute()
    
    users = res.data
    try:
        blocks_res = await sb.table("blocked_users").select("blocker_id, blocked_id").or_(f"blocker_id.eq.{user['id']},blocked_id.eq.{user['id']}").aexecute()
        if blocks_res.data:
            blocked_user_ids = {row["blocker_id"] for row in blocks_res.data} | {row["blocked_id"] for row in blocks_res.data}
            users = [u for u in users if u["id"] not in blocked_user_ids]
    except Exception as e:
        print(f"Error filtering blocked users in search: {e}")
        
    return {"success": True, "data": {"users": users}}


@router.get("/notifications")
async def get_notifications(
    is_read: str = None,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id)
):
    sb = get_supabase()
    query = sb.table("notifications").select("*").eq("school_id", school_id).eq("user_id", user["id"])
    if is_read == "true":
        query = query.eq("is_read", True)
    elif is_read == "false":
        query = query.eq("is_read", False)
    notifications = (await query.order("created_at", ascending=False).limit(50).aexecute()).data
    unread_count = sum(1 for n in notifications if not n.get("is_read", False))
    return {"success": True, "school_id": school_id, "data": {"notifications": notifications, "unread_count": unread_count}}


@router.put("/notifications/{notification_id}/read")
async def mark_notification_read(notification_id: str, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    await sb.table("notifications").update({"is_read": True}).eq("id", notification_id).eq("user_id", user["id"]).aexecute()
    return {"success": True}


@router.patch("/notifications/{notification_id}/read")
async def mark_notification_read_patch(notification_id: str, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    await sb.table("notifications").update({"is_read": True}).eq("id", notification_id).eq("user_id", user["id"]).aexecute()
    return {"success": True}


@router.patch("/notifications/read-all")
async def mark_all_notifications_read(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    await sb.table("notifications").update({"is_read": True}).eq("user_id", user["id"]).eq("is_read", False).aexecute()
    return {"success": True}


@router.delete("/notifications/{notification_id}")
async def delete_notification(notification_id: str, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    await sb.table("notifications").delete().eq("id", notification_id).eq("user_id", user["id"]).aexecute()
    return {"success": True}


@router.get("/user/settings")
async def get_settings(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    settings = (await sb.table("user_settings").select("*").eq("user_id", user["id"]).maybe_single().aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"settings": settings or {}}}


@router.put("/user/settings")
async def update_user_settings(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    await sb.table("user_settings").upsert({"school_id": school_id, "user_id": user["id"], **request}, on_conflict="user_id").aexecute()
    return {"success": True}


@router.get("/groups/{group_id}/members")
async def get_group_members(group_id: str, user=Depends(get_current_user)):
    sb = get_supabase()
    caller = await _get_caller_profile(user, sb)
    caller_id = str(caller.get("id") or user.get("id"))
    
    members_res = await sb.table("group_members").select("id, member_id, user_id, role, created_at").eq("group_id", group_id).aexecute()
    members_data = members_res.data or []
    
    group_res = await sb.table("groups").select("created_by").eq("id", group_id).maybe_single().aexecute()
    creator_id = str(group_res.data.get("created_by")) if group_res.data and group_res.data.get("created_by") else None
    
    member_ids = list({str(m["member_id"]) for m in members_data if m.get("member_id")} | {str(m["user_id"]) for m in members_data if m.get("user_id")})
    
    profiles_dict = {}
    if member_ids:
        uuid_ids = [mid for mid in member_ids if _is_uuid(mid)]
        if uuid_ids:
            try:
                p_res = await sb.table("profiles").select("id, user_id, full_name, email, role, avatar_url, phone, class, department").in_("id", uuid_ids).aexecute()
                if p_res.data:
                    for p in p_res.data:
                        if p.get("id"):
                            profiles_dict[str(p["id"])] = p
                        if p.get("user_id"):
                            profiles_dict[str(p["user_id"])] = p
            except Exception as e:
                print(f"Error querying profiles by id: {e}")
                
        try:
            p_res2 = await sb.table("profiles").select("id, user_id, full_name, email, role, avatar_url, phone, class, department").in_("user_id", member_ids).aexecute()
            if p_res2.data:
                for p in p_res2.data:
                    if p.get("id"):
                        profiles_dict[str(p["id"])] = p
                    if p.get("user_id"):
                        profiles_dict[str(p["user_id"])] = p
        except Exception as e:
            print(f"Error querying profiles by user_id: {e}")
            
    result = []
    seen_ids = set()
    for m in members_data:
        mid = str(m.get("member_id") or m.get("user_id"))
        prof = profiles_dict.get(str(m.get("member_id")), {}) or profiles_dict.get(str(m.get("user_id")), {})
        
        profile_uuid = str(prof.get("id") or mid)
        if profile_uuid in seen_ids:
            continue
        seen_ids.add(profile_uuid)
        
        is_creator = (profile_uuid == creator_id) if creator_id else False
        grp_role = m.get("role") or ("admin" if is_creator else "member")
        
        name = prof.get("full_name")
        if not name:
            if profile_uuid == caller_id or mid == str(user.get("id")):
                name = caller.get("full_name") or user.get("name") or "User"
            else:
                name = prof.get("email", "").split("@")[0].replace(".", " ").title() if prof.get("email") else "Group Member"
                
        user_role_val = prof.get("role") or ("super_admin" if is_creator else "student")
        
        result.append({
            "id": profile_uuid,
            "member_record_id": m.get("id"),
            "user_id": prof.get("user_id") or profile_uuid,
            "name": name,
            "full_name": name,
            "role": grp_role,
            "group_role": grp_role,
            "user_role": user_role_val,
            "avatar_url": prof.get("avatar_url"),
            "email": prof.get("email"),
            "phone": prof.get("phone"),
            "class": prof.get("class"),
            "class_name": prof.get("class"),
            "department": prof.get("department"),
            "is_creator": is_creator,
        })
        
    return {"success": True, "data": {"members": result}}


@router.post("/groups/{group_id}/avatar")
async def upload_group_avatar(
    group_id: str,
    avatar: UploadFile = File(...),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id)
):
    """Upload a group photo and save the public URL to groups.avatar_url."""
    sb = get_supabase()
    group_check = await sb.table("groups").select("id").eq("id", group_id).maybe_single().aexecute()
    if not group_check.data:
        raise HTTPException(status_code=404, detail="Group not found")
        
    image_bytes = await avatar.read()
    supabase_url = settings.SUPABASE_URL
    public_url_base = os.environ.get("PUBLIC_URL", supabase_url)
    
    content_type = avatar.content_type or "application/octet-stream"
    ext = "jpg"
    if avatar.filename and avatar.filename.lower().endswith(".png"):
        ext = "png"
    elif avatar.filename and avatar.filename.lower().endswith(".jpeg"):
        ext = "jpeg"
        
    storage_path = f"avatars/group_{group_id}.{ext}"
    storage_url = f"{supabase_url}/storage/v1/object/{storage_path}"
    
    headers = {
        "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
        "Content-Type": content_type
    }
    
    async with httpx.AsyncClient() as client:
        upload_response = await client.post(storage_url, headers=headers, content=image_bytes)
        if upload_response.status_code not in (200, 201):
            put_response = await client.put(storage_url, headers=headers, content=image_bytes)
            if put_response.status_code not in (200, 201):
                raise HTTPException(status_code=500, detail=f"Failed to upload group image: {put_response.text}")
                
    timestamp = int(datetime.now().timestamp())
    from app.middleware.auth import get_public_supabase_url
    public_url_base_replaced = get_public_supabase_url(public_url_base)
    public_url = f"{public_url_base_replaced}/storage/v1/object/public/{storage_path}?t={timestamp}"
    
    await sb.table("groups").update({"avatar_url": public_url}).eq("id", group_id).aexecute()
    return {"success": True, "data": {"avatar_url": public_url}}


@router.post("/groups/create")
async def create_group(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    caller = await _get_caller_profile(user, sb)
    creator_profile_id = str(caller.get("id") or user.get("id"))
    
    name = request.get("name")
    description = request.get("description")
    group_level = request.get("group_level", "school")
    class_name = request.get("class_name")
    is_private = request.get("is_private", False)
    avatar_url = request.get("avatar_url")
    
    if not name or not str(name).strip():
        raise HTTPException(status_code=400, detail="Group name is required")
        
    resolved_creator = await _resolve_profile_id(creator_profile_id, sb)
    if not resolved_creator or not _is_uuid(resolved_creator):
        resolved_creator = creator_profile_id
        
    user_role = caller.get("role", "student")
    user_class = caller.get("class")
    
    if user_role == "student":
        group_level = "class"
        class_name = user_class or class_name or "General"
    else:
        class_name = class_name or user_class or "General"

    insert_data = {
        "school_id": school_id,
        "name": str(name).strip(),
        "description": str(description).strip() if description else None,
        "created_by": resolved_creator,
        "is_private": bool(is_private),
        "group_level": group_level,
        "class_name": class_name,
    }
    if avatar_url:
        insert_data["avatar_url"] = avatar_url

    group_res = await sb.table("groups").insert(insert_data).aexecute()
    if not group_res.data:
        raise HTTPException(status_code=500, detail="Failed to create group")
        
    group_id = group_res.data[0]["id"]
    
    # Automatically add creator to group_members as admin
    await sb.table("group_members").insert({
        "group_id": group_id,
        "member_id": resolved_creator,
        "user_id": resolved_creator,
        "school_id": school_id,
        "role": "admin"
    }).aexecute()
    
    # If initial member_ids provided, add them as members
    initial_member_ids = request.get("member_ids") or []
    for mid in initial_member_ids:
        mid_resolved = await _resolve_profile_id(mid, sb)
        if mid_resolved and mid_resolved != resolved_creator:
            try:
                await sb.table("group_members").insert({
                    "group_id": group_id,
                    "member_id": mid_resolved,
                    "user_id": mid_resolved,
                    "school_id": school_id,
                    "role": "member"
                }).aexecute()
            except Exception:
                pass
                
    return {"success": True, "school_id": school_id, "data": {"group": group_res.data[0]}}


@router.get("/groups")
async def get_groups(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    caller = await _get_caller_profile(user, sb)
    caller_id = str(caller.get("id") or user.get("id"))
    
    memberships = (await sb.table("group_members").select("group_id").or_(
        f"member_id.eq.{caller_id},user_id.eq.{caller_id}"
    ).aexecute()).data or []
    member_group_ids = {m['group_id'] for m in memberships if m.get('group_id')}
    
    user_role = caller.get("role", "student")
    user_class = caller.get("class")
    
    groups_res = await sb.table("groups").select("*").eq("school_id", school_id).aexecute()
    all_groups = groups_res.data or []
    
    creator_ids = list({g["created_by"] for g in all_groups if g.get("created_by")})
    creators_dict = {}
    if creator_ids:
        uuid_creators = [cid for cid in creator_ids if _is_uuid(cid)]
        if uuid_creators:
            try:
                creators_res = await sb.table("profiles").select("id, role, class").in_("id", uuid_creators).aexecute()
                if creators_res.data:
                    creators_dict = {p["id"]: p for p in creators_res.data}
            except Exception:
                pass
            
    filtered_groups = []
    for g in all_groups:
        g_id = g["id"]
        is_member = g_id in member_group_ids or str(g.get("created_by")) == caller_id
        
        if is_member:
            g["is_member"] = True
            filtered_groups.append(g)
            continue
            
        g["is_member"] = False
        
        is_private = g.get("is_private", False)
        if is_private:
            continue
            
        creator_id = g.get("created_by")
        creator_profile = creators_dict.get(creator_id) if creator_id else None
        creator_role = creator_profile.get("role", "student") if creator_profile else "student"
        creator_class = creator_profile.get("class") if creator_profile else None
        
        if user_role == "student":
            if creator_role != "student":
                filtered_groups.append(g)
            elif creator_class and creator_class == user_class:
                filtered_groups.append(g)
            elif g.get("class_name") and g.get("class_name") == user_class:
                filtered_groups.append(g)
        else:
            filtered_groups.append(g)
            
    return {"success": True, "school_id": school_id, "data": {"groups": filtered_groups}}


@router.post("/groups/{group_id}/join")
async def join_group(group_id: str, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    caller = await _get_caller_profile(user, sb)
    caller_id = str(caller.get("id") or user.get("id"))
    
    group = await sb.table("groups").select("is_private").eq("id", group_id).maybe_single().aexecute()
    if not group.data:
        raise HTTPException(status_code=404, detail="Group not found")
    if group.data.get("is_private", False):
        raise HTTPException(status_code=403, detail="Cannot join a private group. You must be invited/added by an admin.")
        
    await sb.table("group_members").insert({
        "group_id": group_id,
        "member_id": caller_id,
        "user_id": caller_id,
        "school_id": school_id,
        "role": "member"
    }).aexecute()
    return {"success": True, "message": "Joined group successfully"}


@router.post("/groups/{group_id}/members")
async def add_group_member(group_id: str, request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    caller = await _get_caller_profile(user, sb)
    caller_id = str(caller.get("id") or user.get("id"))
    
    group = await sb.table("groups").select("created_by, school_id").eq("id", group_id).maybe_single().aexecute()
    if not group.data:
        raise HTTPException(status_code=404, detail="Group not found")
        
    creator_id = str(group.data.get("created_by")) if group.data.get("created_by") else None
    is_creator = (caller_id == creator_id)
    is_app_admin = caller.get("role") in ("admin", "super_admin", "principal") or user.get("role") in ("admin", "super_admin", "principal")
    
    caller_membership = await sb.table("group_members").select("role").eq("group_id", group_id).or_(
        f"member_id.eq.{caller_id},user_id.eq.{caller_id}"
    ).maybe_single().aexecute()
    is_group_admin = bool(caller_membership.data and caller_membership.data.get("role") == "admin")
    
    if not (is_creator or is_app_admin or is_group_admin):
        raise HTTPException(status_code=403, detail="Only group admins can add new members")
        
    member_ids = []
    if "member_ids" in request and isinstance(request["member_ids"], list):
        member_ids = request["member_ids"]
    elif "member_id" in request and request["member_id"]:
        member_ids = [request["member_id"]]
        
    if not member_ids:
        raise HTTPException(status_code=400, detail="member_id or member_ids is required")
        
    added_count = 0
    for mid in member_ids:
        target_uuid = await _resolve_profile_id(mid, sb)
        if not target_uuid:
            continue
            
        existing = await sb.table("group_members").select("id").eq("group_id", group_id).or_(
            f"member_id.eq.{target_uuid},user_id.eq.{target_uuid}"
        ).maybe_single().aexecute()
        if existing.data:
            continue
            
        await sb.table("group_members").insert({
            "group_id": group_id,
            "member_id": target_uuid,
            "user_id": target_uuid,
            "school_id": school_id,
            "role": "member"
        }).aexecute()
        added_count += 1
        
    return {"success": True, "message": f"Added {added_count} members successfully", "added_count": added_count}


@router.post("/groups/{group_id}/leave")
async def leave_group(group_id: str, user=Depends(get_current_user)):
    sb = get_supabase()
    caller = await _get_caller_profile(user, sb)
    caller_id = str(caller.get("id") or user.get("id"))
    
    await sb.table("group_members").delete().eq("group_id", group_id).or_(
        f"member_id.eq.{caller_id},user_id.eq.{caller_id}"
    ).aexecute()
    
    if user.get("id") and str(user["id"]) != caller_id:
        try:
            await sb.table("group_members").delete().eq("group_id", group_id).eq("member_id", str(user["id"])).aexecute()
        except Exception:
            pass
            
    return {"success": True, "message": "Left group successfully"}


@router.put("/groups/{group_id}")
@router.patch("/groups/{group_id}")
async def update_group_details(group_id: str, request: dict, user=Depends(get_current_user)):
    sb = get_supabase()
    caller = await _get_caller_profile(user, sb)
    caller_id = str(caller.get("id") or user.get("id"))
    
    group = await sb.table("groups").select("created_by").eq("id", group_id).maybe_single().aexecute()
    if not group.data:
        raise HTTPException(status_code=404, detail="Group not found")
        
    creator_id = str(group.data.get("created_by")) if group.data.get("created_by") else None
    is_creator = (caller_id == creator_id)
    is_app_admin = caller.get("role") in ("admin", "super_admin", "principal") or user.get("role") in ("admin", "super_admin", "principal")
    
    caller_mem = await sb.table("group_members").select("role").eq("group_id", group_id).or_(
        f"member_id.eq.{caller_id},user_id.eq.{caller_id}"
    ).maybe_single().aexecute()
    is_group_admin = bool(caller_mem.data and caller_mem.data.get("role") == "admin")
    
    if not (is_creator or is_app_admin or is_group_admin):
        raise HTTPException(status_code=403, detail="Only group admins can update group details")
        
    updates = {}
    if "name" in request and request["name"] and request["name"].strip():
        updates["name"] = request["name"].strip()
    if "description" in request:
        updates["description"] = request["description"].strip() if request["description"] else None
    if "avatar_url" in request:
        updates["avatar_url"] = request["avatar_url"].strip() if request["avatar_url"] else None
        
    if not updates:
        raise HTTPException(status_code=400, detail="No valid fields to update")
        
    res = await sb.table("groups").update(updates).eq("id", group_id).aexecute()
    return {"success": True, "message": "Group details updated successfully", "data": res.data[0] if res.data else updates}


@router.put("/groups/{group_id}/members/{member_id}")
@router.post("/groups/{group_id}/members/{member_id}/role")
async def update_group_member_role(group_id: str, member_id: str, request: dict, user=Depends(get_current_user)):
    sb = get_supabase()
    caller = await _get_caller_profile(user, sb)
    caller_id = str(caller.get("id") or user.get("id"))
    
    new_role = request.get("role", "member")
    if new_role not in ("admin", "member"):
        raise HTTPException(status_code=400, detail="Role must be 'admin' or 'member'")
        
    group = await sb.table("groups").select("created_by").eq("id", group_id).maybe_single().aexecute()
    if not group.data:
        raise HTTPException(status_code=404, detail="Group not found")
        
    creator_id = str(group.data.get("created_by")) if group.data.get("created_by") else None
    is_creator = (caller_id == creator_id)
    is_app_admin = caller.get("role") in ("admin", "super_admin", "principal") or user.get("role") in ("admin", "super_admin", "principal")
    
    caller_membership = await sb.table("group_members").select("role").eq("group_id", group_id).or_(
        f"member_id.eq.{caller_id},user_id.eq.{caller_id}"
    ).maybe_single().aexecute()
    is_group_admin = bool(caller_membership.data and caller_membership.data.get("role") == "admin")
    
    if not (is_creator or is_app_admin or is_group_admin):
        raise HTTPException(status_code=403, detail="Only group admins can update member roles")
        
    target_uuid = await _resolve_profile_id(member_id, sb) or member_id
    
    target_mem = await sb.table("group_members").select("*").eq("group_id", group_id).or_(
        f"member_id.eq.{target_uuid},user_id.eq.{target_uuid},id.eq.{member_id}"
    ).maybe_single().aexecute()
    
    if not target_mem.data:
        raise HTTPException(status_code=404, detail="Target user is not a member of this group")
        
    target_row = target_mem.data
    current_role = target_row.get("role", "member")
    row_id = target_row["id"]
    
    if current_role == new_role:
        return {"success": True, "message": f"User already has role {new_role}"}
        
    if current_role == "admin" and new_role == "member":
        admins_res = await sb.table("group_members").select("id").eq("group_id", group_id).eq("role", "admin").aexecute()
        admins = admins_res.data or []
        if len(admins) <= 1:
            raise HTTPException(status_code=400, detail="Cannot demote the last admin of the group. Please promote another member first.")
            
    await sb.table("group_members").update({"role": new_role}).eq("id", row_id).aexecute()
    return {"success": True, "message": f"Member role updated to {new_role} successfully"}


@router.delete("/groups/{group_id}/members/{member_id}")
async def remove_group_member(group_id: str, member_id: str, user=Depends(get_current_user)):
    sb = get_supabase()
    caller = await _get_caller_profile(user, sb)
    caller_id = str(caller.get("id") or user.get("id"))
    
    group = await sb.table("groups").select("created_by").eq("id", group_id).maybe_single().aexecute()
    if not group.data:
        raise HTTPException(status_code=404, detail="Group not found")
        
    creator_id = str(group.data.get("created_by")) if group.data.get("created_by") else None
    is_creator = (caller_id == creator_id)
    is_app_admin = caller.get("role") in ("admin", "super_admin", "principal") or user.get("role") in ("admin", "super_admin", "principal")
    
    caller_mem = await sb.table("group_members").select("role").eq("group_id", group_id).or_(
        f"member_id.eq.{caller_id},user_id.eq.{caller_id}"
    ).maybe_single().aexecute()
    is_group_admin = bool(caller_mem.data and caller_mem.data.get("role") == "admin")
    
    target_uuid = await _resolve_profile_id(member_id, sb) or member_id
    is_self = (caller_id == target_uuid or str(user.get("id")) == member_id)
    
    if not (is_self or is_creator or is_app_admin or is_group_admin):
        raise HTTPException(status_code=403, detail="Only group admins can remove members")
        
    await sb.table("group_members").delete().eq("group_id", group_id).or_(
        f"member_id.eq.{target_uuid},user_id.eq.{target_uuid},id.eq.{member_id}"
    ).aexecute()
    return {"success": True, "message": "Member removed successfully"}



@router.post("/user/change-password")
async def change_password(request: dict, user=Depends(get_current_user)):
    current_pw = request.get("currentPassword")
    new_pw = request.get("newPassword")
    
    if not current_pw or not new_pw:
        raise HTTPException(status_code=400, detail="Current and new password required")
        
    sb = get_supabase()
    
    # 1. Get email (fallback if not in token)
    email = user.get("email")
    if not email:
        try:
            profile_res = await sb.table("profiles").select("email").eq("id", user["id"]).maybe_single().aexecute()
            if profile_res.data:
                email = profile_res.data.get("email")
        except Exception as e:
            print(f"Error fetching email fallback: {str(e)}")
            
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")

    # 2. Verify current password by attempting to sign in
    try:
        await sb.auth().sign_in_with_password({
            "email": email,
            "password": current_pw,
        })
    except Exception as e:
        print(f"Password verification failed for {email}: {str(e)}")
        raise HTTPException(status_code=400, detail=f"Current password incorrect: {str(e)}")
        
    # 3. Update to new password
    try:
        # Use the admin update to override password directly
        await sb.auth().admin_update_user(user["id"], {"password": new_pw})
        return {"success": True, "message": "Password changed successfully"}
    except Exception as e:
        print(f"Password update failed: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to update password: {str(e)}")


@router.delete("/messages/{message_id}")
async def delete_message(message_id: str, user=Depends(get_current_user)):
    sb = get_supabase()
    caller = await _get_caller_profile(user, sb)
    caller_id = str(caller.get("id") or user.get("id"))
    
    msg = await sb.table("messages").select("sender_id, group_id").eq("id", message_id).maybe_single().aexecute()
    if not msg.data:
        raise HTTPException(status_code=404, detail="Message not found")
        
    sender_id = str(msg.data.get("sender_id") or "")
    group_id = msg.data.get("group_id")
    is_sender = (sender_id == caller_id or sender_id == str(user.get("id")))
    is_app_admin = caller.get("role") in ("admin", "super_admin", "principal") or user.get("role") in ("admin", "super_admin", "principal")
    
    # Senders can ALWAYS delete their own messages (even after exiting the group)
    if is_sender:
        await sb.table("messages").delete().eq("id", message_id).aexecute()
        return {"success": True, "message": "Message deleted successfully"}
        
    # Non-senders can ONLY delete if they are a group admin in that group or app admin
    is_group_admin = False
    if group_id:
        caller_mem = await sb.table("group_members").select("role").eq("group_id", group_id).or_(
            f"member_id.eq.{caller_id},user_id.eq.{caller_id}"
        ).maybe_single().aexecute()
        if caller_mem.data and caller_mem.data.get("role") == "admin":
            is_group_admin = True
            
    if not (is_group_admin or is_app_admin):
        raise HTTPException(status_code=403, detail="You can only delete your own messages")
        
    await sb.table("messages").delete().eq("id", message_id).aexecute()
    return {"success": True, "message": "Message deleted successfully"}


@router.post("/messages/clear")
async def clear_chat(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    chat_id = request.get("chat_id")
    if not chat_id:
        raise HTTPException(status_code=400, detail="chat_id is required")
        
    sb = get_supabase()
    caller = await _get_caller_profile(user, sb)
    caller_id = str(caller.get("id") or user.get("id"))
    is_app_admin = caller.get("role") in ("admin", "super_admin", "principal") or user.get("role") in ("admin", "super_admin", "principal")
    
    group_check = await sb.table("groups").select("id, created_by").eq("id", chat_id).maybe_single().aexecute()
    if group_check.data:
        # For groups: ONLY group creator or group admin or school admin can clear the group chat!
        is_creator = str(group_check.data.get("created_by")) == caller_id
        caller_mem = await sb.table("group_members").select("role").eq("group_id", chat_id).or_(
            f"member_id.eq.{caller_id},user_id.eq.{caller_id}"
        ).maybe_single().aexecute()
        is_group_admin = bool(caller_mem.data and caller_mem.data.get("role") == "admin")
        
        if not (is_creator or is_app_admin or is_group_admin):
            raise HTTPException(status_code=403, detail="Only group admins can clear group chat history")
            
        await sb.table("messages").delete().eq("group_id", chat_id).aexecute()
    else:
        contact_uuid = await _resolve_profile_id(chat_id, sb) or chat_id
        await sb.table("messages").delete().eq("school_id", school_id).or_(
            f"and(sender_id.eq.{caller_id},receiver_id.eq.{contact_uuid}),and(sender_id.eq.{contact_uuid},receiver_id.eq.{caller_id})"
        ).aexecute()
        
    return {"success": True, "message": "Chat history cleared"}


@router.post("/messages/upload")
async def upload_message_file(
    file: UploadFile = File(...),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id)
):
    """Upload a message file (photo/document) to Supabase storage and return public access URL."""
    file_bytes = await file.read()
    if len(file_bytes) == 0:
        raise HTTPException(status_code=400, detail="Empty file")
        
    supabase_url = settings.SUPABASE_URL
    public_url_base = os.environ.get("PUBLIC_URL", supabase_url)
    
    content_type = file.content_type or "application/octet-stream"
    filename = file.filename or "file.bin"
    
    # Secure file extension
    ext = "bin"
    if "." in filename:
        ext = filename.split(".")[-1]
        
    unique_id = uuid.uuid4().hex
    storage_path = f"avatars/msg_{user['id']}_{unique_id}.{ext}"
    storage_url = f"{supabase_url}/storage/v1/object/{storage_path}"
    
    headers = {
        "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
        "Content-Type": content_type
    }
    
    async with httpx.AsyncClient() as client:
        upload_response = await client.post(storage_url, headers=headers, content=file_bytes)
        if upload_response.status_code not in (200, 201):
            put_response = await client.put(storage_url, headers=headers, content=file_bytes)
            if put_response.status_code not in (200, 201):
                raise HTTPException(status_code=500, detail=f"Upload failed: {put_response.text}")
                
    from app.middleware.auth import get_public_supabase_url
    public_url_base_replaced = get_public_supabase_url(public_url_base)
    public_url = f"{public_url_base_replaced}/storage/v1/object/public/{storage_path}"
    return {
        "success": True, 
        "data": {
            "url": public_url, 
            "filename": filename, 
            "content_type": content_type
        }
    }


@router.post("/user/logout")
async def logout(user=Depends(get_current_user)):
    return {"success": True, "message": "Logged out"}


@router.post("/users/{blocked_id}/block")
async def block_user(blocked_id: str, user=Depends(get_current_user)):
    sb = get_supabase()
    profile = await sb.table("profiles").select("id").eq("id", blocked_id).maybe_single().aexecute()
    if not profile.data:
        raise HTTPException(status_code=404, detail="User to block not found")
    
    if blocked_id == user["id"]:
        raise HTTPException(status_code=400, detail="You cannot block yourself")
        
    try:
        await sb.table("blocked_users").insert({
            "blocker_id": user["id"],
            "blocked_id": blocked_id
        }).aexecute()
    except Exception:
        pass
        
    return {"success": True, "message": "User blocked successfully"}


@router.post("/users/{blocked_id}/unblock")
async def unblock_user(blocked_id: str, user=Depends(get_current_user)):
    sb = get_supabase()
    await sb.table("blocked_users").delete().eq("blocker_id", user["id"]).eq("blocked_id", blocked_id).aexecute()
    return {"success": True, "message": "User unblocked successfully"}


@router.get("/users/blocked")
async def get_blocked_users(user=Depends(get_current_user)):
    sb = get_supabase()
    res = await sb.table("blocked_users").select("blocked_id").eq("blocker_id", user["id"]).aexecute()
    blocked_ids = [row["blocked_id"] for row in res.data]
    return {"success": True, "data": {"blocked_ids": blocked_ids}}


@router.delete("/groups/{group_id}")
async def delete_group(group_id: str, user=Depends(get_current_user)):
    sb = get_supabase()
    caller = await _get_caller_profile(user, sb)
    caller_id = str(caller.get("id") or user.get("id"))
    
    group = await sb.table("groups").select("*").eq("id", group_id).maybe_single().aexecute()
    if not group.data:
        raise HTTPException(status_code=404, detail="Group not found")
        
    creator_id = str(group.data.get("created_by")) if group.data.get("created_by") else None
    is_creator = (caller_id == creator_id)
    is_app_admin = caller.get("role") in ("admin", "super_admin", "principal") or user.get("role") in ("admin", "super_admin", "principal")
    
    if not (is_creator or is_app_admin):
        raise HTTPException(status_code=403, detail="Only the group creator or admin can delete the group")
        
    members = await sb.table("group_members").select("*").eq("group_id", group_id).aexecute()
    if len(members.data or []) > 1 and not is_app_admin:
        raise HTTPException(status_code=400, detail="Groups with more than 1 member cannot be deleted until all other members leave.")
        
    await sb.table("groups").delete().eq("id", group_id).aexecute()
    return {"success": True, "message": "Group deleted successfully"}


# ─────────────────────────────────────────────────────────────────────────────
# LEAVE MANAGEMENT ENDPOINTS (shared — works for both student & teacher roles)
# ─────────────────────────────────────────────────────────────────────────────

@router.get("/leave")
async def get_leave_applications(
    status: Optional[str] = None,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id)
):
    """Get all leave applications for the current user (student or teacher)."""
    sb = get_supabase()

    query = (sb.table("leave_applications")
               .select("*")
               .eq("applicant_id", user["id"])
               .eq("school_id", school_id)
               .order("created_at", ascending=False))

    if status and status.lower() != "all":
        query = query.eq("status", status.lower())

    result = await query.aexecute()
    applications = result.data or []

    # Build stats
    total_quota = 30 if user.get("role") == "teacher" else 15
    approved = [a for a in applications if a["status"] == "approved"]
    pending  = [a for a in applications if a["status"] == "pending"]
    used     = sum(int(a.get("duration_days") or 0) for a in approved)
    balance  = max(0, total_quota - used)

    return {
        "applications": applications,
        "stats": {
            "total_quota": total_quota,
            "used": used,
            "pending": len(pending),
            "balance": balance,
        }
    }


@router.post("/leave")
async def apply_leave(
    body: dict,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id)
):
    """Apply for a leave (student or teacher)."""
    sb = get_supabase()

    leave_type = body.get("leave_type") or body.get("type")
    start_date = body.get("start_date")
    end_date   = body.get("end_date")
    reason     = body.get("reason", "")

    if not all([leave_type, start_date, end_date, reason]):
        raise HTTPException(status_code=400, detail="leave_type, start_date, end_date and reason are required")

    # Validate dates
    try:
        from datetime import date as _date
        sd = _date.fromisoformat(start_date)
        ed = _date.fromisoformat(end_date)
        if ed < sd:
            raise HTTPException(status_code=400, detail="end_date must be >= start_date")
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid date format (expected YYYY-MM-DD)")

    payload = {
        "school_id":      school_id,
        "applicant_id":   user["id"],
        "applicant_role": user.get("role", "student"),
        "leave_type":     leave_type,
        "start_date":     start_date,
        "end_date":       end_date,
        "reason":         reason,
        "status":         "pending",
    }

    if body.get("attachment_url"):
        payload["attachment_url"] = body["attachment_url"]

    result = await sb.table("leave_applications").insert(payload).aexecute()
    if not result.data:
        raise HTTPException(status_code=500, detail="Failed to create leave application")

    return {"success": True, "application": result.data[0]}


@router.patch("/leave/{leave_id}")
async def update_leave(
    leave_id: str,
    body: dict,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id)
):
    """Edit a pending leave application (only the applicant can edit their own pending leave)."""
    sb = get_supabase()

    # Verify ownership and pending status
    existing = await sb.table("leave_applications") \
        .select("*") \
        .eq("id", leave_id) \
        .eq("applicant_id", user["id"]) \
        .eq("school_id", school_id) \
        .aexecute()

    if not existing.data:
        raise HTTPException(status_code=404, detail="Leave application not found")

    leave = existing.data[0]
    if leave["status"] != "pending":
        raise HTTPException(status_code=400, detail="Only pending leave applications can be edited")

    # Build update payload from allowed fields
    update_payload = {}
    allowed_fields = ["leave_type", "start_date", "end_date", "reason", "attachment_url"]
    for field in allowed_fields:
        if field in body and body[field] is not None:
            update_payload[field] = body[field]

    if not update_payload:
        raise HTTPException(status_code=400, detail="No valid fields to update")

    # Validate dates if provided
    if "start_date" in update_payload or "end_date" in update_payload:
        from datetime import date as _date
        try:
            sd = _date.fromisoformat(update_payload.get("start_date", leave["start_date"]))
            ed = _date.fromisoformat(update_payload.get("end_date",   leave["end_date"]))
            if ed < sd:
                raise HTTPException(status_code=400, detail="end_date must be >= start_date")
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid date format")

    update_payload["updated_at"] = datetime.utcnow().isoformat()

    result = await sb.table("leave_applications") \
        .update(update_payload) \
        .eq("id", leave_id) \
        .eq("applicant_id", user["id"]) \
        .aexecute()

    return {"success": True, "application": result.data[0] if result.data else None}


@router.delete("/leave/{leave_id}")
async def cancel_or_delete_leave(
    leave_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id)
):
    """Cancel a pending leave, or delete a past (rejected/cancelled) leave application."""
    sb = get_supabase()

    existing = await sb.table("leave_applications") \
        .select("*") \
        .eq("id", leave_id) \
        .eq("applicant_id", user["id"]) \
        .eq("school_id", school_id) \
        .aexecute()

    if not existing.data:
        raise HTTPException(status_code=404, detail="Leave application not found")

    leave = existing.data[0]

    if leave["status"] == "pending":
        # Cancel pending leave
        await sb.table("leave_applications") \
            .update({"status": "cancelled", "updated_at": datetime.utcnow().isoformat()}) \
            .eq("id", leave_id) \
            .aexecute()
        return {"success": True, "message": "Leave application cancelled"}

    elif leave["status"] in ("rejected", "cancelled"):
        # Hard delete past rejected/cancelled leaves
        await sb.table("leave_applications") \
            .delete() \
            .eq("id", leave_id) \
            .eq("applicant_id", user["id"]) \
            .aexecute()
        return {"success": True, "message": "Leave application deleted"}

    else:
        raise HTTPException(
            status_code=400,
            detail="Cannot delete an approved leave. Contact admin to withdraw."
        )


@router.post("/leave/upload")
async def upload_leave_document(
    file: UploadFile = File(...),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Upload a leave supporting document to Supabase storage and save it in the documents table."""
    import uuid
    sb = get_supabase()

    # 1. Validate file
    if not file.filename:
        raise HTTPException(status_code=400, detail="Filename missing")
    
    ext = file.filename.split('.')[-1].lower() if '.' in file.filename else ''
    if ext not in ["pdf", "jpg", "jpeg", "png", "doc", "docx"]:
        raise HTTPException(status_code=400, detail="Invalid file type. Allowed: PDF, JPG, PNG, DOC, DOCX")

    file_bytes = await file.read()
    if len(file_bytes) == 0:
        raise HTTPException(status_code=400, detail="Empty file")
    if len(file_bytes) > 5 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="File too large. Maximum 5 MB.")

    # 2. Upload to Supabase Storage
    doc_id = str(uuid.uuid4())
    storage_path = f"documents/{user['id']}/{doc_id}.{ext}"
    supabase_url = settings.SUPABASE_URL.rstrip("/")
    storage_url = f"{supabase_url}/storage/v1/object/{storage_path}"
    
    content_type = file.content_type or "application/octet-stream"
    headers = {
        "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
        "Content-Type": content_type,
        "x-upsert": "true",
    }

    async with httpx.AsyncClient(timeout=30.0) as client:
        upload_response = await client.post(storage_url, headers=headers, content=file_bytes)

    if upload_response.status_code not in (200, 201):
        raise HTTPException(
            status_code=500,
            detail=f"Storage upload failed: {upload_response.text}"
        )

    from app.middleware.auth import get_public_supabase_url
    public_url_base = get_public_supabase_url(supabase_url)
    public_url = f"{public_url_base}/storage/v1/object/public/{storage_path}"

    # 3. Insert into documents table
    doc_data = {
        "id": doc_id,
        "school_id": school_id,
        "user_id": user["id"],
        "document_type": "leave_attachment",
        "file_name": file.filename,
        "file_url": public_url,
        "verification_status": "pending"
    }
    await sb.table("documents").insert(doc_data).aexecute()

    return {
        "success": True,
        "message": "Document uploaded successfully",
        "data": {
            "id": doc_id,
            "file_url": public_url,
            "file_name": file.filename
        }
    }


@router.get("/subjects")
async def get_all_subjects(class_name: Optional[str] = None, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    query = sb.table("subjects").select("*").eq("school_id", school_id)
    
    role = user.get("role")
    if role == "student":
        student_class = user.get("class")
        if not student_class:
            res_p = await sb.table("profiles").select("class").eq("id", user["id"]).aexecute()
            if res_p.data:
                student_class = res_p.data[0].get("class")
        if student_class:
            query = query.eq("class", student_class)
        else:
            return {"success": True, "school_id": school_id, "data": {"subjects": []}}
            
    elif role == "teacher":
        if class_name:
            query = query.eq("class", class_name)
        else:
            classes_res = await sb.table("timetable").select("class").eq("school_id", school_id).eq("teacher_id", user["id"]).aexecute()
            teacher_classes = list({row["class"] for row in classes_res.data if row.get("class")})
            if teacher_classes:
                query = query.in_("class", teacher_classes)
            else:
                query = query.eq("teacher_id", user["id"])
                
    else: # admin / student_admin / teacher_admin
        if class_name:
            query = query.eq("class", class_name)
            
    subjects = (await query.order("name").aexecute()).data or []
    return {"success": True, "school_id": school_id, "data": {"subjects": subjects}}