from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File
from typing import Optional, List
from datetime import datetime, timedelta
import uuid

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
        "is_enabled": payload.get("is_enabled", True)
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
    for key in ["name", "description", "icon", "screens", "endpoints", "is_enabled"]:
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
