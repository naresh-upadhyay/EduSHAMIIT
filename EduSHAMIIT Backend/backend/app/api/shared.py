from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from typing import Optional
import httpx
import os
from datetime import datetime

from app.middleware.auth import get_current_user, require_school_id
from app.services.supabase_client import get_supabase

router = APIRouter()


@router.get("/messages")
async def get_messages(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    
    # 1. Fetch all groups user is in
    memberships = (await sb.table("group_members").select("*, groups!group_id(*)").eq("member_id", user['id']).aexecute()).data
    group_ids = [m['group_id'] for m in memberships if m.get('group_id')]
    
    # 2. Build the initial set of active group conversation placeholders
    conversations = {}
    for m in memberships:
        g = m.get("groups")
        if g:
            conversations[f"group_{g['id']}"] = {
                "id": g["id"],
                "name": g["name"],
                "avatar_url": g.get("avatar_url"),
                "type": "group",
                "last_message": "No messages yet",
                "last_message_time": g["created_at"],
                "unread_count": 0
            }
            
    # 3. Construct OR query to fetch relevant messages
    # Either user is sender, user is receiver, or the message belongs to a group the user is in
    or_cond = f"sender_id.eq.{user['id']},receiver_id.eq.{user['id']}"
    if group_ids:
        group_conds = ",".join([f"group_id.eq.{gid}" for gid in group_ids])
        or_cond += f",{group_conds}"
        
    messages = (await sb.table("messages")
                .select("*, sender:profiles!sender_id(full_name, avatar_url, role), receiver:profiles!receiver_id(full_name, avatar_url, role), groups:groups!group_id(name, avatar_url)")
                .eq("school_id", school_id)
                .or_(or_cond)
                .order("created_at", ascending=False)
                .aexecute()).data
                
    # 4. Aggregate messages into conversation buckets
    for msg in messages:
        is_read = msg.get("is_read", False)
        sender_id = msg.get("sender_id")
        receiver_id = msg.get("receiver_id")
        group_id = msg.get("group_id")
        created_at = msg.get("created_at")
        content = msg.get("content")
        
        if group_id:
            key = f"group_{group_id}"
            if key in conversations:
                # If placeholder has not been replaced by a real message, replace it
                if conversations[key]["last_message"] == "No messages yet":
                    conversations[key]["last_message"] = content
                    conversations[key]["last_message_time"] = created_at
                # Count unread group messages (sent by others)
                if sender_id != user["id"] and not is_read:
                    conversations[key]["unread_count"] += 1
            else:
                g = msg.get("groups")
                name = g.get("name", "Unknown Group") if g else "Unknown Group"
                avatar = g.get("avatar_url") if g else None
                conversations[key] = {
                    "id": group_id,
                    "name": name,
                    "avatar_url": avatar,
                    "type": "group",
                    "last_message": content,
                    "last_message_time": created_at,
                    "unread_count": 1 if (sender_id != user["id"] and not is_read) else 0
                }
        else:
            contact_id = receiver_id if sender_id == user["id"] else sender_id
            key = f"user_{contact_id}"
            
            if key not in conversations:
                p = msg.get("receiver") if sender_id == user["id"] else msg.get("sender")
                name = p.get("full_name", "Unknown User") if p else "Unknown User"
                avatar = p.get("avatar_url") if p else None
                role = p.get("role", "student") if p else "student"
                
                conversations[key] = {
                    "id": contact_id,
                    "name": name,
                    "avatar_url": avatar,
                    "role": role,
                    "type": "direct",
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
    receiver_id = request.get("receiver_id")
    group_id = request.get("group_id")
    content = request.get("content")
    
    if not content:
        raise HTTPException(status_code=400, detail="Content cannot be empty")
        
    payload = {
        "school_id": school_id,
        "sender_id": user["id"],
        "content": content
    }
    
    if group_id:
        payload["group_id"] = group_id
    else:
        payload["receiver_id"] = receiver_id
        if receiver_id:
            try:
                blocks_res = await sb.table("blocked_users").select("blocker_id, blocked_id").or_(f"blocker_id.eq.{user['id']},blocked_id.eq.{user['id']}").aexecute()
                if blocks_res.data:
                    blocked_user_ids = {row["blocker_id"] for row in blocks_res.data} | {row["blocked_id"] for row in blocks_res.data}
                    if receiver_id in blocked_user_ids:
                        raise HTTPException(status_code=403, detail="Messaging is blocked with this user")
            except HTTPException:
                raise
            except Exception as e:
                print(f"Error checking blocks in send_message: {e}")
        
    message = await sb.table("messages").insert(payload).aexecute()
    if not message.data:
        raise HTTPException(status_code=500, detail="Failed to send message")
        
    return {"success": True, "school_id": school_id, "data": {"message": message.data[0]}}


@router.get("/messages/chat")
async def get_chat(chat_id: str = "", user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    if not chat_id:
        return {"success": True, "school_id": school_id, "data": {"messages": []}}
        
    # Check if chat_id matches a study group
    group_res = await sb.table("groups").select("*").eq("id", chat_id).maybe_single().aexecute()
    
    if group_res.data:
        # Fetch group messages and include sender profiles
        messages = (await sb.table("messages")
                    .select("*, profiles!sender_id(full_name, avatar_url, role)")
                    .eq("group_id", chat_id)
                    .order("created_at")
                    .aexecute()).data
    else:
        # Fetch private direct messages between user and contact
        res1 = await sb.table("messages").select("*, profiles!sender_id(full_name, avatar_url, role)").eq("school_id", school_id).eq("sender_id", user['id']).eq("receiver_id", chat_id).aexecute()
        res2 = await sb.table("messages").select("*, profiles!sender_id(full_name, avatar_url, role)").eq("school_id", school_id).eq("sender_id", chat_id).eq("receiver_id", user['id']).aexecute()
        messages = res1.data + res2.data
        messages.sort(key=lambda x: x['created_at'])
        
        # Mark incoming messages as read
        await sb.table("messages").update({"is_read": True, "read_at": "now()"}).eq("sender_id", chat_id).eq("receiver_id", user['id']).eq("is_read", False).aexecute()
        
    return {"success": True, "school_id": school_id, "data": {"messages": messages}}


@router.get("/users/search")
async def search_users(q: str = "", user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    query_builder = sb.table("profiles").select("id, full_name, avatar_url, role").eq("school_id", school_id).neq("id", user["id"])
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
async def update_user_settings(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    await sb.table("user_settings").upsert({"school_id": school_id, "user_id": user["id"], **request}, on_conflict="user_id").aexecute()
    return {"success": True}


@router.get("/groups/{group_id}/members")
async def get_group_members(group_id: str, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    members = (await sb.table("group_members")
               .select("role, profiles:member_id(id, full_name, avatar_url, role)")
               .eq("group_id", group_id)
               .aexecute()).data
               
    formatted_members = []
    for m in members:
        p = m.get("profiles")
        if p:
            formatted_members.append({
                "id": p["id"],
                "full_name": p["full_name"],
                "avatar_url": p.get("avatar_url"),
                "role": p.get("role", "student"),
                "group_role": m.get("role", "member")
            })
            
    return {"success": True, "data": {"members": formatted_members}}


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
    supabase_url = os.environ.get("SUPABASE_URL", "")
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
        "Authorization": f"Bearer {os.environ.get('SUPABASE_SERVICE_ROLE_KEY')}",
        "Content-Type": content_type
    }
    
    async with httpx.AsyncClient() as client:
        # Upload to Supabase storage bucket "avatars" using service role bypass
        upload_response = await client.post(storage_url, headers=headers, content=image_bytes)
        if upload_response.status_code not in (200, 201):
            put_response = await client.put(storage_url, headers=headers, content=image_bytes)
            if put_response.status_code not in (200, 201):
                raise HTTPException(status_code=500, detail=f"Failed to upload group image: {put_response.text}")
                
    timestamp = int(datetime.now().timestamp())
    public_url_base_replaced = public_url_base.replace("http://kong:8000", "http://127.0.0.1:8000")
    public_url = f"{public_url_base_replaced}/storage/v1/object/public/{storage_path}?t={timestamp}"
    
    await sb.table("groups").update({"avatar_url": public_url}).eq("id", group_id).aexecute()
    return {"success": True, "data": {"avatar_url": public_url}}


@router.post("/groups/create")
async def create_group(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    name = request.get("name")
    description = request.get("description")
    group_level = request.get("group_level", "school")
    class_name = request.get("class_name")
    
    if not name:
        raise HTTPException(status_code=400, detail="Group name is required")
        
    user_role = user.get("role", "student")
    user_class = user.get("class")
    
    # 1. Enforce student/teacher roles & constraints
    if user_role == "student":
        # Students can ONLY create class-level groups for their own class
        group_level = "class"
        if not user_class:
            raise HTTPException(status_code=400, detail="Student must be assigned to a class to create a group")
        class_name = user_class
    else:
        # Teachers or senior level like principal/hod/admin can choose school or class level
        if group_level == "class" and not class_name:
            raise HTTPException(status_code=400, detail="class_name is required for Class Level groups")

    # 2. Insert the group
    group_res = await sb.table("groups").insert({
        "school_id": school_id,
        "name": name,
        "description": description,
        "created_by": user["id"],
        "group_level": group_level,
        "class_name": class_name if group_level == "class" else None
    }).aexecute()
    
    if not group_res.data:
        raise HTTPException(status_code=500, detail="Failed to create group")
        
    group_id = group_res.data[0]["id"]
    
    # 3. Automatically add creator to group_members as admin
    await sb.table("group_members").insert({
        "group_id": group_id,
        "member_id": user["id"],
        "role": "admin"
    }).aexecute()
    
    # 4. If Class Level and created by Student, automatically add all students of that class by default!
    if group_level == "class" and user_role == "student":
        try:
            students_res = await sb.table("profiles").select("id").eq("school_id", school_id).eq("role", "student").eq("class", class_name).aexecute()
            if students_res.data:
                member_inserts = []
                for s in students_res.data:
                    if s["id"] == user["id"]:
                        continue
                    member_inserts.append({
                        "group_id": group_id,
                        "member_id": s["id"],
                        "role": "member"
                    })
                if member_inserts:
                    await sb.table("group_members").insert(member_inserts).aexecute()
        except Exception as e:
            print(f"Error auto-populating class students: {str(e)}")
            
    return {"success": True, "school_id": school_id, "data": {"group": group_res.data[0]}}


@router.get("/groups")
async def get_groups(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    
    # Fetch user memberships
    memberships = (await sb.table("group_members").select("group_id").eq("member_id", user['id']).aexecute()).data
    member_group_ids = {m['group_id'] for m in memberships if m.get('group_id')}
    
    user_role = user.get("role", "student")
    user_class = user.get("class")
    
    # Filter groups based on role
    if user_role == "student":
        # Students only see:
        # 1. Groups they are already members of (regardless of level)
        # 2. Class level groups for their own class (so they can join them)
        if user_class:
            in_cond = ",".join([f"'{gid}'" for gid in member_group_ids]) if member_group_ids else "'00000000-0000-0000-0000-000000000000'"
            groups = (await sb.table("groups")
                      .select("*")
                      .eq("school_id", school_id)
                      .or_(f"class_name.eq.{user_class},id.in.({in_cond})")
                      .aexecute()).data
        else:
            in_cond = ",".join([f"'{gid}'" for gid in member_group_ids]) if member_group_ids else "'00000000-0000-0000-0000-000000000000'"
            groups = (await sb.table("groups")
                      .select("*")
                      .eq("school_id", school_id)
                      .or_(f"id.in.({in_cond})")
                      .aexecute()).data
    else:
        # Teachers/principals/HODs/admins see all groups in the school
        groups = (await sb.table("groups").select("*").eq("school_id", school_id).aexecute()).data
        
    for g in groups:
        g['is_member'] = g['id'] in member_group_ids
        
    return {"success": True, "school_id": school_id, "data": {"groups": groups}}


@router.post("/groups/{group_id}/join")
async def join_group(group_id: str, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    # Insert record into group_members
    await sb.table("group_members").insert({
        "group_id": group_id,
        "member_id": user["id"],
        "role": "member"
    }).aexecute()
    return {"success": True, "message": "Joined group successfully"}


@router.post("/groups/{group_id}/members")
async def add_group_member(group_id: str, request: dict, user=Depends(get_current_user)):
    sb = get_supabase()
    member_id = request.get("member_id")
    if not member_id:
        raise HTTPException(status_code=400, detail="member_id is required")
        
    try:
        blocks_res = await sb.table("blocked_users").select("blocker_id, blocked_id").or_(f"blocker_id.eq.{user['id']},blocked_id.eq.{user['id']}").aexecute()
        if blocks_res.data:
            blocked_user_ids = {row["blocker_id"] for row in blocks_res.data} | {row["blocked_id"] for row in blocks_res.data}
            if member_id in blocked_user_ids:
                raise HTTPException(status_code=403, detail="Cannot add user to group because one of you has blocked the other")
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error checking blocks in add_group_member: {e}")

    # Check if already a member to prevent duplicate key error
    existing = await sb.table("group_members").select("*").eq("group_id", group_id).eq("member_id", member_id).maybe_single().aexecute()
    if existing.data:
        return {"success": True, "message": "User is already a member of this group"}
        
    # Insert record into group_members
    await sb.table("group_members").insert({
        "group_id": group_id,
        "member_id": member_id,
        "role": "member"
    }).aexecute()
    return {"success": True, "message": "Member added successfully"}


@router.post("/groups/{group_id}/leave")
async def leave_group(group_id: str, user=Depends(get_current_user)):
    sb = get_supabase()
    await sb.table("group_members").delete().eq("group_id", group_id).eq("member_id", user["id"]).aexecute()
    return {"success": True, "message": "Left group successfully"}



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
    msg = await sb.table("messages").select("sender_id").eq("id", message_id).maybe_single().aexecute()
    if not msg.data:
        raise HTTPException(status_code=404, detail="Message not found")
    if msg.data["sender_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="You can only delete your own messages")
        
    await sb.table("messages").delete().eq("id", message_id).aexecute()
    return {"success": True}


@router.post("/messages/clear")
async def clear_chat(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    chat_id = request.get("chat_id")
    if not chat_id:
        raise HTTPException(status_code=400, detail="chat_id is required")
        
    sb = get_supabase()
    group_check = await sb.table("groups").select("id").eq("id", chat_id).maybe_single().aexecute()
    if group_check.data:
        await sb.table("messages").delete().eq("group_id", chat_id).aexecute()
    else:
        await sb.table("messages").delete().eq("school_id", school_id).eq("sender_id", user["id"]).eq("receiver_id", chat_id).aexecute()
        await sb.table("messages").delete().eq("school_id", school_id).eq("sender_id", chat_id).eq("receiver_id", user["id"]).aexecute()
        
    return {"success": True}


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
        
    supabase_url = os.environ.get("SUPABASE_URL", "")
    public_url_base = os.environ.get("PUBLIC_URL", supabase_url)
    
    content_type = file.content_type or "application/octet-stream"
    filename = file.filename or "file.bin"
    
    # Secure file extension
    ext = "bin"
    if "." in filename:
        ext = filename.split(".")[-1]
        
    import uuid
    unique_id = uuid.uuid4().hex
    storage_path = f"avatars/msg_{user['id']}_{unique_id}.{ext}"
    storage_url = f"{supabase_url}/storage/v1/object/{storage_path}"
    
    headers = {
        "Authorization": f"Bearer {os.environ.get('SUPABASE_SERVICE_ROLE_KEY')}",
        "Content-Type": content_type
    }
    
    async with httpx.AsyncClient() as client:
        upload_response = await client.post(storage_url, headers=headers, content=file_bytes)
        if upload_response.status_code not in (200, 201):
            put_response = await client.put(storage_url, headers=headers, content=file_bytes)
            if put_response.status_code not in (200, 201):
                raise HTTPException(status_code=500, detail=f"Upload failed: {put_response.text}")
                
    public_url = f"{public_url_base}/storage/v1/object/public/{storage_path}"
    return {
        "success": True, 
        "data": {
            "url": public_url, 
            "filename": filename, 
            "content_type": content_type
        }
    }


@router.post("/user/logout")
async def logout():
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
        # Unique constraint violation means already blocked
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
    group = await sb.table("groups").select("*").eq("id", group_id).maybe_single().aexecute()
    if not group.data:
        raise HTTPException(status_code=404, detail="Group not found")
        
    if group.data["created_by"] != user["id"]:
        raise HTTPException(status_code=403, detail="Only the group creator/admin can delete the group")
        
    members = await sb.table("group_members").select("*").eq("group_id", group_id).aexecute()
    if len(members.data) > 1:
        raise HTTPException(status_code=400, detail="Groups with more than 1 member cannot be deleted by creator until they are the only remaining member.")
        
    await sb.table("groups").delete().eq("id", group_id).aexecute()
    return {"success": True, "message": "Group deleted successfully"}


@router.delete("/groups/{group_id}/members/{member_id}")
async def remove_group_member(group_id: str, member_id: str, user=Depends(get_current_user)):
    sb = get_supabase()
    group = await sb.table("groups").select("created_by").eq("id", group_id).maybe_single().aexecute()
    if not group.data:
        raise HTTPException(status_code=404, detail="Group not found")
        
    if group.data["created_by"] != user["id"]:
        membership = await sb.table("group_members").select("role").eq("group_id", group_id).eq("member_id", user["id"]).maybe_single().aexecute()
        if not membership.data or membership.data["role"] != "admin":
            raise HTTPException(status_code=403, detail="Only admins have permission to remove members")
            
    if member_id == user["id"]:
        raise HTTPException(status_code=400, detail="Cannot remove yourself. Use leave group instead.")
        
    await sb.table("group_members").delete().eq("group_id", group_id).eq("member_id", member_id).aexecute()
    return {"success": True, "message": "Member removed successfully"}