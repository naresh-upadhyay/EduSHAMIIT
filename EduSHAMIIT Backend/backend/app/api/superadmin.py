from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File, Request
from typing import Optional, List
from datetime import datetime, timedelta
import uuid
from app.config import settings

from app.middleware.auth import (
    get_current_user,
    require_any_role,
)
from app.services.supabase_client import get_supabase

router = APIRouter()
vault_router = APIRouter()

# Verify director/super_admin access
require_super_admin_or_director = require_any_role("super_admin", "director")

# ===========================================================
# Roles CRUD Schemas & Endpoints
# ===========================================================
from pydantic import BaseModel

class RoleCreateRequest(BaseModel):
    name: str
    code: Optional[str] = None
    description: Optional[str] = None
    permissions: List[str] = []
    draft_permissions: Optional[List[str]] = None
    status: Optional[str] = "Active"

class RoleUpdateRequest(BaseModel):
    name: Optional[str] = None
    code: Optional[str] = None
    description: Optional[str] = None
    permissions: Optional[List[str]] = None
    draft_permissions: Optional[List[str]] = None
    status: Optional[str] = None

def count_allowed_permissions(perms_list: list) -> int:
    if not perms_list:
        return 0
    count = 0
    for p in perms_list:
        p_str = str(p)
        if ":" in p_str and p_str.endswith(":allow"):
            count += 1
    return count

def check_pending_publish(perms: list, draft: list) -> bool:
    if not draft:
        return False
    p_set = set(str(x) for x in perms if ":" in str(x))
    d_set = set(str(x) for x in draft if ":" in str(x))
    return p_set != d_set

def augment_role_metadata(role: dict) -> dict:
    if role.get("name") == "super_admin":
        role["permissions_count"] = 108
        role["draft_permissions_count"] = 108
        role["has_pending_publish"] = False
    else:
        perms = role.get("permissions") or []
        draft = role.get("draft_permissions") or []
        role["permissions_count"] = count_allowed_permissions(perms)
        role["draft_permissions_count"] = count_allowed_permissions(draft)
        role["has_pending_publish"] = check_pending_publish(perms, draft)
    return role

@router.get("/roles")
async def list_roles(
    user=Depends(require_super_admin_or_director),
):
    """List all application roles and calculate dynamic user counts per role."""
    sb = get_supabase()
    
    # 1. Fetch roles
    roles_res = await sb.table("app_roles").select("*").order("name").aexecute()
    roles = roles_res.data or []
    
    # 2. Get user counts per role dynamically from profiles table
    try:
        profiles_res = await sb.table("profiles").select("role").aexecute()
        profiles = profiles_res.data or []
        
        role_counts = {}
        for p in profiles:
            role_name = p.get("role")
            if role_name:
                role_counts[role_name] = role_counts.get(role_name, 0) + 1
                
        for r in roles:
            r["user_count"] = role_counts.get(r["name"], 0)
            augment_role_metadata(r)
    except Exception as e:
        print(f"Error fetching role user counts: {e}", flush=True)
        for r in roles:
            r["user_count"] = 0
            augment_role_metadata(r)
            
    # All system permissions that can be assigned
    system_permissions = [
        "view_courses",
        "submit_assignments",
        "view_grades",
        "view_attendance",
        "grade_assignments",
        "manage_classes",
        "manage_users",
        "view_reports",
        "manage_admissions",
        "manage_infra",
        "manage_roles",
        "manage_finance",
        "manage_staff",
        "manage_payroll",
        "manage_transport",
        "manage_library",
        "view_logs",
        "manage_sports",
        "manage_support",
        "manage_hostel",
        "manage_exams"
    ]
            
    return {
        "success": True,
        "data": roles,
        "system_permissions": system_permissions
    }

@router.post("/roles")
async def create_role(
    req: RoleCreateRequest,
    user=Depends(require_super_admin_or_director),
):
    """Create a new custom user role."""
    sb = get_supabase()
    
    role_name = req.name.strip()
    if not role_name:
        raise HTTPException(status_code=400, detail="Role name cannot be empty")
        
    # Check if role name already exists (case-insensitive check)
    exists = await sb.table("app_roles").select("id").ilike("name", role_name).aexecute()
    if exists.data:
        raise HTTPException(status_code=400, detail=f"Role with name '{role_name}' already exists")
        
    role_code = req.code.strip() if req.code else f"ROLE_{role_name.upper().replace(' ', '_')}"
    # Check if role code already exists
    code_exists = await sb.table("app_roles").select("id").eq("code", role_code).aexecute()
    if code_exists.data:
        raise HTTPException(status_code=400, detail=f"Role with code '{role_code}' already exists")
        
    # Insert new role
    payload = {
        "name": role_name,
        "code": role_code,
        "description": req.description,
        "permissions": req.permissions,
        "draft_permissions": req.draft_permissions or req.permissions or [],
        "is_custom": True,
        "status": req.status or "Active"
    }
    
    res = await sb.table("app_roles").insert(payload).aexecute()
    if not res.data:
        raise HTTPException(status_code=500, detail="Failed to create role")
        
    res_data = augment_role_metadata(res.data[0])
    return {"success": True, "data": res_data}

@router.put("/roles/{role_id}")
async def update_role(
    role_id: str,
    req: RoleUpdateRequest,
    user=Depends(require_super_admin_or_director),
):
    """Update custom or system role details."""
    sb = get_supabase()
    
    # 1. Fetch current role
    role_res = await sb.table("app_roles").select("*").eq("id", role_id).aexecute()
    if not role_res.data:
        raise HTTPException(status_code=404, detail="Role not found")
        
    curr_role = role_res.data[0]
    
    payload = {}
    # Prevent changing name or code of core system roles (is_custom = False)
    if not curr_role["is_custom"]:
        if req.name and req.name.strip() != curr_role["name"]:
            raise HTTPException(status_code=400, detail="Cannot rename built-in system roles")
        if req.code and req.code.strip() != curr_role["code"]:
            raise HTTPException(status_code=400, detail="Cannot modify built-in system role codes")
    else:
        if req.name:
            new_name = req.name.strip()
            if new_name != curr_role["name"]:
                # Ensure new name is unique
                exists = await sb.table("app_roles").select("id").ilike("name", new_name).aexecute()
                if exists.data:
                    raise HTTPException(status_code=400, detail=f"Role with name '{new_name}' already exists")
                payload["name"] = new_name
        if req.code:
            new_code = req.code.strip()
            if new_code != curr_role["code"]:
                # Ensure new code is unique
                exists = await sb.table("app_roles").select("id").eq("code", new_code).aexecute()
                if exists.data:
                    raise HTTPException(status_code=400, detail=f"Role with code '{new_code}' already exists")
                payload["code"] = new_code

    if req.permissions is not None:
        payload["permissions"] = req.permissions
    if req.draft_permissions is not None:
        payload["draft_permissions"] = req.draft_permissions
    if req.description is not None:
        payload["description"] = req.description
    if req.status is not None:
        payload["status"] = req.status
        
    if not payload:
        return {"success": True, "data": augment_role_metadata(curr_role)}
        
    res = await sb.table("app_roles").update(payload).eq("id", role_id).aexecute()
    if not res.data:
        raise HTTPException(status_code=500, detail="Failed to update role")
        
    res_data = augment_role_metadata(res.data[0])
    return {"success": True, "data": res_data}

@router.post("/roles/{role_id}/publish")
async def publish_role_permissions(
    role_id: str,
    user=Depends(require_super_admin_or_director),
):
    """Publish draft permissions to active permissions."""
    sb = get_supabase()
    
    # 1. Fetch current role
    role_res = await sb.table("app_roles").select("*").eq("id", role_id).aexecute()
    if not role_res.data:
        raise HTTPException(status_code=404, detail="Role not found")
        
    curr_role = role_res.data[0]
    draft_perms = curr_role.get("draft_permissions") or []
    
    # 2. Update permissions to match draft_permissions
    res = await sb.table("app_roles").update({
        "permissions": draft_perms
    }).eq("id", role_id).aexecute()
    
    if not res.data:
        raise HTTPException(status_code=500, detail="Failed to publish permissions")
        
    res_data = augment_role_metadata(res.data[0])
    return {"success": True, "data": res_data}

@router.delete("/roles/{role_id}")
async def delete_role(
    role_id: str,
    user=Depends(require_super_admin_or_director),
):
    """Delete a custom user role."""
    sb = get_supabase()
    
    # 1. Fetch current role
    role_res = await sb.table("app_roles").select("*").eq("id", role_id).aexecute()
    if not role_res.data:
        raise HTTPException(status_code=404, detail="Role not found")
        
    curr_role = role_res.data[0]
    
    # Block deleting built-in roles
    # if not curr_role["is_custom"]:
    #     raise HTTPException(status_code=400, detail="Cannot delete built-in core system roles")
        
    # Check if any user is currently assigned this role
    users_with_role = await sb.table("profiles").select("id").eq("role", curr_role["name"]).aexecute()
    if users_with_role.data:
        raise HTTPException(status_code=400, detail=f"Cannot delete role '{curr_role['name']}' as it is currently assigned to users")
        
    await sb.table("app_roles").delete().eq("id", role_id).aexecute()
    return {"success": True, "message": f"Role '{curr_role['name']}' deleted successfully"}

# ===========================================================
# Schools CRUD
# ===========================================================

@router.get("")
async def list_schools(
    user=Depends(require_super_admin_or_director),
):
    """List all schools/institutes in the system with subscription info and student counts."""
    sb = get_supabase()
    
    # 1. Fetch schools
    res = await sb.table("schools").select("*").order("name").aexecute()
    schools = res.data or []
    
    # 2. Fetch profiles to count them
    try:
        profiles_res = await sb.table("profiles").select("school_id").aexecute()
        profiles = profiles_res.data or []
        
        # Aggregate counts by school_id
        user_counts = {}
        for p in profiles:
            sid = p.get("school_id")
            if sid:
                user_counts[sid] = user_counts.get(sid, 0) + 1
                
        # Inject counts into response
        for s in schools:
            sid = s.get("id")
            s["existing_users"] = user_counts.get(sid, 0)
    except Exception as e:
        print(f"Error fetching user counts: {e}", flush=True)
        for s in schools:
            s["existing_users"] = 0
            
    return {"success": True, "data": {"schools": schools, "count": len(schools)}}

@router.post("")
async def create_school(
    payload: dict,
    user=Depends(require_super_admin_or_director),
):
    """Create a new school/institute with subscription specs."""
    name = payload.get("name")
    if not name:
        raise HTTPException(status_code=400, detail="School name is required")
        
    sb = get_supabase()
    school_id = str(uuid.uuid4())
    
    # Pricing & Subscription info
    pricing_model = payload.get("pricing_model", "per_student")
    pricing_rate = float(payload.get("pricing_rate", 10.00))
    max_students = int(payload.get("max_students", 1000))
    subscription_status = payload.get("subscription_status", "active")
    subscription_tier = payload.get("subscription_tier", "premium")
    
    # Expiry Dates
    start_date = payload.get("subscription_start_date") or datetime.utcnow().isoformat()
    end_date = payload.get("subscription_end_date") or (datetime.utcnow() + timedelta(days=365)).isoformat()

    # Owner details
    owner_name = payload.get("owner_name") or "School Administrator"
    owner_email = payload.get("owner_email")
    send_renewal_reminders = payload.get("send_renewal_reminders", True)

    school_data = {
        "id": school_id,
        "name": name,
        "address": payload.get("address"),
        "phone": payload.get("phone"),
        "logo_url": payload.get("logo_url"),
        "subscription_status": subscription_status,
        "subscription_tier": subscription_tier,
        "subscription_start_date": start_date,
        "subscription_end_date": end_date,
        "pricing_model": pricing_model,
        "pricing_rate": pricing_rate,
        "max_students": max_students,
        "owner_name": owner_name,
        "owner_email": owner_email,
        "send_renewal_reminders": send_renewal_reminders
    }

    try:
        # Create school record
        school_res = await sb.table("schools").insert(school_data).aexecute()
        
        # Only create a mail subscription if the user explicitly opted in (mail_plan_code present)
        if payload.get("mail_plan_code"):
            mail_plan = payload["mail_plan_code"]
            rate = 0.10
            limit = 5000
            size_limit = 1024.00
            mail_pricing_model = "per_email"
            
            if mail_plan == "mail_starter":
                limit = 5000
                rate = 0.10
                mail_pricing_model = "per_email"
                size_limit = 1024.00
            elif mail_plan == "mail_growth":
                limit = 25000
                rate = 0.08
                mail_pricing_model = "per_email"
                size_limit = 5120.00
            elif mail_plan == "mail_enterprise":
                limit = 1000000
                rate = 0.05
                mail_pricing_model = "monthly_flat"
                size_limit = 102400.00

            mail_sub_data = {
                "school_id": school_id,
                "enabled": True,
                "pricing_model": payload.get("mail_pricing_model") or mail_pricing_model,
                "rate_per_unit": float(payload.get("rate_per_unit") or rate),
                "monthly_limit": int(payload.get("monthly_limit") or limit),
                "emails_sent": 0,
                "mail_plan_code": mail_plan,
                "mail_host": payload.get("mail_host") or "smtp.gmail.com",
                "mail_port": int(payload.get("mail_port") or 587),
                "mail_username": payload.get("mail_username"),
                "mail_password": payload.get("mail_password"),
                "mail_server_size_limit_mb": float(payload.get("mail_server_size_limit_mb") or size_limit),
                "mail_server_size_used_mb": float(payload.get("mail_server_size_used_mb") or 0.00)
            }
            await sb.table("school_mail_subscriptions").insert(mail_sub_data).aexecute()
        
        return {"success": True, "data": {"school": school_res.data}}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create school: {str(e)}")

@router.put("/{school_id}")
async def update_school(
    school_id: str,
    payload: dict,
    user=Depends(require_super_admin_or_director),
):
    """Update school details and subscription settings."""
    print("PAYLOAD RECEIVED IN UPDATE_SCHOOL:", payload, flush=True)
    sb = get_supabase()
    
    # Check if school exists
    check_res = await sb.table("schools").select("id").eq("id", school_id).aexecute()
    if not check_res.data:
        raise HTTPException(status_code=404, detail="School not found")
        
    update_data = {}
    for key in [
        "name", "address", "phone", "logo_url",
        "subscription_status", "subscription_tier",
        "subscription_start_date", "subscription_end_date",
        "pricing_model", "pricing_rate", "max_students",
        "owner_name", "owner_email", "send_renewal_reminders",
        "module_toggles"
    ]:
        if key in payload:
            update_data[key] = payload[key]

    try:
        # Update school record
        res = await sb.table("schools").update(update_data).eq("id", school_id).aexecute()

        # Handle mail subscription based on enable_mail_server flag
        enable_mail = payload.get("enable_mail_server")

        # Fetch existing subscription (if any)
        check_mail = await sb.table("school_mail_subscriptions").select("id").eq("school_id", school_id).aexecute()
        existing_mail = check_mail.data[0] if check_mail.data else None

        if enable_mail is False:
            # User explicitly disabled mail server — disable the subscription row if it exists
            if existing_mail:
                await sb.table("school_mail_subscriptions").update({"enabled": False}).eq("school_id", school_id).aexecute()
                print(f"Mail subscription DISABLED for school {school_id}", flush=True)

        elif enable_mail is True:
            # User enabled mail server — build the update dict from provided mail fields
            mail_keys = [
                "mail_plan_code", "mail_host", "mail_port", "mail_username",
                "mail_password", "mail_server_size_limit_mb"
            ]
            mail_update = {"enabled": True}  # always re-enable when toggled on
            for key in mail_keys:
                if key in payload:
                    if key == "mail_port":
                        mail_update[key] = int(payload[key])
                    elif key == "mail_server_size_limit_mb":
                        mail_update[key] = float(payload[key])
                    else:
                        mail_update[key] = payload[key]

            # Auto-fill limits based on selected plan
            if "mail_plan_code" in mail_update:
                plan = mail_update["mail_plan_code"]
                if plan == "mail_starter":
                    mail_update.setdefault("monthly_limit", 5000)
                    mail_update.setdefault("rate_per_unit", 0.10)
                    mail_update.setdefault("pricing_model", "per_email")
                elif plan == "mail_growth":
                    mail_update.setdefault("monthly_limit", 25000)
                    mail_update.setdefault("rate_per_unit", 0.08)
                    mail_update.setdefault("pricing_model", "per_email")
                elif plan == "mail_enterprise":
                    mail_update.setdefault("monthly_limit", 1000000)
                    mail_update.setdefault("rate_per_unit", 0.05)
                    mail_update.setdefault("pricing_model", "monthly_flat")

            print(f"Mail UPDATE payload for school {school_id}: {mail_update}", flush=True)

            if existing_mail:
                # Update existing subscription
                await sb.table("school_mail_subscriptions").update(mail_update).eq("school_id", school_id).aexecute()
            else:
                # No subscription yet — create one with defaults
                new_mail = {
                    "school_id": school_id,
                    "enabled": True,
                    "pricing_model": "per_email",
                    "rate_per_unit": 0.10,
                    "monthly_limit": 5000,
                    "emails_sent": 0,
                    "mail_host": "smtp.gmail.com",
                    "mail_port": 587,
                    "mail_server_size_limit_mb": 1024.00,
                    "mail_server_size_used_mb": 0.00,
                    "mail_plan_code": "mail_starter",
                    **mail_update,
                }
                await sb.table("school_mail_subscriptions").insert(new_mail).aexecute()
                print(f"Mail subscription CREATED for school {school_id}", flush=True)
        # If enable_mail_server is not in payload at all, do nothing to mail subscription

        return {"success": True, "data": {"school": res.data}}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to update school: {str(e)}")

@router.delete("/{school_id}")
async def delete_school(
    school_id: str,
    user=Depends(require_super_admin_or_director),
):
    """Delete a school and its associated data."""
    sb = get_supabase()
    
    # Check if school exists
    check_res = await sb.table("schools").select("id").eq("id", school_id).aexecute()
    if not check_res.data:
        raise HTTPException(status_code=404, detail="School not found")
        
    try:
        await sb.table("schools").delete().eq("id", school_id).aexecute()
        return {"success": True, "detail": "School deleted successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to delete school: {str(e)}")

@router.post("/upload-logo")
async def upload_school_logo(
    file: UploadFile = File(...),
    user=Depends(require_super_admin_or_director),
):
    """Upload a school logo and return its public URL."""
    image_bytes = await file.read()
    if len(image_bytes) == 0:
        raise HTTPException(status_code=400, detail="Empty image file")
    if len(image_bytes) > 2 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="Image too large. Maximum 2 MB.")

    content_type = file.content_type or "application/octet-stream"
    if content_type == "application/octet-stream":
        if file.filename and file.filename.lower().endswith(".png"):
            content_type = "image/png"
        else:
            content_type = "image/jpeg"

    # Determine extension
    ext_map = {"image/jpeg": "jpg", "image/png": "png", "image/webp": "webp", "image/gif": "gif"}
    ext = ext_map.get(content_type, "jpg")
    
    # Generate unique filename
    filename = f"school_logo_{int(datetime.utcnow().timestamp())}_{uuid.uuid4().hex[:8]}.{ext}"
    storage_path = f"schools/{filename}"

    # Upload to Supabase Storage via REST API
    from app.config import settings
    supabase_url = settings.SUPABASE_URL.rstrip("/")
    storage_url = f"{supabase_url}/storage/v1/object/avatars/{storage_path}"
    headers = {
        "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
        "Content-Type": content_type,
        "x-upsert": "true",
    }

    import httpx
    async with httpx.AsyncClient(timeout=30.0) as client:
        upload_response = await client.post(storage_url, headers=headers, content=image_bytes)

    if upload_response.status_code not in (200, 201):
        raise HTTPException(
            status_code=500,
            detail=f"Storage upload failed: {upload_response.text}"
        )

    # Build public URL with a cache-busting query parameter
    timestamp = int(datetime.utcnow().timestamp())
    from app.middleware.auth import get_public_supabase_url
    public_url_base = get_public_supabase_url(supabase_url)
    public_url = f"{public_url_base}/storage/v1/object/public/avatars/{storage_path}?t={timestamp}"

    return {"success": True, "data": {"logo_url": public_url}}


# ===========================================================
# Mail Subscriptions
# ===========================================================

@router.get("/mail-subscriptions")
async def get_mail_subscriptions(
    user=Depends(require_super_admin_or_director),
):
    """Get all mail subscriptions along with school names."""
    sb = get_supabase()
    schools_res = await sb.table("schools").select("id, name, owner_email, owner_name").aexecute()
    mail_res = await sb.table("school_mail_subscriptions").select("*").aexecute()
    
    schools = {s["id"]: s for s in (schools_res.data or [])}
    mail_subs = mail_res.data or []
    
    result = []
    for sub in mail_subs:
        school_id = sub.get("school_id")
        school_info = schools.get(school_id, {})
        result.append({
            **sub,
            "school_name": school_info.get("name", "Unknown School"),
            "owner_email": school_info.get("owner_email"),
            "owner_name": school_info.get("owner_name")
        })

    # Enforce stable ordering by school name case-insensitively
    result.sort(key=lambda x: x.get("school_name", "").lower())
        
    return {"success": True, "data": {"mail_subscriptions": result}}

@router.put("/{school_id}/mail-subscription")
async def update_mail_subscription(
    school_id: str,
    payload: dict,
    user=Depends(require_super_admin_or_director),
):
    """Update or upsert mail subscription config for a school."""
    sb = get_supabase()
    
    # Check if school exists
    check_res = await sb.table("schools").select("id").eq("id", school_id).aexecute()
    if not check_res.data:
        raise HTTPException(status_code=404, detail="School not found")
        
    update_data = {
        "school_id": school_id,
        "updated_at": datetime.utcnow().isoformat()
    }
    
    # Support basic & advanced configs
    for key in [
        "enabled", "pricing_model", "rate_per_unit", "monthly_limit", "emails_sent",
        "mail_host", "mail_port", "mail_username", "mail_password",
        "mail_server_size_limit_mb", "mail_server_size_used_mb", "mail_plan_code"
    ]:
        if key in payload:
            if key in ("enabled",):
                update_data[key] = bool(payload[key])
            elif key in ("mail_port", "monthly_limit", "emails_sent"):
                update_data[key] = int(payload[key])
            elif key in ("rate_per_unit", "mail_server_size_limit_mb", "mail_server_size_used_mb"):
                update_data[key] = float(payload[key])
            else:
                update_data[key] = payload[key]

    try:
        # Check if mail subscription exists; if not, insert it (upsert fallback)
        check_sub = await sb.table("school_mail_subscriptions").select("id").eq("school_id", school_id).aexecute()
        if not check_sub.data:
            insert_data = {
                "school_id": school_id,
                "enabled": True,
                "pricing_model": "per_email",
                "rate_per_unit": 0.10,
                "monthly_limit": 5000,
                "emails_sent": 0,
                "mail_host": "smtp.gmail.com",
                "mail_port": 587,
                "mail_server_size_limit_mb": 1024.00,
                "mail_server_size_used_mb": 0.00,
                "mail_plan_code": "mail_starter",
                **update_data
            }
            res = await sb.table("school_mail_subscriptions").insert(insert_data).aexecute()
        else:
            res = await sb.table("school_mail_subscriptions").update(update_data).eq("school_id", school_id).aexecute()

        # Update general school subscription status if toggling mail subscription enabled
        if "enabled" in payload:
            status = "active" if bool(payload["enabled"]) else "suspended"
            await sb.table("schools").update({"subscription_status": status}).eq("id", school_id).aexecute()

        return {"success": True, "data": {"mail_subscription": res.data}}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to update mail subscription: {str(e)}")

# ===========================================================
# Expiry & Alert Mail Shooter Simulation
# ===========================================================

@router.post("/{school_id}/send-reminder")
async def send_renewal_reminder(
    school_id: str,
    user=Depends(require_super_admin_or_director),
):
    """Send a subscription & email renewal notification warning to the school owner."""
    sb = get_supabase()
    check_res = await sb.table("schools").select(
        "id, name, owner_email, owner_name, subscription_end_date, "
        "subscription_start_date, subscription_status, subscription_tier, "
        "pricing_model, pricing_rate, max_students"
    ).eq("id", school_id).aexecute()
    if not check_res.data:
        raise HTTPException(status_code=404, detail="School not found")
        
    school = check_res.data[0]
    owner_email = school.get("owner_email")
    owner_name = school.get("owner_name") or "Administrator"
    school_name = school.get("name")
    
    if not owner_email:
        raise HTTPException(status_code=400, detail="Owner email is not configured for this school.")

    def _parse_date(raw: str, fmt: str = "%d %b %Y") -> str:
        if not raw:
            return "N/A"
        try:
            cleaned = raw.split(".")[0].split("+")[0].rstrip("Z")
            return datetime.fromisoformat(cleaned).strftime(fmt)
        except Exception:
            return raw

    expiry_date = _parse_date(school.get("subscription_end_date"))
    start_date  = _parse_date(school.get("subscription_start_date"))

    # Days remaining calculation
    days_remaining = "N/A"
    try:
        raw_end = school.get("subscription_end_date", "")
        if raw_end:
            cleaned_end = raw_end.split(".")[0].split("+")[0].rstrip("Z")
            end_dt = datetime.fromisoformat(cleaned_end)
            delta = (end_dt - datetime.utcnow()).days
            days_remaining = str(max(delta, 0))
    except Exception:
        pass

    # Tier / billing labels
    tier = (school.get("subscription_tier") or "premium").replace("_", " ").title()
    status = (school.get("subscription_status") or "active").replace("_", " ").upper()
    pricing_model = school.get("pricing_model") or "per_student"
    pricing_rate  = school.get("pricing_rate") or 0
    max_students  = school.get("max_students") or 0

    billing_label = (
        f"₹{pricing_rate:.2f} / student / month"
        if pricing_model == "per_student"
        else f"₹{pricing_rate:.2f} / month (flat)"
    )

    # Also fetch mail subscription info
    mail_res = await sb.table("school_mail_subscriptions").select(
        "mail_plan_code, monthly_limit, emails_sent, enabled"
    ).eq("school_id", school_id).aexecute()
    mail_plan_code = "N/A"
    mail_monthly_limit = 0
    mail_emails_sent = 0
    if mail_res.data:
        m = mail_res.data[0]
        mail_plan_code = (m.get("mail_plan_code") or "N/A").replace("_", " ").title()
        mail_monthly_limit = m.get("monthly_limit") or 0
        mail_emails_sent = m.get("emails_sent") or 0

    from app.services.email_service import get_email_service
    email_svc = get_email_service()
    
    sent = email_svc.send_renewal_warning_email(
        to_email=owner_email,
        owner_name=owner_name,
        school_name=school_name,
        expiry_date=expiry_date,
        start_date=start_date,
        days_remaining=days_remaining,
        tier=tier,
        status=status,
        billing_label=billing_label,
        max_students=max_students,
        mail_plan_code=mail_plan_code,
        mail_monthly_limit=mail_monthly_limit,
        mail_emails_sent=mail_emails_sent,
    )
    
    if not sent:
        raise HTTPException(status_code=500, detail="Failed to dispatch warning alert email via SMTP server.")

    return {
        "success": True,
        "message": f"Renewal warning alert dispatched successfully to owner: {owner_email} ({owner_name}) for school '{school_name}'. Expiry timeline: {expiry_date}."
    }

# ===========================================================
# Subscription Plans CRUD
# ===========================================================

@router.get("/plans")
async def list_plans(
    user=Depends(require_super_admin_or_director),
):
    """List all subscription plans."""
    sb = get_supabase()
    res = await sb.table("subscription_plans").select("*").order("price_per_month").aexecute()
    plans = res.data or []
    return {"success": True, "data": {"plans": plans, "count": len(plans)}}

@router.post("/plans")
async def create_plan(
    payload: dict,
    user=Depends(require_super_admin_or_director),
):
    """Create a subscription plan."""
    name = payload.get("name")
    code = payload.get("code")
    if not name or not code:
        raise HTTPException(status_code=400, detail="Plan Name and Code are required")
        
    sb = get_supabase()
    plan_data = {
        "id": str(uuid.uuid4()),
        "name": name,
        "code": code,
        "plan_type": payload.get("plan_type", "erp"),
        "price_per_month": float(payload.get("price_per_month", 0.00)),
        "price_per_year": float(payload.get("price_per_year", 0.00)),
        "features": payload.get("features") or [],
        "discount_percent": float(payload.get("discount_percent", 0.00)),
        "offer_text": payload.get("offer_text")
    }

    try:
        res = await sb.table("subscription_plans").insert(plan_data).aexecute()
        return {"success": True, "data": {"plan": res.data}}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create plan: {str(e)}")

@router.put("/plans/{plan_id}")
async def update_plan(
    plan_id: str,
    payload: dict,
    user=Depends(require_super_admin_or_director),
):
    """Update a subscription plan."""
    sb = get_supabase()
    
    # Check if plan exists
    check_res = await sb.table("subscription_plans").select("id").eq("id", plan_id).aexecute()
    if not check_res.data:
        raise HTTPException(status_code=404, detail="Plan not found")
        
    update_data = {
        "updated_at": datetime.utcnow().isoformat()
    }
    for key in ["name", "code", "plan_type", "price_per_month", "price_per_year", "features", "discount_percent", "offer_text"]:
        if key in payload:
            if key in ("price_per_month", "price_per_year", "discount_percent"):
                update_data[key] = float(payload[key])
            else:
                update_data[key] = payload[key]

    try:
        res = await sb.table("subscription_plans").update(update_data).eq("id", plan_id).aexecute()
        return {"success": True, "data": {"plan": res.data}}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to update plan: {str(e)}")

@router.delete("/plans/{plan_id}")
async def delete_plan(
    plan_id: str,
    user=Depends(require_super_admin_or_director),
):
    """Delete a subscription plan."""
    sb = get_supabase()
    
    # Check if plan exists
    check_res = await sb.table("subscription_plans").select("id").eq("id", plan_id).aexecute()
    if not check_res.data:
        raise HTTPException(status_code=404, detail="Plan not found")
        
    try:
        await sb.table("subscription_plans").delete().eq("id", plan_id).aexecute()
        return {"success": True, "detail": "Subscription plan deleted successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to delete plan: {str(e)}")

# ===========================================================
# Module Categories CRUD
# ===========================================================

@router.get("/modules/categories")
async def list_module_categories(
    user=Depends(require_super_admin_or_director),
):
    """List all module categories."""
    sb = get_supabase()
    res = await sb.table("module_categories").select("*").order("name").aexecute()
    return {"success": True, "data": res.data or []}

@router.post("/modules/categories")
async def create_module_category(
    payload: dict,
    user=Depends(require_super_admin_or_director),
):
    """Create a new module category."""
    name = payload.get("name")
    if not name:
        raise HTTPException(status_code=400, detail="Category name is required")
        
    sb = get_supabase()
    check = await sb.table("module_categories").select("name").eq("name", name).aexecute()
    if check.data:
        raise HTTPException(status_code=400, detail="Category name already exists")
        
    cat_data = {
        "name": name,
        "description": payload.get("description", ""),
        "status": payload.get("status", "Active")
    }
    res = await sb.table("module_categories").insert(cat_data).aexecute()
    return {"success": True, "data": res.data}

@router.put("/modules/categories/{name}")
async def update_module_category(
    name: str,
    payload: dict,
    user=Depends(require_super_admin_or_director),
):
    """Update module category."""
    sb = get_supabase()
    check = await sb.table("module_categories").select("name").eq("name", name).aexecute()
    if not check.data:
        raise HTTPException(status_code=404, detail="Category not found")
        
    update_data = {}
    if "description" in payload:
        update_data["description"] = payload["description"]
    if "status" in payload:
        update_data["status"] = payload["status"]
        
    res = await sb.table("module_categories").update(update_data).eq("name", name).aexecute()
    return {"success": True, "data": res.data}

@router.delete("/modules/categories/{name}")
async def delete_module_category(
    name: str,
    user=Depends(require_super_admin_or_director),
):
    """Delete a module category."""
    sb = get_supabase()
    check = await sb.table("module_categories").select("name").eq("name", name).aexecute()
    if not check.data:
        raise HTTPException(status_code=404, detail="Category not found")
        
    res = await sb.table("module_categories").delete().eq("name", name).aexecute()
    return {"success": True, "data": res.data}

# ===========================================================
# Modules Master Registry CRUD
# ===========================================================

@router.get("/modules/all")
async def list_all_modules(
    user=Depends(require_super_admin_or_director),
):
    """List all modules registered in the system."""
    sb = get_supabase()
    res = await sb.table("modules").select("*").order("name").aexecute()
    return {"success": True, "data": res.data or []}

@router.post("/modules/all")
async def create_module(
    payload: dict,
    user=Depends(require_super_admin_or_director),
):
    """Create a new system module."""
    module_id = payload.get("id")
    name = payload.get("name")
    if not module_id or not name:
        raise HTTPException(status_code=400, detail="Module ID and Name are required")
    
    sb = get_supabase()
    check = await sb.table("modules").select("id").eq("id", module_id).aexecute()
    if check.data:
        raise HTTPException(status_code=400, detail="Module ID already exists")

    module_data = {
        "id": module_id,
        "name": name,
        "description": payload.get("description", ""),
        "icon": payload.get("icon", "extension"),
        "screens": payload.get("screens", []),
        "endpoints": payload.get("endpoints", []),
        "is_enabled": payload.get("is_enabled", True),
        "category": payload.get("category", "Core"),
        "type": payload.get("type", "Feature"),
        "version": payload.get("version", "v1.0.0"),
        "developed_by": payload.get("developed_by", "School ERP Team")
    }
    
    res = await sb.table("modules").insert(module_data).aexecute()
    return {"success": True, "data": res.data}

@router.put("/modules/all/{module_id}")
async def update_module(
    module_id: str,
    payload: dict,
    user=Depends(require_super_admin_or_director),
):
    """Update system module details and configurations."""
    sb = get_supabase()
    check = await sb.table("modules").select("id").eq("id", module_id).aexecute()
    if not check.data:
        raise HTTPException(status_code=404, detail="Module not found")

    # If deactivating, check if active for any school
    if payload.get("is_enabled") is False:
        check_schools = await sb.table("schools").select("id, name, module_toggles").aexecute()
        active_schools = []
        for s in (check_schools.data or []):
            toggles = s.get("module_toggles") or {}
            if toggles.get(module_id) is True:
                active_schools.append(s.get("name") or s.get("id"))
        if active_schools:
            schools_str = ", ".join(active_schools[:3])
            if len(active_schools) > 3:
                schools_str += f" and {len(active_schools) - 3} more"
            from fastapi.responses import JSONResponse
            return JSONResponse(
                status_code=400,
                content={
                    "success": False,
                    "detail": f"Cannot deactivate module '{module_id}' because it is active for: {schools_str}. Please deactivate it for all institutions first."
                }
            )

    update_data = {}
    for key in ["name", "description", "icon", "screens", "endpoints", "is_enabled", "category", "type", "version", "developed_by"]:
        if key in payload:
            update_data[key] = payload[key]

    res = await sb.table("modules").update(update_data).eq("id", module_id).aexecute()
    return {"success": True, "data": res.data}

@router.delete("/modules/all/{module_id}")
async def delete_module(
    module_id: str,
    user=Depends(require_super_admin_or_director),
):
    """Delete a system module."""
    sb = get_supabase()
    check = await sb.table("modules").select("id").eq("id", module_id).aexecute()
    if not check.data:
        raise HTTPException(status_code=404, detail="Module not found")

    # Check if active for any school before deleting
    check_schools = await sb.table("schools").select("id, name, module_toggles").aexecute()
    active_schools = []
    for s in (check_schools.data or []):
        toggles = s.get("module_toggles") or {}
        if toggles.get(module_id) is True:
            active_schools.append(s.get("name") or s.get("id"))
    if active_schools:
        schools_str = ", ".join(active_schools[:3])
        if len(active_schools) > 3:
            schools_str += f" and {len(active_schools) - 3} more"
        from fastapi.responses import JSONResponse
        return JSONResponse(
            status_code=400,
            content={
                "success": False,
                "detail": f"Cannot delete module '{module_id}' because it is active for: {schools_str}. Please deactivate it for all institutions first."
            }
        )

    await sb.table("modules").delete().eq("id", module_id).aexecute()
    return {"success": True, "message": "Module deleted successfully"}

@router.get("/modules/requests")
async def list_module_requests(
    user=Depends(require_super_admin_or_director),
):
    """List all module requests with joined school and module details."""
    sb = get_supabase()
    res = await sb.table("module_requests").select("*, modules(*), schools(*)").order("created_at", ascending=False).aexecute()
    return {"success": True, "data": res.data or []}

@router.put("/modules/requests/{request_id}")
async def update_module_request(
    request_id: str,
    payload: dict,
    user=Depends(require_super_admin_or_director),
):
    """Update a module request status and automatically update school modules if approved."""
    status = payload.get("status")
    if not status or status not in ["Pending", "Approved", "Rejected"]:
        raise HTTPException(status_code=400, detail="Invalid status")
    
    sb = get_supabase()
    req_check = await sb.table("module_requests").select("*").eq("id", request_id).aexecute()
    if not req_check.data:
        raise HTTPException(status_code=404, detail="Request not found")
    
    req = req_check.data[0]
    school_id = req.get("school_id")
    module_id = req.get("module_id")

    res = await sb.table("module_requests").update({"status": status}).eq("id", request_id).aexecute()

    if status == "Approved" and school_id and module_id:
        school_check = await sb.table("schools").select("module_toggles").eq("id", school_id).aexecute()
        if school_check.data:
            toggles = school_check.data[0].get("module_toggles") or {}
            toggles[module_id] = True
            await sb.table("schools").update({"module_toggles": toggles}).eq("id", school_id).aexecute()

    return {"success": True, "data": res.data}

@vault_router.get("/vault/secrets")
async def list_vault_secrets(
    user=Depends(require_super_admin_or_director),
):
    """List all environment variables and API keys from Supabase Vault."""
    sb = get_supabase()
    res = await sb.rpc("get_vault_secrets").aexecute()
    return {"success": True, "data": res.data}

@vault_router.get("/vault/secrets/{secret_id}/value")
async def get_vault_secret_val(
    secret_id: str,
    user=Depends(require_super_admin_or_director),
):
    """Get decrypted secret value by ID."""
    sb = get_supabase()
    res = await sb.rpc("get_vault_secret_value", {"secret_id": secret_id}).aexecute()
    val = res.data
    if isinstance(val, list):
        val = val[0] if val else ""
    return {"success": True, "value": val}

@vault_router.post("/vault/secrets")
async def create_vault_secret_endpoint(
    payload: dict,
    user=Depends(require_super_admin_or_director),
):
    """Create a new secret in Supabase Vault."""
    name = payload.get("name")
    value = payload.get("value")
    description = payload.get("description")
    if not name or not value:
        raise HTTPException(status_code=400, detail="Name and value are required")

    sb = get_supabase()
    res = await sb.rpc("create_vault_secret", {
        "secret_name": name,
        "secret_value": value,
        "secret_desc": description
    }).aexecute()
    
    # Sync immediately to os.environ and settings
    from app.services.supabase_client import sync_vault_secrets_to_environ
    await sync_vault_secrets_to_environ()
    
    return {"success": True, "id": res.data}

@vault_router.put("/vault/secrets/{secret_id}")
async def update_vault_secret_endpoint(
    secret_id: str,
    payload: dict,
    user=Depends(require_super_admin_or_director),
):
    """Update a secret in Supabase Vault."""
    sb = get_supabase()
    await sb.rpc("update_vault_secret", {
        "secret_id": secret_id,
        "secret_name": payload.get("name"),
        "secret_value": payload.get("value"),
        "secret_desc": payload.get("description")
    }).aexecute()
    
    # Sync immediately to os.environ and settings
    from app.services.supabase_client import sync_vault_secrets_to_environ
    await sync_vault_secrets_to_environ()
    
    return {"success": True, "message": "Secret updated successfully"}

@vault_router.delete("/vault/secrets/{secret_id}")
async def delete_vault_secret_endpoint(
    secret_id: str,
    user=Depends(require_super_admin_or_director),
):
    """Delete a secret from Supabase Vault."""
    sb = get_supabase()
    await sb.rpc("delete_vault_secret", {"secret_id": secret_id}).aexecute()
    
    # Sync immediately to os.environ and settings
    from app.services.supabase_client import sync_vault_secrets_to_environ
    await sync_vault_secrets_to_environ()
    
    return {"success": True, "message": "Secret deleted successfully"}


# ===========================================================
# API Gateway Stats & Configs
# ===========================================================

async def auto_register_prefixes(sb, prefixes, existing_prefixes):
    new_prefixes = prefixes - existing_prefixes
    for prefix in new_prefixes:
        parts = prefix.split("/")
        last_part = parts[-1] if parts[-1] else (parts[-2] if len(parts) >= 2 else "api")
        if "admin" in parts:
            name = last_part.replace("-", " ").replace("_", " ").title() + " Admin API"
            category = "Student" if "student" in last_part else "Academic" if "teacher" in last_part else "Others"
        else:
            name = last_part.replace("-", " ").replace("_", " ").title() + " API"
            category = "Authentication" if "auth" in last_part else "Student" if "student" in last_part else "Academic" if "teacher" in last_part else "Finance" if "payment" in last_part else "Communication" if "chat" in last_part else "Others"
        
        try:
            await sb.table("api_gateway_configs").insert({
                "path_prefix": prefix,
                "api_name": name,
                "category": category,
                "version": "v1.0",
                "is_active": True
            }).aexecute()
        except Exception as e:
            print(f"Failed to auto-register prefix {prefix}: {e}", flush=True)


@router.get("/gateway/stats")
async def get_gateway_stats(
    request: Request,
    user=Depends(require_super_admin_or_director),
):
    sb = get_supabase()
    
    # 1. Fetch configs from DB
    configs_res = await sb.table("api_gateway_configs").select("*").aexecute()
    configs = configs_res.data or []
    existing_prefixes = {c["path_prefix"] for c in configs}
    
    # 2. Dynamic route discovery
    prefixes = set()
    for route in request.app.routes:
        path = getattr(route, "path", None)
        if path and path.startswith("/api/"):
            parts = path.split("/")
            if len(parts) >= 4 and parts[2] == "admin":
                prefix = "/".join(parts[:4])
            else:
                prefix = "/".join(parts[:3])
            prefixes.add(prefix)
            
    # Auto-register any missing prefixes
    if prefixes - existing_prefixes:
        await auto_register_prefixes(sb, prefixes, existing_prefixes)
        # Re-fetch configs
        configs_res = await sb.table("api_gateway_configs").select("*").aexecute()
        configs = configs_res.data or []
        
    # 3. Fetch aggregated path statistics from views (lightning fast, O(1) memory)
    path_stats_res = await sb.table("api_path_stats").select("*").aexecute()
    path_stats = path_stats_res.data or []
    
    # 4. Fetch daily stats for the last 7 days from views
    seven_days_ago_date = (datetime.utcnow() - timedelta(days=7)).date().isoformat()
    daily_stats_res = await sb.table("api_daily_stats").select("*").gte("log_date", seven_days_ago_date).aexecute()
    daily_stats = daily_stats_res.data or []
    
    # 5. Calculate dashboard metrics
    total_requests = sum(row["total_requests"] for row in path_stats)
    success_requests = sum(row["success_requests"] for row in path_stats)
    rate_limit_hits = sum(row["rate_limit_hits"] for row in path_stats)
    
    success_rate = (success_requests / total_requests * 100.0) if total_requests > 0 else 99.52
    avg_response_time = (sum(row["avg_response_time"] * row["total_requests"] for row in path_stats) / total_requests) if total_requests > 0 else 186.0
    
    # 6. Traffic Overview (last 7 days grouped by day)
    traffic_by_day = {}
    for i in range(7):
        day_str = (datetime.utcnow() - timedelta(days=i)).strftime("%Y-%m-%d")
        traffic_by_day[day_str] = {"requests": 0, "successful": 0, "failed": 0}
        
    for row in daily_stats:
        date_str = str(row["log_date"])
        if date_str in traffic_by_day:
            traffic_by_day[date_str]["requests"] = row["total_requests"]
            traffic_by_day[date_str]["successful"] = row["success_requests"]
            traffic_by_day[date_str]["failed"] = row["failed_requests"]
            
    # Format and sort traffic overview
    traffic_overview = []
    for day_str in sorted(traffic_by_day.keys()):
        dt = datetime.strptime(day_str, "%Y-%m-%d")
        display_label = dt.strftime("%b %d")
        traffic_overview.append({
            "date": day_str,
            "label": display_label,
            "requests": traffic_by_day[day_str]["requests"],
            "successful": traffic_by_day[day_str]["successful"],
            "failed": traffic_by_day[day_str]["failed"],
        })
        
    # 7. Requests by category
    category_counts = {}
    for row in path_stats:
        matching_config = None
        for c in configs:
            if row["path"].startswith(c["path_prefix"]):
                matching_config = c
                break
        cat = matching_config["category"] if matching_config else "Others"
        category_counts[cat] = category_counts.get(cat, 0) + row["total_requests"]
        
    category_data = []
    total_cat_requests = sum(category_counts.values())
    for cat, count in category_counts.items():
        percentage = (count / total_cat_requests * 100.0) if total_cat_requests > 0 else 0.0
        category_data.append({
            "category": cat,
            "count": count,
            "percentage": round(percentage, 2)
        })
        
    all_categories = ["Authentication", "Student", "Academic", "Finance", "Communication", "Others"]
    for cat in all_categories:
        if not any(cd["category"] == cat for cd in category_data):
            category_data.append({"category": cat, "count": 0, "percentage": 0.0})
            
    category_data = sorted(category_data, key=lambda x: all_categories.index(x["category"]))
    
    # 8. Registered APIs list (configs joined with aggregated metrics from views)
    registered_apis = []
    for c in configs:
        prefix = c["path_prefix"]
        matching_rows = [row for row in path_stats if row["path"].startswith(prefix)]
        pref_total = sum(row["total_requests"] for row in matching_rows)
        pref_success = sum(row["success_requests"] for row in matching_rows)
        
        pref_success_rate = (pref_success / pref_total * 100.0) if pref_total > 0 else 99.5
        pref_avg_response = (sum(row["avg_response_time"] * row["total_requests"] for row in matching_rows) / pref_total) if pref_total > 0 else 0.0
        
        registered_apis.append({
            "path_prefix": prefix,
            "api_name": c["api_name"],
            "category": c["category"],
            "version": c["version"],
            "requests": pref_total,
            "success_rate": round(pref_success_rate, 2),
            "avg_response_time": int(pref_avg_response),
            "status": "Active" if c["is_active"] else "Inactive"
        })
        
    registered_apis = sorted(registered_apis, key=lambda x: x["requests"], reverse=True)
    
    # 9. Recent Activity list (fetch recent 10 logs)
    recent_logs_res = await sb.table("api_request_logs").select("*").order("created_at", ascending=False).limit(10).aexecute()
    recent_logs = recent_logs_res.data or []
    
    recent_activities = []
    for log in recent_logs:
        path = log["path"]
        method = log["method"]
        status = log["status_code"]
        ip = log["ip_address"] or "unknown"
        created_at = log["created_at"]
        
        try:
            clean_ts = created_at.replace("Z", "+00:00").split(".")[0]
            dt = datetime.strptime(clean_ts[:19], "%Y-%m-%dT%H:%M:%S")
            diff = datetime.utcnow() - dt
            if diff.days > 0:
                time_str = f"{diff.days}d ago"
            elif diff.seconds >= 3600:
                time_str = f"{diff.seconds // 3600}h ago"
            elif diff.seconds >= 60:
                time_str = f"{diff.seconds // 60}m ago"
            else:
                time_str = "just now"
        except Exception:
            time_str = "recently"
            
        recent_activities.append({
            "activity": f"{method} {path} (HTTP {status})",
            "by": f"IP: {ip}",
            "time": time_str
        })
        
    return {
        "success": True,
        "data": {
            "metrics": {
                "total_apis": len(configs),
                "total_requests": total_requests,
                "success_rate": round(success_rate, 2),
                "avg_response_time": int(avg_response_time),
                "rate_limit_hits": rate_limit_hits
            },
            "traffic_overview": traffic_overview,
            "category_data": category_data,
            "gateway_status": {
                "status": "Operational",
                "uptime": "99.99%",
                "environment": settings.ENVIRONMENT,
                "server_region": "Mumbai, IN",
                "gateway_version": "v2.4.1"
            },
            "recent_activity": recent_activities[:5],
            "registered_apis": registered_apis
        }
    }


@router.post("/gateway/configs")
async def create_gateway_config(
    payload: dict,
    user=Depends(require_super_admin_or_director),
):
    path_prefix = payload.get("path_prefix")
    if not path_prefix:
        raise HTTPException(status_code=400, detail="Path prefix is required")
    if not path_prefix.startswith("/"):
        path_prefix = "/" + path_prefix
        
    sb = get_supabase()
    exists = await sb.table("api_gateway_configs").select("path_prefix").eq("path_prefix", path_prefix).aexecute()
    if exists.data:
        raise HTTPException(status_code=400, detail=f"API Gateway prefix {path_prefix} already exists")
        
    insert_data = {
        "path_prefix": path_prefix,
        "api_name": payload.get("api_name") or "New Endpoint API",
        "category": payload.get("category") or "Others",
        "version": payload.get("version") or "v1.0",
        "is_active": payload.get("is_active", True)
    }
    await sb.table("api_gateway_configs").insert(insert_data).aexecute()
    return {"success": True, "message": "API Gateway configuration created successfully"}


@router.put("/gateway/configs/{path_prefix:path}")
async def update_gateway_config(
    path_prefix: str,
    payload: dict,
    user=Depends(require_super_admin_or_director),
):
    if not path_prefix.startswith("/"):
        path_prefix = "/" + path_prefix
        
    sb = get_supabase()
    update_data = {}
    if "api_name" in payload:
        update_data["api_name"] = payload["api_name"]
    if "category" in payload:
        update_data["category"] = payload["category"]
    if "version" in payload:
        update_data["version"] = payload["version"]
    if "is_active" in payload:
        is_act = payload["is_active"]
        if isinstance(is_act, str):
            is_act = is_act.lower() == "true" or is_act == "Active"
        update_data["is_active"] = is_act
        
    update_data["updated_at"] = datetime.utcnow().isoformat()
    
    await sb.table("api_gateway_configs").update(update_data).eq("path_prefix", path_prefix).aexecute()
    return {"success": True, "message": "API Gateway configuration updated successfully"}


@router.post("/gateway/simulate-traffic")
async def simulate_traffic(
    payload: dict,
    user=Depends(require_super_admin_or_director),
):
    sb = get_supabase()
    status_code = payload.get("status_code", 200)
    count = payload.get("count", 10)
    path = payload.get("path", "/api/student/profile")
    method = payload.get("method", "GET")
    response_time = payload.get("response_time_ms", 120.0)
    
    logs_to_insert = []
    for _ in range(count):
        logs_to_insert.append({
            "path": path,
            "method": method,
            "status_code": status_code,
            "response_time_ms": response_time,
            "ip_address": "127.0.0.1"
        })
        
    await sb.table("api_request_logs").insert(logs_to_insert).aexecute()
    return {"success": True, "message": f"Successfully simulated {count} requests to {path}"}


import asyncio
from pydantic import BaseModel

# In-memory service state registry to track real-time container states
service_states = {}

def get_service_status(server_name: str, service_name: str) -> str:
    key = f"{server_name}:{service_name}"
    if key not in service_states:
        # Default starting state
        service_states[key] = "running"
    return service_states[key]

class ServiceControlRequest(BaseModel):
    server_name: str
    service_name: str
    action: str

@router.post("/infra/services/control")
async def control_infra_service(
    req: ServiceControlRequest,
    user=Depends(require_super_admin_or_director),
):
    key = f"{req.server_name}:{req.service_name}"
    if req.action == "restart":
        service_states[key] = "restarting"
        
        async def reset_state():
            await asyncio.sleep(4)
            service_states[key] = "running"
        asyncio.create_task(reset_state())
        
    elif req.action == "stop":
        service_states[key] = "stopped"
        
    elif req.action == "start":
        service_states[key] = "running"
        
    return {"success": True, "status": service_states[key]}


class TerminalRunRequest(BaseModel):
    server_name: str
    command: str

@router.post("/infra/terminal/run")
async def run_infra_terminal_command(
    req: TerminalRunRequest,
    user=Depends(require_super_admin_or_director),
):
    import subprocess
    import socket
    import json

    cmd = req.command.strip()
    if not cmd:
        return {"success": True, "output": ""}

    # Translate simulated container names to real Docker container names
    translations = [
        ("application_api_(node)", "edushamiit-api"),
        ("web_server_(nginx)", "edushamiit-nginx"),
        ("database_host_(postgres)", "supabase-db"),
        ("cache_broker_(redis)", "edushamiit-redis"),
        ("application_api", "edushamiit-api"),
        ("web_server", "edushamiit-nginx"),
        ("database_host", "supabase-db"),
        ("cache_broker", "edushamiit-redis"),
    ]
    for old_name, new_name in translations:
        cmd = cmd.replace(old_name, new_name)
        cmd = cmd.replace(old_name.replace("_", " "), new_name)

    # Helper function to talk to local Docker Daemon REST API via unix socket using http.client
    def query_docker_api(path: str, method: str = "GET") -> tuple[int, str]:
        import http.client
        
        class UnixHTTPConnection(http.client.HTTPConnection):
            def __init__(self, unix_socket_path):
                super().__init__("localhost")
                self.unix_socket_path = unix_socket_path
                
            def connect(self):
                self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                self.sock.connect(self.unix_socket_path)

        try:
            conn = UnixHTTPConnection("/var/run/docker.sock")
            conn.request(method, path)
            res = conn.getresponse()
            body = res.read().decode('utf-8', errors='ignore')
            status = res.status
            conn.close()
            return status, body
        except Exception as e:
            return 500, f"Socket HTTP error: {str(e)}"

    lower_cmd = cmd.lower()

    # 1. Intercept "docker ps"
    if lower_cmd == "docker ps":
        code, body = query_docker_api("/containers/json")
        if code == 200:
            try:
                containers = json.loads(body)
                if not containers:
                    return {"success": True, "output": "No active containers running."}
                lines = [f"{'CONTAINER ID':<14} {'IMAGE':<30} {'STATUS':<20} {'NAMES':<25}"]
                for c in containers:
                    cid = c.get("Id", "")[:12]
                    img = c.get("Image", "")
                    if len(img) > 28:
                        img = img[:26] + "..."
                    names = ", ".join([n.lstrip('/') for n in c.get("Names", [])])
                    status = c.get("Status", "")
                    lines.append(f"{cid:<14} {img:<30} {status:<20} {names:<25}")
                return {"success": True, "output": "\n".join(lines)}
            except Exception as e:
                return {"success": True, "output": f"Error parsing docker response: {str(e)}"}
        else:
            return {"success": True, "output": f"Docker Daemon returned code {code}: {body}"}

    # 2. Intercept "docker restart"
    if lower_cmd.startswith("docker restart "):
        target = cmd[15:].strip()
        code, body = query_docker_api(f"/containers/{target}/restart", "POST")
        if code in (200, 204):
            return {"success": True, "output": f"Container {target} restarted successfully."}
        else:
            return {"success": True, "output": f"Error restarting container {target} (API code {code}): {body}"}

    # 3. Intercept "docker stop"
    if lower_cmd.startswith("docker stop "):
        target = cmd[12:].strip()
        code, body = query_docker_api(f"/containers/{target}/stop", "POST")
        if code in (200, 204):
            return {"success": True, "output": f"Container {target} stopped successfully."}
        else:
            return {"success": True, "output": f"Error stopping container {target} (API code {code}): {body}"}

    # 4. Intercept "docker start"
    if lower_cmd.startswith("docker start "):
        target = cmd[13:].strip()
        code, body = query_docker_api(f"/containers/{target}/start", "POST")
        if code in (200, 204):
            return {"success": True, "output": f"Container {target} started successfully."}
        else:
            return {"success": True, "output": f"Error starting container {target} (API code {code}): {body}"}

    # 5. Custom high-level helper for "restart docker"
    if lower_cmd == "restart docker":
        code, body = query_docker_api("/containers/json")
        if code == 200:
            try:
                containers = json.loads(body)
                restarts = []
                for c in containers:
                    cid = c.get("Id", "")
                    name = c.get("Names", [""])[0].lstrip('/')
                    q_code, _ = query_docker_api(f"/containers/{cid}/restart", "POST")
                    if q_code in (200, 204):
                        restarts.append(f"  Container {name or cid[:8]}... RESTARTED")
                    else:
                        restarts.append(f"  Container {name or cid[:8]}... FAILED")
                if restarts:
                    output = "Stopping and starting active Docker containers...\n" + "\n".join(restarts) + "\nAll Docker containers recycled successfully."
                else:
                    output = "No active Docker containers found to restart."
                return {"success": True, "output": output}
            except Exception as e:
                return {"success": True, "output": f"Error parsing docker response: {str(e)}"}
        else:
            return {"success": True, "output": f"Error communicating with Docker socket: {body}"}

    # Fallback to run standard host/container shell command
    try:
        process = subprocess.run(
            cmd,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=8.0
        )
        output = process.stdout or ""
        if process.stderr:
            output += "\n" + process.stderr
        if not output.strip():
            output = f"Command executed successfully (exit code {process.returncode})."
    except subprocess.TimeoutExpired:
        output = "Error: Command timed out after 8.0 seconds."
    except Exception as e:
        output = f"Error executing command: {str(e)}"
        
    return {"success": True, "output": output}


@router.get("/infra/stats")
async def get_infra_stats(
    user=Depends(require_super_admin_or_director),
):
    sb = get_supabase()
    
    # 1. Query schools to match metrics and alerts
    schools_res = await sb.table("schools").select("id, name").aexecute()
    schools = schools_res.data or []
    school_map = {s["id"]: s["name"] for s in schools}
    
    # 2. Query servers
    servers_res = await sb.table("infra_servers").select("*").aexecute()
    servers = servers_res.data or []
    
    # 3. Query services dynamically
    services_list = []
    service_names = [
        ("Web Server (Nginx)", 80),
        ("Application API (Node)", 8000),
        ("Database Host (Postgres)", 5432),
        ("Cache Broker (Redis)", 6379)
    ]
    for s in servers:
        s_name = s["name"]
        for srv_name, port in service_names:
            status = get_service_status(s_name, srv_name)
            services_list.append({
                "host_server": s_name,
                "name": srv_name,
                "status": status,
                "port": port
            })
    services = services_list
    
    # 4. Query alerts (active)
    alerts_res = await sb.table("infra_alerts").select("*").eq("is_active", True).order("created_at", ascending=False).aexecute()
    alerts = alerts_res.data or []
    
    # 5. Query metrics (last 7 days)
    metrics_res = await sb.table("infra_school_metrics").select("*").order("log_date", ascending=True).aexecute()
    metrics = metrics_res.data or []
    
    # 6. Extract today's metrics
    today_str = datetime.utcnow().date().isoformat()
    today_metrics = [m for m in metrics if str(m["log_date"]) == today_str]
    # Fallback to last day in metrics if today has no data (though it should)
    if not today_metrics and metrics:
        last_date = metrics[-1]["log_date"]
        today_metrics = [m for m in metrics if m["log_date"] == last_date]
        
    # Get Real Host OS Resource Utilization using psutil
    real_cpu = 42.0
    real_memory = 61.0
    real_disk = 54.0
    real_network = 35.0
    
    try:
        import psutil
        real_cpu = psutil.cpu_percent(interval=None)
        if real_cpu == 0.0:
            real_cpu = psutil.cpu_percent(interval=0.01)
        real_memory = psutil.virtual_memory().percent
        real_disk = psutil.disk_usage('/').percent
        
        net_io = psutil.net_io_counters()
        real_network = float((net_io.bytes_sent + net_io.bytes_recv) % 75) + 15
    except Exception:
        pass

    # Query Real Database size & Connections
    db_size_bytes = 52428800  # default fallback 50MB
    db_connections = 12
    try:
        size_rpc = await sb.rpc("get_db_size", {}).aexecute()
        if size_rpc.data is not None:
            db_size_bytes = int(size_rpc.data)
        conn_rpc = await sb.rpc("get_db_connections", {}).aexecute()
        if conn_rpc.data is not None:
            db_connections = int(conn_rpc.data)
    except Exception:
        pass

    # Query Real Live API Request logs counts (Last 24 hours)
    live_requests_24h = 0
    try:
        req_count_res = await sb.table("api_request_logs").select("id", count="exact").filter("created_at", "gte", (datetime.utcnow() - timedelta(hours=24)).isoformat()).aexecute()
        live_requests_24h = req_count_res.count or 0
    except Exception:
        pass

    # Fetch school request breakdown from our live database view
    live_school_requests = {}
    live_school_latencies = {}
    try:
        stats_view = await sb.table("school_request_stats_24h").select("*").aexecute()
        if stats_view.data:
            for item in stats_view.data:
                s_id = item["school_id"]
                live_school_requests[s_id] = item["request_count"]
                live_school_latencies[s_id] = round(item["avg_response_time"], 1)
    except Exception:
        pass

    # Update server list dynamically with real system load
    for s in servers:
        s_name = s["name"]
        if s_name == "api-server-1":
            s["cpu_usage"] = round(real_cpu, 1)
            s["memory_usage"] = round(real_memory, 1)
            s["disk_usage"] = round(real_disk, 1)
            s["status"] = "healthy" if real_cpu < 85 else "warning"
        elif s_name == "db-node-primary":
            db_cpu_load = min(95.0, 5.0 + (db_connections * 1.5))
            db_ram_load = min(90.0, 25.0 + (db_size_bytes / (1024 ** 2) * 0.1))
            s["cpu_usage"] = round(db_cpu_load, 1)
            s["memory_usage"] = round(db_ram_load, 1)
            s["status"] = "healthy" if db_cpu_load < 80 else "warning"
        elif s_name == "api-server-2":
            api2_cpu = max(1.0, real_cpu * 0.8)
            api2_ram = max(1.0, real_memory * 0.9)
            s["cpu_usage"] = round(api2_cpu, 1)
            s["memory_usage"] = round(api2_ram, 1)
            s["status"] = "healthy" if api2_cpu < 85 else "warning"
        elif s_name == "db-node-replica":
            replica_cpu = max(1.0, (5.0 + (db_connections * 0.7)))
            s["cpu_usage"] = round(replica_cpu, 1)
            s["status"] = "healthy" if replica_cpu < 80 else "warning"

        # Check if any service on this server is stopped or restarting
        s_services_statuses = [get_service_status(s_name, srv_name) for srv_name, _ in service_names]
        if "stopped" in s_services_statuses:
            s["status"] = "critical"
        elif "restarting" in s_services_statuses:
            s["status"] = "warning"

    # Calculate aggregate metrics
    total_institutions = len(schools)
    active_institutions = sum(1 for m in today_metrics if m["status"] != "critical")
    
    total_systems = len(servers)
    healthy_systems = sum(1 for s in servers if s["status"] == "healthy")
    
    uptime_avg = sum(m["uptime_percentage"] for m in today_metrics) / len(today_metrics) if today_metrics else 99.94
    
    base_requests_seeded = sum(m["request_count_24h"] for m in today_metrics)
    total_requests_24h = base_requests_seeded + live_requests_24h
    
    # Calculate aggregate data transfer (approx 62KB per request) -> bytes to TB
    total_data_transfer_bytes = total_requests_24h * 62000
    data_transfer_tb = total_data_transfer_bytes / (1024.0 ** 4)
    
    incidents_count = len(alerts)
    
    # System health overview summary
    healthy_servers = sum(1 for s in servers if s["status"] == "healthy")
    warning_servers = sum(1 for s in servers if s["status"] == "warning")
    critical_servers = sum(1 for s in servers if s["status"] == "critical")
    

    avg_cpu = real_cpu
    avg_memory = real_memory
    avg_disk = real_disk
    avg_network = real_network
    
    # Format active alerts list with institute name
    active_alerts_list = []
    for a in alerts:
        school_name = school_map.get(a["school_id"], "System Network")
        active_alerts_list.append({
            "id": a["id"],
            "title": a["title"],
            "institute": school_name,
            "severity": a["severity"],
            "created_at": a["created_at"]
        })
        
    # Format institutions overview list
    school_overview = []
    for s in schools:
        s_id = s["id"]
        # Find latest metric for this school
        s_metrics = [m for m in today_metrics if m["school_id"] == s_id]
        latest_m = s_metrics[0] if s_metrics else None
        
        # Count alerts for this school
        s_alerts = sum(1 for a in alerts if a["school_id"] == s_id)
        
        status = latest_m["status"] if latest_m else "healthy"
        uptime = latest_m["uptime_percentage"] if latest_m else 100.0
        
        resp_time = live_school_latencies.get(s_id, latest_m["avg_response_time_ms"] if latest_m else 120)
        requests = live_school_requests.get(s_id, 0) + (latest_m["request_count_24h"] if latest_m else 0)
        used_storage = (latest_m["storage_used_bytes"] if latest_m else 0)
        if s_id == user.get("school_id"):
            used_storage += db_size_bytes
            
        total_storage = latest_m["storage_total_bytes"] if latest_m else 214748364800
        
        # format values for display
        req_display = f"{requests / 1000000.0:.2f}M" if requests >= 1000000 else f"{requests / 1000.0:.0f}K"
        used_gb = int(used_storage / (1024 ** 3))
        total_gb = int(total_storage / (1024 ** 3))
        if used_gb == 0 and used_storage > 0:
            used_gb = 1
            
        school_overview.append({
            "school_id": s_id,
            "name": s["name"],
            "status": status.capitalize(),
            "uptime": f"{uptime}%",
            "response_time": f"{int(resp_time)}ms",
            "requests": req_display,
            "storage": f"{used_gb} GB / {total_gb} GB",
            "alerts": s_alerts
        })
        
    # Format response time line chart data (last 7 days grouped by date)
    historical_chart_data = []
    # Get distinct log dates
    distinct_dates = sorted(list(set(str(m["log_date"]) for m in metrics)))
    for date_str in distinct_dates:
        try:
            dt = datetime.strptime(date_str, "%Y-%m-%d")
            display_label = dt.strftime("%b %d")
        except Exception:
            display_label = date_str
            
        entry = {
            "date": date_str,
            "label": display_label,
        }
        for s in schools:
            s_metrics = [m for m in metrics if str(m["log_date"]) == date_str and m["school_id"] == s["id"]]
            entry[s["name"]] = s_metrics[0]["avg_response_time_ms"] if s_metrics else 0
        historical_chart_data.append(entry)
        
    return {
        "success": True,
        "data": {
            "metrics": {
                "total_institutions": total_institutions,
                "active_institutions": active_institutions,
                "total_systems": total_systems,
                "healthy_systems": healthy_systems,
                "uptime_avg": round(uptime_avg, 2),
                "total_requests": f"{total_requests_24h / 1000000.0:.2f}M",
                "data_transfer": f"{data_transfer_tb:.2f} TB",
                "incidents": incidents_count
            },
            "health_summary": {
                "healthy": healthy_servers,
                "warning": warning_servers,
                "critical": critical_servers
            },
            "gauges": {
                "cpu": round(avg_cpu, 1),
                "memory": round(avg_memory, 1),
                "disk": round(avg_disk, 1),
                "network": round(avg_network, 1)
            },
            "servers": servers,
            "alerts": active_alerts_list,
            "institutions_overview": school_overview,
            "response_time_chart": historical_chart_data,
            "services_status": services
        }
    }


