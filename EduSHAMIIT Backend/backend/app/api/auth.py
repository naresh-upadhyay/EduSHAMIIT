from fastapi import APIRouter, HTTPException, status, Depends, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel, validator
from typing import Optional, Dict, Any, List
from app.services.supabase_client import get_supabase
from app.services.email_service import get_email_service
from app.config import settings
from app.models import (
    LoginRequest, RegisterRequest, RefreshRequest, SendOtpRequest, 
    VerifyOtpRequest, ResetPasswordRequest, LoginResponse, RegisterResponse,
    RefreshResponse, OtpResponse, VerifyOtpResponse, ResetPasswordResponse,
    ErrorResponse, SendLoginOtpRequest, VerifyLoginOtpRequest, OnboardSchoolRequest
)
from jose import jwt
from datetime import datetime, timedelta, timezone
import httpx
import os
import uuid
import random
import logging
import re
from app.middleware.auth import get_current_user

router = APIRouter()

JWT_SECRET = settings.SUPABASE_JWT_SECRET or settings.JWT_SECRET
JWT_ALGORITHM = "HS256"


def validate_email(email: str) -> str:
    """Validate email format"""
    email_regex = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    if not re.match(email_regex, email):
        raise ValueError("Invalid email format")
    return email


def get_security_settings(school_id: Optional[str] = None) -> dict:
    import psycopg2
    from app.config import settings
    
    default_settings = {
        "password_policy": "Strong",
        "session_limit": 5,
        "failed_attempts_lockout": 5
    }
    
    try:
        conn = psycopg2.connect(settings.DATABASE_URL, connect_timeout=3)
        with conn.cursor() as cur:
            if school_id:
                cur.execute(
                    "SELECT security_settings FROM public.system_configurations WHERE school_id = %s LIMIT 1",
                    (school_id,)
                )
                row = cur.fetchone()
                if row and row[0]:
                    return row[0]
            
            cur.execute(
                "SELECT security_settings FROM public.system_configurations WHERE school_id IS NULL LIMIT 1"
            )
            row = cur.fetchone()
            if row and row[0]:
                return row[0]
    except Exception as e:
        logging.warning(f"Error fetching security settings synchronously: {e}")
    return default_settings


def validate_password_complexity(password: str, policy: str):
    policy = policy.lower()
    
    if policy == "simple":
        if len(password) < 6:
            raise HTTPException(status_code=400, detail="Password must be at least 6 characters long under Simple policy")
            
    elif policy == "medium":
        if len(password) < 8:
            raise HTTPException(status_code=400, detail="Password must be at least 8 characters long under Medium policy")
        if not re.search(r'[a-zA-Z]', password) or not re.search(r'\d', password):
            raise HTTPException(status_code=400, detail="Password must contain at least one letter and one number under Medium policy")
            
    elif policy == "enterprise":
        if len(password) < 10:
            raise HTTPException(status_code=400, detail="Password must be at least 10 characters long under Enterprise policy")
        if not re.search(r'[A-Z]', password):
            raise HTTPException(status_code=400, detail="Password must contain at least one uppercase letter under Enterprise policy")
        if not re.search(r'[a-z]', password):
            raise HTTPException(status_code=400, detail="Password must contain at least one lowercase letter under Enterprise policy")
        if not re.search(r'\d', password):
            raise HTTPException(status_code=400, detail="Password must contain at least one number under Enterprise policy")
        if not re.search(r'[^a-zA-Z0-9]', password):
            raise HTTPException(status_code=400, detail="Password must contain at least one special character under Enterprise policy")
        for i in range(len(password) - 2):
            if password[i] == password[i+1] == password[i+2]:
                raise HTTPException(status_code=400, detail="Password must not contain repeating patterns (3 or more consecutive identical characters) under Enterprise policy")
                
    else: # Default is "strong"
        if len(password) < 8:
            raise HTTPException(status_code=400, detail="Password must be at least 8 characters long under Strong policy")
        if not re.search(r'[A-Z]', password):
            raise HTTPException(status_code=400, detail="Password must contain at least one uppercase letter under Strong policy")
        if not re.search(r'[a-z]', password):
            raise HTTPException(status_code=400, detail="Password must contain at least one lowercase letter under Strong policy")
        if not re.search(r'\d', password):
            raise HTTPException(status_code=400, detail="Password must contain at least one number under Strong policy")
        if not re.search(r'[^a-zA-Z0-9]', password):
            raise HTTPException(status_code=400, detail="Password must contain at least one special character under Strong policy")


def validate_password(password: str) -> str:
    """Validate password basic length to support dynamic policies in endpoints"""
    if len(password) < 6:
        raise ValueError("Password must be at least 6 characters long")
    return password


class EnhancedSendOtpRequest(SendOtpRequest):
    """Enhanced OTP request with validation"""
    
    @validator('identifier')
    def validate_identifier(cls, v):
        if not v:
            raise ValueError("Identifier is required")
        # Check if it's a UUID or email
        if '@' not in v:
            try:
                uuid.UUID(v)
            except ValueError:
                raise ValueError("Invalid UUID format for identifier")
        else:
            validate_email(v)
        return v


class EnhancedResetPasswordRequest(ResetPasswordRequest):
    """Enhanced password reset request with validation"""
    
    @validator('new_password')
    def validate_new_password(cls, v):
        return validate_password(v)
    
    @validator('otp')
    def validate_otp(cls, v):
        if not v or not v.isdigit():
            raise ValueError("OTP must be a numeric value")
        if len(v) != settings.OTP_LENGTH:
            raise ValueError(f"OTP must be {settings.OTP_LENGTH} digits long")
        return v


@router.post("/login", 
    summary="User Login",
    description="Authenticate user with email and password, returns JWT token and user information",
    responses={
        200: {
            "description": "Login successful",
            "model": LoginResponse,
            "content": {
                "application/json": {
                    "example": {
                        "success": True,
                        "school_id": "SCH-12345",
                        "data": {
                            "token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
                            "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                            "user": {
                                "id": "user-uuid-here",
                                "full_name": "John Doe",
                                "role": "student",
                                "class": "10A",
                                "school_id": "SCH-12345",
                                "avatar_url": "https://example.com/avatar.jpg"
                            }
                        }
                    }
                }
            }
        },
        400: {
            "description": "Invalid request",
            "model": ErrorResponse,
            "content": {
                "application/json": {
                    "example": {
                        "success": False,
                        "detail": "Email and password required"
                    }
                }
            }
        },
        401: {
            "description": "Authentication failed",
            "model": ErrorResponse,
            "content": {
                "application/json": {
                    "example": {
                        "success": False,
                        "detail": "Login failed: Invalid credentials"
                    }
                }
            }
        },
        404: {
            "description": "User not found",
            "model": ErrorResponse,
            "content": {
                "application/json": {
                    "example": {
                        "success": False,
                        "detail": "Profile not found"
                    }
                }
            }
        }
    }
)
async def login(request: LoginRequest, raw_req: Request):
    """Authenticate user and return JWT token."""
    try:
        sb = get_supabase()
        email = request.email
        password = request.password

        # Check lockout status first
        profile_check = await sb.table("profiles").select("*").eq("email", email).maybe_single().aexecute()
        p_check = profile_check.data
        sec_settings = get_security_settings(p_check.get("school_id") if p_check else None)
        lockout_limit = int(sec_settings.get("failed_attempts_lockout") or 5)

        if p_check:
            lockout_until_str = p_check.get("lockout_until")
            if lockout_until_str:
                try:
                    lockout_until = datetime.fromisoformat(lockout_until_str.replace("Z", "+00:00"))
                    if lockout_until > datetime.now(timezone.utc):
                        diff = lockout_until - datetime.now(timezone.utc)
                        seconds = int(diff.total_seconds())
                        minutes = seconds // 60
                        remaining = f"{minutes}m {seconds % 60}s" if minutes > 0 else f"{seconds}s"
                        raise HTTPException(
                            status_code=401,
                            detail=f"Account temporarily locked due to too many failed login attempts. Try again in {remaining}."
                        )
                except Exception as ex:
                    if isinstance(ex, HTTPException):
                        raise ex

        try:
            auth_response = await sb.auth().sign_in_with_password({
                "email": email,
                "password": password,
            })
        except Exception as auth_err:
            if p_check:
                last_failed_str = p_check.get("last_failed_login")
                reset_attempts = False
                if last_failed_str:
                    try:
                        last_failed = datetime.fromisoformat(last_failed_str.replace("Z", "+00:00"))
                        if datetime.now(timezone.utc) - last_failed > timedelta(days=1):
                            reset_attempts = True
                    except Exception:
                        pass
                
                if reset_attempts:
                    curr_attempts = 1
                else:
                    curr_attempts = int(p_check.get("failed_login_attempts") or 0) + 1
                
                updates = {
                    "failed_login_attempts": curr_attempts,
                    "last_failed_login": datetime.now(timezone.utc).isoformat()
                }
                
                if curr_attempts >= lockout_limit:
                    lockout_time = datetime.now(timezone.utc) + timedelta(minutes=15)
                    updates["lockout_until"] = lockout_time.isoformat()
                    updates["failed_login_attempts"] = 0
                    err_msg = "Account locked due to too many failed login attempts. Try again in 15 minutes."
                else:
                    err_msg = f"Invalid credentials. {lockout_limit - curr_attempts} attempts remaining before lockout."
                
                await sb.table("profiles").update(updates).eq("id", p_check["id"]).aexecute()
                raise HTTPException(status_code=401, detail=err_msg)
            else:
                raise HTTPException(status_code=401, detail="Login failed: Invalid credentials")

        user_id = auth_response.user.id
        profile = await sb.table("profiles").select("*").eq("id", user_id).maybe_single().aexecute()

        if not profile.data:
            raise HTTPException(status_code=404, detail="Profile not found")

        # profile.data is a dict (due to maybe_single in aexecute)
        p = profile.data

        # Check school subscription status
        role_lower = p.get("role", "").lower()
        school_id = p.get("school_id")
        if school_id and role_lower != "super_admin":
            school_res = await sb.table("schools").select("subscription_status").eq("id", school_id).maybe_single().aexecute()
            if school_res.data:
                school_status = school_res.data.get("subscription_status")
                if school_status:
                    status_lower = school_status.lower()
                    if status_lower in ("new", "expired"):
                        raise HTTPException(
                            status_code=403,
                            detail=f"Access denied: School subscription is {status_lower}."
                        )

        # Reset failed attempts on success and update last login
        await sb.table("profiles").update({
            "failed_login_attempts": 0,
            "lockout_until": None,
            "last_failed_login": None,
            "last_login": datetime.now(timezone.utc).isoformat()
        }).eq("id", user_id).aexecute()

        # Enforce role matching if role is requested
        admin_roles = {
            "admin", "teacher_admin", "student_admin", "super_admin", "director", 
            "principal", "finance", "hr", "transport", "library", "security", 
            "sports", "support", "driver", "hostel", "exam_ctrl"
        }
        req_role = request.role.lower() if request.role else None
        profile_role = p["role"].lower() if p.get("role") else ""
        roles_match = True
        if req_role:
            roles_match = (req_role == profile_role) or (req_role in admin_roles and profile_role in admin_roles)

        if request.role and not roles_match:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Access denied: Selected role '{request.role}' does not match user's registered role"
            )

        token = jwt.encode(
            {
                "sub": user_id,
                "school_id": p["school_id"],
                "role": p["role"],
                "class": p.get("class"),
                "email": p.get("email"),
                "exp": datetime.now(timezone.utc) + timedelta(days=7),
            },
            JWT_SECRET,
            algorithm=JWT_ALGORITHM,
        )

        # Enforce session limit
        session_limit = int(sec_settings.get("session_limit") or 5)
        active_sess_res = await sb.table("user_active_sessions").select("*").eq("user_id", user_id).order("created_at").aexecute()
        active_sessions = active_sess_res.data or []
        
        if len(active_sessions) >= session_limit:
            prune_count = len(active_sessions) - session_limit + 1
            oldest_sessions = active_sessions[:prune_count]
            for old_sess in oldest_sessions:
                await sb.table("user_active_sessions").delete().eq("id", old_sess["id"]).aexecute()
                
        # Register new session
        expires_at = datetime.now(timezone.utc) + timedelta(days=7)
        
        # Parse client details from Request
        user_agent = raw_req.headers.get("user-agent", "")
        ip_address = raw_req.headers.get("x-forwarded-for") or (raw_req.client.host if raw_req.client else "127.0.0.1")
        if "," in ip_address:
            ip_address = ip_address.split(",")[0].strip()
            
        device_name = "Unknown Device"
        browser_name = "Unknown Browser"
        ua_lower = user_agent.lower()
        if "windows" in ua_lower:
            device_name = "Windows"
        elif "macintosh" in ua_lower or "mac os x" in ua_lower:
            device_name = "MacOS"
        elif "iphone" in ua_lower or "ipad" in ua_lower:
            device_name = "iOS"
        elif "android" in ua_lower:
            device_name = "Android"
        elif "linux" in ua_lower:
            device_name = "Linux"
            
        if "edg" in ua_lower:
            browser_name = "Edge"
        elif "opr" in ua_lower or "opera" in ua_lower:
            browser_name = "Opera"
        elif "chrome" in ua_lower:
            browser_name = "Chrome"
        elif "safari" in ua_lower:
            browser_name = "Safari"
        elif "firefox" in ua_lower:
            browser_name = "Firefox"
            
        if ip_address in ("127.0.0.1", "localhost", "::1") or ip_address.startswith("172.") or ip_address.startswith("192.168.") or ip_address.startswith("10."):
            location = "Local Network"
        else:
            location = "Noida, India"

        await sb.table("user_active_sessions").insert({
            "user_id": user_id,
            "token": token,
            "device_name": device_name,
            "browser_name": browser_name,
            "ip_address": ip_address,
            "location": location,
            "expires_at": expires_at.isoformat()
        }).aexecute()

        return LoginResponse(
            success=True,
            school_id=p["school_id"],
            data={
                "token": token,
                "refresh_token": auth_response.session.refresh_token,
                "supabase_access_token": auth_response.session.access_token,
                "user": {
                    "id": user_id,
                    "full_name": p["full_name"],
                    "role": p["role"],
                    "class": p.get("class"),
                    "school_id": p["school_id"],
                    "avatar_url": p.get("avatar_url"),
                },
            }
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Login failed: {str(e)}")


@router.post("/register",
    summary="User Registration",
    description="Register a new user account with email, password, and profile information",
    responses={
        200: {
            "description": "Registration successful",
            "model": RegisterResponse,
            "content": {
                "application/json": {
                    "example": {
                        "success": True,
                        "message": "Registration successful"
                    }
                }
            }
        },
        400: {
            "description": "Registration failed",
            "model": ErrorResponse,
            "content": {
                "application/json": {
                    "example": {
                        "success": False,
                        "detail": "Registration failed: Email already exists"
                    }
                }
            }
        }
    }
)
async def register(request: RegisterRequest):
    """Register new user."""
    try:
        sb = get_supabase()
        
        school_id = request.school_id
        if not school_id or school_id.strip() == "":
            school_id = None

        # Validate password complexity
        sec_settings = get_security_settings(school_id)
        validate_password_complexity(request.password, sec_settings.get("password_policy", "Strong"))

        # Check if email already registered in profiles
        existing = await sb.table("profiles").select("id").eq("email", request.email).maybe_single().aexecute()
        if existing.data:
            raise Exception("Email already exists")

        # Except superadmin, check that school is present and not suspended
        is_superadmin = request.role.lower() == "super_admin"
        
        if not is_superadmin:
            if not school_id:
                raise Exception("School/Institution is required for non-superadmin roles")
            school_res = await sb.table("schools").select("subscription_status").eq("id", school_id).maybe_single().aexecute()
            if not school_res.data:
                raise Exception("The specified school/institute does not exist")
            if school_res.data.get("subscription_status") == "suspended":
                raise Exception("Cannot create user: The school/institute is suspended")

        auth_response = await sb.auth().admin_create_user({
            "email": request.email,
            "password": request.password,
            "app_metadata": {
                "role": request.role
            }
        })

        # Generate role-specific prefix
        role_lower = request.role.lower()
        if "student" in role_lower:
            prefix = "STU"
        elif "teacher" in role_lower:
            prefix = "TEA"
        elif "super" in role_lower:
            prefix = "SUP"
        elif "admin" in role_lower:
            prefix = "ADM"
        elif role_lower in ["principal", "director"]:
            prefix = "MGT"
        else:
            prefix = role_lower[:3].upper()
        generated_user_id = f"{prefix}-{uuid.uuid4().hex[:6].upper()}"

        await sb.table("profiles").insert({
            "id": auth_response.user.id,
            "school_id": school_id if not is_superadmin else None,
            "user_id": generated_user_id,
            "full_name": request.full_name,
            "email": request.email,
            "role": request.role,
            "class": request.class_name,
        }).aexecute()

        return RegisterResponse(
            success=True,
            message="Registration successful"
        )
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Registration failed: {str(e)}")


@router.get("/plans",
    summary="Get subscription plans",
    description="List all available subscription plans for onboarding"
)
async def list_public_plans():
    try:
        sb = get_supabase()
        res = await sb.table("subscription_plans").select("*").order("price_per_month").aexecute()
        plans = res.data or []
        return {"success": True, "data": {"plans": plans}}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch plans: {str(e)}")


@router.post("/onboard-school",
    summary="Onboard a new school",
    description="Register a new school, its initial admin, and setup subscription/payment"
)
async def onboard_school(request: OnboardSchoolRequest):
    try:
        sb = get_supabase()
        
        # 1. Check if email already registered
        existing = await sb.table("profiles").select("id").eq("email", request.email).maybe_single().aexecute()
        if existing.data:
            raise HTTPException(status_code=400, detail="Email already exists")
            
        # 2. Validate password complexity
        if len(request.password) < 6:
            raise HTTPException(status_code=400, detail="Password must be at least 6 characters")
            
        # 3. Create a new school in schools table with subscription_status = 'new'
        school_data = {
            "name": request.school_name,
            "address": request.school_address,
            "phone": request.school_phone,
            "board": request.board,
            "subscription_status": "new",
            "subscription_tier": request.plan_code,
            "owner_name": request.full_name,
            "owner_email": request.email,
            "subscription_start_date": datetime.now(timezone.utc).isoformat(),
            "subscription_end_date": (datetime.now(timezone.utc) + timedelta(days=365)).isoformat() if request.billing_cycle == "yearly" else (datetime.now(timezone.utc) + timedelta(days=30)).isoformat()
        }
        
        school_res = await sb.table("schools").insert(school_data).aexecute()
        if not school_res.data:
            raise Exception("Failed to create school record")
            
        new_school = school_res.data[0]
        school_id = new_school["id"]
        
        # 4. Create the admin user in Supabase auth
        auth_response = await sb.auth().admin_create_user({
            "email": request.email,
            "password": request.password,
            "app_metadata": {
                "role": "admin"
            }
        })
        user_id = auth_response.user.id
        
        # 5. Insert profile
        generated_user_id = f"ADM-{uuid.uuid4().hex[:6].upper()}"
        await sb.table("profiles").insert({
            "id": user_id,
            "school_id": school_id,
            "user_id": generated_user_id,
            "full_name": request.full_name,
            "email": request.email,
            "role": "admin",
        }).aexecute()
        
        # 6. Insert mail subscription
        await sb.table("school_mail_subscriptions").insert({
            "school_id": school_id,
            "enabled": True,
            "pricing_model": "per_email",
            "rate_per_unit": 0.10,
            "monthly_limit": 5000,
            "emails_sent": 0
        }).aexecute()
        
        # 7. Insert payment record
        await sb.table("payments").insert({
            "school_id": school_id,
            "amount": request.payment_amount,
            "payment_method": request.payment_method,
            "status": "success",
            "description": f"Subscription payment for plan: {request.plan_code} ({request.billing_cycle})",
            "initiated_by": user_id,
            "transaction_id": f"TXN-{uuid.uuid4().hex[:8].upper()}"
        }).aexecute()
        
        return {
            "success": True,
            "message": "School registered successfully. Pending superadmin approval.",
            "data": {
                "school_id": school_id,
                "user_id": user_id
            }
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Onboarding failed: {str(e)}")


@router.post("/refresh",
    summary="Token Refresh",
    description="Refresh JWT token using refresh token",
    responses={
        200: {
            "description": "Token refreshed successfully",
            "model": RefreshResponse,
            "content": {
                "application/json": {
                    "example": {
                        "success": True,
                        "data": {
                            "token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9..."
                        }
                    }
                }
            }
        },
        400: {
            "description": "Invalid request",
            "model": ErrorResponse,
            "content": {
                "application/json": {
                    "example": {
                        "success": False,
                        "detail": "Refresh token required"
                    }
                }
            }
        },
        401: {
            "description": "Token refresh failed",
            "model": ErrorResponse,
            "content": {
                "application/json": {
                    "example": {
                        "success": False,
                        "detail": "Token refresh failed: Invalid refresh token"
                    }
                }
            }
        }
    }
)
async def refresh_token(request: RefreshRequest):
    """Refresh JWT token."""
    try:
        sb = get_supabase()
        refresh_token = request.refresh_token

        auth_response = await sb.auth().refresh_session(refresh_token)
        profile = await sb.table("profiles").select("*").eq("id", auth_response.user.id).single().aexecute()

        p = profile.data

        # Check school subscription status
        role_lower = p.get("role", "").lower()
        school_id = p.get("school_id")
        if school_id and role_lower != "super_admin":
            school_res = await sb.table("schools").select("subscription_status").eq("id", school_id).maybe_single().aexecute()
            if school_res.data:
                school_status = school_res.data.get("subscription_status")
                if school_status:
                    status_lower = school_status.lower()
                    if status_lower in ("new", "expired"):
                        raise HTTPException(
                            status_code=403,
                            detail=f"Access denied: School subscription is {status_lower}."
                        )

        token = jwt.encode(
            {
                "sub": auth_response.user.id,
                "school_id": p["school_id"],
                "role": p["role"],
                "class": p.get("class"),
                "email": p.get("email"),
                "exp": datetime.now(timezone.utc) + timedelta(days=7),
            },
            JWT_SECRET,
            algorithm=JWT_ALGORITHM,
        )

        return RefreshResponse(
            success=True,
            data={"token": token}
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Token refresh failed: {str(e)}")


def generate_otp(length: int = 6) -> str:
    """Generate a secure random OTP."""
    return ''.join([str(random.randint(0, 9)) for _ in range(length)])


async def check_rate_limit(sb, identifier: str) -> bool:
    """Check if user has exceeded rate limit for OTP requests."""
    one_hour_ago = datetime.now(timezone.utc) - timedelta(hours=1)
    
    result = await sb.table("password_resets").select("id").eq("user_id", identifier).gte("created_at", one_hour_ago.isoformat()).aexecute()
    
    return len(result.data) < settings.OTP_RATE_LIMIT_PER_HOUR


async def find_user_by_identifier(sb, identifier: str) -> dict:
    """Find user by email or user_id."""
    # Try to find by email first
    result = await sb.table("profiles").select("*").eq("email", identifier).maybe_single().aexecute()
    
    if result.data:
        return result.data
    
    # Try to find by user_id (UUID)
    try:
        uuid.UUID(identifier)
        result = await sb.table("profiles").select("*").eq("id", identifier).maybe_single().aexecute()
        if result.data:
            return result.data
    except ValueError:
        pass
    
    return None


@router.post("/send-otp",
    summary="Send OTP",
    description="Send OTP to user's email for password reset. Identifier can be email or user_id.",
    responses={
        200: {
            "description": "OTP sent successfully",
            "model": OtpResponse,
            "content": {
                "application/json": {
                    "example": {
                        "success": True,
                        "message": "OTP sent successfully",
                        "expires_in": 900
                    }
                }
            }
        },
        400: {
            "description": "Invalid request",
            "model": ErrorResponse,
            "content": {
                "application/json": {
                    "example": {
                        "success": False,
                        "detail": "Identifier (email or user_id) required"
                    }
                }
            }
        },
        404: {
            "description": "User not found",
            "model": ErrorResponse,
            "content": {
                "application/json": {
                    "example": {
                        "success": False,
                        "detail": "User not found"
                    }
                }
            }
        },
        429: {
            "description": "Rate limit exceeded",
            "model": ErrorResponse,
            "content": {
                "application/json": {
                    "example": {
                        "success": False,
                        "detail": "Rate limit exceeded. Maximum 3 OTP requests per hour."
                    }
                }
            }
        },
        500: {
            "description": "Server error",
            "model": ErrorResponse,
            "content": {
                "application/json": {
                    "example": {
                        "success": False,
                        "detail": "Failed to send OTP: Database error"
                    }
                }
            }
        }
    }
)
async def send_otp(request: EnhancedSendOtpRequest):
    """Send OTP for password reset."""
    try:
        sb = get_supabase()
        email_service = get_email_service()
        
        identifier = request.identifier
        user_name = request.user_name
        
        # Find user
        user = await find_user_by_identifier(sb, identifier)
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        user_id = user["id"]
        user_email = user.get("email") or (identifier if "@" in identifier else None)
        full_name = user.get("full_name", user_name)
        
        # Check rate limit
        if not await check_rate_limit(sb, user_id):
            raise HTTPException(
                status_code=429, 
                detail=f"Rate limit exceeded. Maximum {settings.OTP_RATE_LIMIT_PER_HOUR} OTP requests per hour."
            )
        
        # Invalidate any pending OTPs for this user
        await sb.table("password_resets").update({"status": "used"}).eq("user_id", user_id).eq("status", "pending").aexecute()
        
        # Generate OTP
        otp = generate_otp(settings.OTP_LENGTH)
        expires_at = datetime.now(timezone.utc) + timedelta(minutes=settings.OTP_EXPIRATION_MINUTES)
        
        # Store OTP in database
        await sb.table("password_resets").insert({
            "user_id": user_id,
            "school_id": user.get("school_id"),
            "otp": otp,
            "expires_at": expires_at.isoformat(),
            "status": "pending"
        }).aexecute()
        
        # Send email with OTP
        email_sent = email_service.send_otp_email(user_email, otp, full_name)
        
        if not email_sent:
            # Log the failure but don't fail the request
            logging.warning(f"Failed to send OTP email to {user_email}, but OTP was generated")
        
        expires_in = int(settings.OTP_EXPIRATION_MINUTES * 60)
        
        return OtpResponse(
            success=True,
            message="OTP sent successfully",
            expires_in=expires_in
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Error sending OTP: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to send OTP: {str(e)}")


@router.post("/verify-otp",
    summary="Verify OTP",
    description="Verify OTP for password reset using identifier and OTP code",
    responses={
        200: {
            "description": "OTP verified successfully",
            "model": VerifyOtpResponse,
            "content": {
                "application/json": {
                    "example": {
                        "success": True,
                        "message": "OTP verified successfully"
                    }
                }
            }
        },
        400: {
            "description": "Invalid OTP",
            "model": ErrorResponse,
            "content": {
                "application/json": {
                    "example": {
                        "success": False,
                        "detail": "Identifier and OTP required"
                    }
                }
            }
        },
        404: {
            "description": "User not found",
            "model": ErrorResponse,
            "content": {
                "application/json": {
                    "example": {
                        "success": False,
                        "detail": "User not found"
                    }
                }
            }
        },
        500: {
            "description": "Server error",
            "model": ErrorResponse,
            "content": {
                "application/json": {
                    "example": {
                        "success": False,
                        "detail": "Failed to verify OTP: Database error"
                    }
                }
            }
        }
    }
)
async def verify_otp(request: VerifyOtpRequest):
    """Verify OTP for password reset."""
    try:
        sb = get_supabase()
        
        identifier = request.identifier
        otp = request.otp
        
        # Find user
        user = await find_user_by_identifier(sb, identifier)
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        user_id = user["id"]
        
        # Find valid OTP
        now = datetime.now(timezone.utc).isoformat()
        result = await sb.table("password_resets").select("*").eq("user_id", user_id).eq("otp", otp).eq("status", "pending").gte("expires_at", now).aexecute()
        
        if not result.data:
            raise HTTPException(status_code=400, detail="Invalid or expired OTP")
        
        # Mark OTP as verified
        otp_record = result.data[0]
        await sb.table("password_resets").update({"status": "verified"}).eq("id", otp_record["id"]).aexecute()
        
        return VerifyOtpResponse(
            success=True,
            message="OTP verified successfully"
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Error verifying OTP: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to verify OTP: {str(e)}")


@router.post("/reset-password",
    summary="Reset Password",
    description="Reset user password using OTP verification",
    responses={
        200: {
            "description": "Password reset successfully",
            "model": ResetPasswordResponse,
            "content": {
                "application/json": {
                    "example": {
                        "success": True,
                        "message": "Password reset successfully"
                    }
                }
            }
        },
        400: {
            "description": "Invalid request",
            "model": ErrorResponse,
            "content": {
                "application/json": {
                    "example": {
                        "success": False,
                        "detail": "Identifier, OTP, and new password required"
                    }
                }
            }
        },
        404: {
            "description": "User not found",
            "model": ErrorResponse,
            "content": {
                "application/json": {
                    "example": {
                        "success": False,
                        "detail": "User not found"
                    }
                }
            }
        },
        500: {
            "description": "Server error",
            "model": ErrorResponse,
            "content": {
                "application/json": {
                    "example": {
                        "success": False,
                        "detail": "Failed to reset password: Database error"
                    }
                }
            }
        }
    }
)
async def reset_password(request: EnhancedResetPasswordRequest):
    """Reset password using OTP."""
    try:
        sb = get_supabase()
        email_service = get_email_service()
        
        identifier = request.identifier
        otp = request.otp
        new_password = request.new_password
        
        # Find user
        user = await find_user_by_identifier(sb, identifier)
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        user_id = user["id"]
        user_email = user.get("email", identifier)
        full_name = user.get("full_name")

        # Validate password complexity
        sec_settings = get_security_settings(user.get("school_id"))
        validate_password_complexity(new_password, sec_settings.get("password_policy", "Strong"))
        
        # Find and verify OTP (accept both pending and verified, as verified means it's been confirmed in the previous step)
        now = datetime.now(timezone.utc).isoformat()
        result = await sb.table("password_resets").select("*").eq("user_id", user_id).eq("otp", otp).in_("status", ["pending", "verified"]).gte("expires_at", now).aexecute()
        
        if not result.data:
            raise HTTPException(status_code=400, detail="Invalid or expired OTP")
        
        otp_record = result.data[0]
        
        # Update password using Supabase Admin API
        try:
            # Use the Supabase REST API to update the user's password
            client = await sb.get_async_client()
            
            admin_url = f"{settings.SUPABASE_URL}/auth/v1/admin/users/{user_id}"
            headers = {
                "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
                "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
                "Content-Type": "application/json"
            }
            
            response = await client.put(
                admin_url,
                headers=headers,
                json={"password": new_password},
                timeout=10.0
            )
            
            if response.status_code != 200:
                error_data = response.json()
                raise Exception(error_data.get("message", "Failed to update password"))
                
        except Exception as e:
            logging.error(f"Failed to update password via Supabase Admin API: {str(e)}")
            raise HTTPException(status_code=500, detail=f"Failed to update password: {str(e)}")
        
        # Mark OTP as used
        await sb.table("password_resets").update({"status": "used"}).eq("id", otp_record["id"]).aexecute()
        
        # Send confirmation email
        email_sent = email_service.send_password_reset_confirmation(user_email, full_name)
        if not email_sent:
            logging.warning(f"Failed to send confirmation email to {user_email}")
        
        return ResetPasswordResponse(
            success=True,
            message="Password reset successfully"
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Error resetting password: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to reset password: {str(e)}")


@router.delete("/user/{identifier}")
async def delete_user(identifier: str):
    """Delete a user and their application-level profile.
    Accepts either the Supabase Auth UUID or the custom application user_id (e.g. STU-123456).
    """
    try:
        sb = get_supabase()
        
        # 1. Resolve the Auth UUID from the profile record
        auth_uuid = None
        
        # Check if identifier looks like a UUID
        is_uuid = False
        try:
            uuid.UUID(identifier)
            is_uuid = True
        except ValueError:
            is_uuid = False

        # Query profile to find the actual Auth record UUID
        if is_uuid:
            # Try finding by internal ID first (which is the Auth UUID)
            profile = await sb.table("profiles").select("id").eq("id", identifier).maybe_single().aexecute()
            if profile.data:
                auth_uuid = profile.data["id"]
        
        # If not found yet, try finding by custom user_id (STU-XXXX)
        if not auth_uuid:
            profile = await sb.table("profiles").select("id").eq("user_id", identifier).maybe_single().aexecute()
            if profile.data:
                auth_uuid = profile.data["id"]

        # If not found yet, try finding by email
        if not auth_uuid:
            profile = await sb.table("profiles").select("id").eq("email", identifier).maybe_single().aexecute()
            if profile.data:
                auth_uuid = profile.data["id"]

        # If still not found and contains '@', try database function first, fallback to GoTrue admin API
        if not auth_uuid and "@" in identifier:
            try:
                res = await sb.rpc("get_auth_user_id_by_email", {"email_addr": identifier}).aexecute()
                if res.data:
                    if isinstance(res.data, list) and res.data[0]:
                        auth_uuid = res.data[0]
                    elif isinstance(res.data, str):
                        auth_uuid = res.data
            except Exception as ex:
                logging.warning(f"Failed to query get_auth_user_id_by_email: {str(ex)}")

            if not auth_uuid:
                try:
                    client = await sb.get_async_client()
                    headers = {
                        "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
                        "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}"
                    }
                    response = await client.get(
                        f"{settings.SUPABASE_URL}/auth/v1/admin/users",
                        headers=headers,
                        timeout=10.0
                    )
                    if response.status_code == 200:
                        users_data = response.json()
                        users = users_data.get("users", [])
                        for u in users:
                            if u.get("email") == identifier:
                                auth_uuid = u.get("id")
                                break
                except Exception as ex:
                    logging.warning(f"Failed to query auth.users by email: {str(ex)}")

        # If we still don't have a UUID, and the identifier is a UUID, we assume it's a headless Auth user
        if not auth_uuid and is_uuid:
            auth_uuid = identifier

        if not auth_uuid:
            raise HTTPException(status_code=404, detail=f"User {identifier} not found in profile system or auth records.")

        # 2. Delete from Supabase Auth (admin privileges)
        auth_deleted = False
        try:
            await sb.auth().admin_delete_user(auth_uuid)
            auth_deleted = True
        except Exception as e:
            logging.warning(f"Auth record deletion failed for {auth_uuid}: {str(e)}")
            
        # 3. Delete from profiles table and all cascading records using RPC stored procedure
        await sb.rpc("rpc_admin_delete_user_cascade", {"p_user_id": auth_uuid}).aexecute()
        
        return {
            "success": True,
            "message": f"User {identifier} deleted successfully. Auth record removed: {auth_deleted}."
        }
    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Error deleting user {identifier}: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to delete user: {str(e)}")


# ──────────────────────────────────────────────────────────────
# OTP AUTHENTICATION ENDPOINTS
# ──────────────────────────────────────────────────────────────

@router.post("/send-login-otp")
async def send_login_otp(request: SendLoginOtpRequest):
    try:
        sb = get_supabase()
        email_service = get_email_service()
        
        user = await find_user_by_identifier(sb, request.identifier)
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
            
        # Check school subscription status
        role_lower = user.get("role", "").lower()
        school_id = user.get("school_id")
        if school_id and role_lower != "super_admin":
            school_res = await sb.table("schools").select("subscription_status").eq("id", school_id).maybe_single().aexecute()
            if school_res.data:
                school_status = school_res.data.get("subscription_status")
                if school_status:
                    status_lower = school_status.lower()
                    if status_lower in ("new", "expired"):
                        raise HTTPException(
                            status_code=403,
                            detail=f"Access denied: School subscription is {status_lower}."
                        )
            
        user_id = user["id"]
        user_email = user.get("email") or (request.identifier if "@" in request.identifier else None)
        
        # Generate & store OTP atomically via RPC stored procedure
        otp = generate_otp(settings.OTP_LENGTH)
        await sb.rpc("rpc_process_send_login_otp", {
            "p_identifier": request.identifier,
            "p_otp_code": otp,
            "p_ip_address": None
        }).aexecute()

        
        # Send mail
        sent = email_service.send_login_otp_email(user_email, otp, user.get("full_name"))
        if not sent:
            logging.warning(f"Failed to send login OTP email to {user_email}")
            
        return OtpResponse(
            success=True,
            message="Login OTP sent successfully",
            expires_in=int(settings.OTP_EXPIRATION_MINUTES * 60)
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to send login OTP: {str(e)}")

@router.post("/verify-login-otp")
async def verify_login_otp(request: VerifyLoginOtpRequest):
    try:
        sb = get_supabase()
        user = await find_user_by_identifier(sb, request.identifier)
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
            
        # Check school subscription status
        role_lower = user.get("role", "").lower()
        school_id = user.get("school_id")
        if school_id and role_lower != "super_admin":
            school_res = await sb.table("schools").select("subscription_status").eq("id", school_id).maybe_single().aexecute()
            if school_res.data:
                school_status = school_res.data.get("subscription_status")
                if school_status:
                    status_lower = school_status.lower()
                    if status_lower in ("new", "expired"):
                        raise HTTPException(
                            status_code=403,
                            detail=f"Access denied: School subscription is {status_lower}."
                        )
            
        user_id = user["id"]
        
        admin_roles = {
            "admin", "teacher_admin", "student_admin", "super_admin", "director", 
            "principal", "finance", "hr", "transport", "library", "security", 
            "sports", "support", "driver", "hostel", "exam_ctrl"
        }
        req_role = request.role.lower() if request.role else ""
        user_role = user["role"].lower()
        roles_match = (req_role == user_role) or (req_role in admin_roles and user_role in admin_roles)
        
        if request.role and not roles_match:
            raise HTTPException(status_code=403, detail="Selected role does not match registered profile")
            
        # Verify OTP code atomically via RPC stored procedure
        otp_res = await sb.rpc("rpc_process_verify_login_otp", {
            "p_identifier": request.identifier,
            "p_otp_code": request.otp
        }).aexecute()
        
        if not otp_res.data or not otp_res.data.get("success"):
            raise HTTPException(status_code=400, detail="Invalid or expired OTP code")

        
        token = jwt.encode(
            {
                "sub": user_id,
                "school_id": user["school_id"],
                "role": user["role"],
                "class": user.get("class"),
                "email": user.get("email"),
                "exp": datetime.now(timezone.utc) + timedelta(days=7),
            },
            JWT_SECRET,
            algorithm=JWT_ALGORITHM,
        )
        
        return LoginResponse(
            success=True,
            school_id=user["school_id"],
            data={
                "token": token,
                "user": {
                    "id": user_id,
                    "full_name": user["full_name"],
                    "role": user["role"],
                    "class": user.get("class"),
                    "school_id": user["school_id"],
                    "avatar_url": user.get("avatar_url"),
                },
            }
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to verify login OTP: {str(e)}")


# ──────────────────────────────────────────────────────────────
# ADMIN USER DIRECTORY CRUD
# ──────────────────────────────────────────────────────────────

class UpdateUserRequest(BaseModel):
    full_name: Optional[str] = None
    email: Optional[str] = None
    role: Optional[str] = None
    school_id: Optional[str] = None
    class_name: Optional[str] = None
    password: Optional[str] = None
    status: Optional[str] = None
    department: Optional[str] = None
    manager_id: Optional[str] = None


class AssignManagerRequest(BaseModel):
    user_ids: List[str]
    manager_id: Optional[str] = None


@router.get("/users/stats",
    summary="Get User Directory Statistics",
    description="Retrieve dynamic statistics and summaries for the user directory dashboard."
)
async def get_user_stats(
    school_id: Optional[str] = None,
    user=Depends(get_current_user)
):
    try:
        sb = get_supabase()
        
        caller_role = user.get("role", "").lower()
        target_school_id = school_id
        if caller_role != "super_admin":
            target_school_id = user.get("school_id")
            
        query = sb.table("profiles").select("*")
        if target_school_id:
            query = query.eq("school_id", target_school_id)
            
        res = await query.aexecute()
        users = res.data or []
        
        # Deduplicate users by ID and email
        seen_stats_ids = set()
        seen_stats_emails = set()
        unique_users_for_stats = []
        for u in users:
            uid = str(u.get("id") or "")
            uemail = (u.get("email") or "").strip().lower()
            if uid and uid in seen_stats_ids:
                continue
            if uemail and uemail in seen_stats_emails:
                continue
            if uid:
                seen_stats_ids.add(uid)
            if uemail:
                seen_stats_emails.add(uemail)
            unique_users_for_stats.append(u)

        users = unique_users_for_stats
        total_users = len(users)
        active_users = 0
        inactive_users = 0
        locked_users = 0
        
        from datetime import datetime, timezone, date
        now = datetime.now(timezone.utc)
        today = date.today()
        
        new_this_month = 0
        start_of_month = datetime(today.year, today.month, 1, tzinfo=timezone.utc)
        
        # Query audit logs for real logins today
        from datetime import time
        start_of_day = datetime.combine(today, time.min).replace(tzinfo=timezone.utc)
        logins_query = sb.table("audit_logs").select("id").eq("event_type", "Login").gte("created_at", start_of_day.isoformat())
        if target_school_id:
            logins_query = logins_query.eq("school_id", target_school_id)
        logins_res = await logins_query.aexecute()
        logins_today = len(logins_res.data or [])

        # Query profiles for real registrations today
        regs_query = sb.table("profiles").select("id").gte("created_at", start_of_day.isoformat())
        if target_school_id:
            regs_query = regs_query.eq("school_id", target_school_id)
        regs_res = await regs_query.aexecute()
        regs_today = len(regs_res.data or [])
        
        role_breakdown = {}
        
        for u in users:
            lockout_until_str = u.get("lockout_until")
            is_locked = False
            if lockout_until_str:
                try:
                    lockout_until = datetime.fromisoformat(lockout_until_str.replace("Z", "+00:00"))
                    if lockout_until > now:
                        is_locked = True
                except Exception:
                    pass
                    
            db_status = u.get("status") or "Active"
            if is_locked or db_status == "Locked":
                locked_users += 1
            elif db_status == "Inactive":
                inactive_users += 1
            else:
                active_users += 1
                
            created_at_str = u.get("created_at")
            if created_at_str:
                try:
                    created_at = datetime.fromisoformat(created_at_str.replace("Z", "+00:00"))
                    if created_at >= start_of_month:
                        new_this_month += 1
                except Exception:
                    pass
                    
            role = u.get("role", "user")
            role_breakdown[role] = role_breakdown.get(role, 0) + 1
            
        return {
            "success": True,
            "data": {
                "total_users": total_users,
                "active_users": active_users,
                "inactive_users": inactive_users,
                "locked_users": locked_users,
                "new_this_month": new_this_month,
                "role_breakdown": role_breakdown,
                "activity_summary": {
                    "logins_today": logins_today,
                    "new_registrations_today": regs_today
                }
            }
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch user statistics: {str(e)}")


@router.get("/users",
    summary="List All Users",
    description="Retrieve all profiles with optional search and filters. Restricted by school for non-super_admins."
)
async def list_users(
    q: Optional[str] = None,
    role: Optional[str] = None,
    school_id: Optional[str] = None,
    status: Optional[str] = None,
    department: Optional[str] = None,
    user=Depends(get_current_user)
):
    try:
        sb = get_supabase()
        
        # We start by querying the profiles table and joining the schools table to fetch school name and subscription status.
        query = sb.table("profiles").select("*, schools(name, subscription_status)")
        
        caller_role = user.get("role", "").lower()
        if caller_role != "super_admin":
            caller_school_id = user.get("school_id")
            if not caller_school_id:
                raise HTTPException(status_code=403, detail="Access denied: No school ID associated with your account")
            query = query.eq("school_id", caller_school_id)
        else:
            if school_id:
                query = query.eq("school_id", school_id)
                
        if role and role != "All":
            query = query.eq("role", role)
            
        if q and q.strip():
            search_str = q.strip()
            query = query.or_(f"full_name.ilike.%{search_str}%,email.ilike.%{search_str}%,user_id.ilike.%{search_str}%")
            
        res = await query.order("created_at", ascending=False).aexecute()
        users = res.data or []
        
        # Batch resolve reporting manager info
        manager_ids = list({u.get("manager_id") for u in users if u.get("manager_id")})
        manager_map = {}
        if manager_ids:
            try:
                mgr_res = await sb.table("profiles").select("id, full_name, email, role, avatar_url, department").in_("id", manager_ids).aexecute()
                for m in (mgr_res.data or []):
                    manager_map[m["id"]] = m
            except Exception as e:
                logger.warning(f"Failed to batch resolve manager profiles: {e}")

        # Format the joined school & manager data
        formatted_users = []
        for u in users:
            school_obj = u.pop("schools", None)
            if school_obj:
                u["school_name"] = school_obj.get("name")
                u["school_status"] = school_obj.get("subscription_status")
            else:
                u["school_name"] = "System-wide" if u["role"] == "super_admin" else "Unknown"
                u["school_status"] = None

            # Attach Manager Info
            mgr_id = u.get("manager_id")
            mgr = manager_map.get(mgr_id)
            if mgr:
                u["manager_name"] = mgr.get("full_name")
                u["manager_email"] = mgr.get("email")
                u["manager_role"] = mgr.get("role")
                u["manager_avatar_url"] = mgr.get("avatar_url")
                u["manager_department"] = mgr.get("department")
            else:
                u["manager_name"] = None
                u["manager_email"] = None
                u["manager_role"] = None
                u["manager_avatar_url"] = None
                u["manager_department"] = None
                
            # Resolve dynamic status
            lockout_until_str = u.get("lockout_until")
            is_locked = False
            if lockout_until_str:
                try:
                    from datetime import datetime, timezone
                    lockout_until = datetime.fromisoformat(lockout_until_str.replace("Z", "+00:00"))
                    if lockout_until > datetime.now(timezone.utc):
                        is_locked = True
                except Exception:
                    pass
            
            db_status = u.get("status") or "Active"
            if is_locked or db_status == "Locked":
                u["status"] = "Locked"
            else:
                u["status"] = db_status
                
            # Filter by status in python
            if status and status != "All" and status.lower() != "all":
                if u["status"].lower() != status.lower():
                    continue
                    
            # Filter by department in python
            if department and department != "All" and department.lower() != "all":
                if (u.get("department") or "").lower() != department.lower():
                    continue
                    
            formatted_users.append(u)
            
        # Deduplicate users by ID and email (case-insensitive) to prevent duplicate display
        seen_user_ids = set()
        seen_user_emails = set()
        unique_users = []
        for u in formatted_users:
            uid = str(u.get("id") or "")
            uemail = (u.get("email") or "").strip().lower()
            if uid and uid in seen_user_ids:
                continue
            if uemail and uemail in seen_user_emails:
                continue
            if uid:
                seen_user_ids.add(uid)
            if uemail:
                seen_user_emails.add(uemail)
            unique_users.append(u)

        return {"success": True, "data": unique_users}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch users: {str(e)}")


@router.put("/users/{user_id}",
    summary="Update User Profile",
    description="Update user profile fields and optionally their authentication credentials."
)
async def update_user(
    user_id: str,
    request: UpdateUserRequest,
    user=Depends(get_current_user)
):
    try:
        from datetime import datetime, timedelta
        sb = get_supabase()
        
        # Check if profile exists (by id or user_id)
        profile_res = await sb.table("profiles").select("*").or_(f"id.eq.{user_id},user_id.eq.{user_id}").maybe_single().aexecute()
        if not profile_res.data:
            raise HTTPException(status_code=404, detail="User profile not found")
            
        current_profile = profile_res.data
        real_profile_id = current_profile["id"]
        current_email = current_profile.get("email")
        
        # Permission check
        caller_role = user.get("role", "").lower()
        if caller_role != "super_admin":
            if current_profile.get("school_id") != user.get("school_id"):
                raise HTTPException(status_code=403, detail="Access denied: Cannot update user from another school")
                
        # Prepare profile updates
        update_data = {}
        if request.full_name is not None:
            update_data["full_name"] = request.full_name
        if request.class_name is not None:
            update_data["class"] = request.class_name
        if request.department is not None:
            update_data["department"] = request.department
        if request.manager_id is not None:
            update_data["manager_id"] = None if (request.manager_id == "" or request.manager_id.lower() == "none") else request.manager_id
        if request.status is not None:
            update_data["status"] = request.status
            if request.status == "Locked":
                future_lockout = datetime.utcnow() + timedelta(days=365*100)
                update_data["lockout_until"] = future_lockout.isoformat()
            else:
                update_data["lockout_until"] = None
                update_data["failed_login_attempts"] = 0
            
        new_role = request.role or current_profile.get("role")
        new_school_id = request.school_id or current_profile.get("school_id")
        
        role_changed = False
        if request.role is not None and request.role != current_profile.get("role"):
            update_data["role"] = request.role
            role_changed = True
            
        if request.school_id is not None:
            update_data["school_id"] = request.school_id if new_role.lower() != "super_admin" else None
            new_school_id = update_data["school_id"]
            
        # Check school suspension status if role is not superadmin
        if new_role.lower() != "super_admin":
            if not new_school_id:
                raise HTTPException(status_code=400, detail="School ID is required for non-superadmin roles")
            school_res = await sb.table("schools").select("subscription_status").eq("id", new_school_id).maybe_single().aexecute()
            if not school_res.data:
                raise HTTPException(status_code=400, detail="The specified school/institute does not exist")
            if school_res.data.get("subscription_status") == "suspended":
                raise HTTPException(status_code=400, detail="Cannot update user: The school/institute is suspended")
                
        # Check if email is changing
        email_changed = False
        if request.email and request.email.lower() != (current_email or "").lower():
            existing = await sb.table("profiles").select("id").eq("email", request.email).neq("id", real_profile_id).maybe_single().aexecute()
            if existing.data:
                raise HTTPException(status_code=400, detail="Email already exists in another profile")
            update_data["email"] = request.email
            email_changed = True
            
        # Update Supabase Auth if role, email or password changes
        if role_changed or email_changed or request.password:
            try:
                client = await sb.get_async_client()
                admin_url = f"{settings.SUPABASE_URL}/auth/v1/admin/users/{real_profile_id}"
                headers = {
                    "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
                    "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
                    "Content-Type": "application/json"
                }
                json_payload = {}
                if email_changed:
                    json_payload["email"] = request.email
                if request.password:
                    json_payload["password"] = request.password
                if role_changed:
                    json_payload["app_metadata"] = {
                        "role": request.role
                    }
                    
                auth_res = await client.put(admin_url, headers=headers, json=json_payload, timeout=10.0)
                
                if auth_res.status_code == 404:
                    # User profile exists in DB but GoTrue auth user record is missing (e.g. seeded user).
                    # Create the missing auth user record in GoTrue so password/credentials update succeeds.
                    target_email = request.email if email_changed else current_email
                    target_role = request.role if role_changed else current_profile.get("role", "student")
                    create_url = f"{settings.SUPABASE_URL}/auth/v1/admin/users"
                    create_payload = {
                        "id": real_profile_id,
                        "email": target_email,
                        "password": request.password or "Password123!",
                        "email_confirm": True,
                        "app_metadata": {
                            "role": target_role
                        },
                        "user_metadata": {
                            "full_name": request.full_name or current_profile.get("full_name")
                        }
                    }
                    create_res = await client.post(create_url, headers=headers, json=create_payload, timeout=10.0)
                    if create_res.status_code not in [200, 201]:
                        # If creating with explicit ID failed (e.g. email exists under different auth ID), search by email
                        search_res = await client.get(create_url, headers=headers, timeout=10.0)
                        auth_user_id = None
                        if search_res.status_code == 200:
                            user_list = search_res.json().get("users", [])
                            for u in user_list:
                                if (u.get("email") or "").lower() == (target_email or "").lower():
                                    auth_user_id = u.get("id")
                                    break
                        if auth_user_id:
                            alt_url = f"{settings.SUPABASE_URL}/auth/v1/admin/users/{auth_user_id}"
                            alt_res = await client.put(alt_url, headers=headers, json=json_payload, timeout=10.0)
                            if alt_res.status_code != 200:
                                err_detail = alt_res.text
                                raise Exception(f"Auth update failed for auth user {auth_user_id}: {err_detail}")
                        else:
                            try:
                                err_detail = create_res.json().get("message", create_res.text)
                            except Exception:
                                err_detail = create_res.text
                            raise Exception(f"Auth user creation failed: {err_detail}")
                elif auth_res.status_code != 200:
                    try:
                        err_detail = auth_res.json().get("message", auth_res.text)
                    except Exception:
                        err_detail = auth_res.text
                    raise Exception(f"Auth update failed with status {auth_res.status_code}: {err_detail}")
            except Exception as e:
                raise HTTPException(status_code=500, detail=f"Failed to update authentication details: {str(e)}")
                
        # Save profile update in database
        if update_data:
            update_data["updated_at"] = datetime.utcnow().isoformat()
            await sb.table("profiles").update(update_data).eq("id", real_profile_id).aexecute()
            
        return {"success": True, "message": "User updated successfully"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to update user: {str(e)}")


@router.get("/users/managers",
    summary="List Eligible Reporting Managers",
    description="Retrieve all eligible managers based on role hierarchy, role rank levels, and direct report counts."
)
async def list_eligible_managers(
    q: Optional[str] = None,
    department: Optional[str] = None,
    school_id: Optional[str] = None,
    target_user_ids: Optional[str] = None,
    target_role: Optional[str] = None,
    user=Depends(get_current_user)
):
    try:
        sb = get_supabase()
        caller_role = user.get("role", "").lower()
        effective_school_id = user.get("school_id") if caller_role != "super_admin" else school_id

        # 1. Fetch active roles from app_roles for dynamic hierarchy metadata
        roles_res = await sb.table("app_roles").select("id, name, display_name, level, parent_role_id, role_type, is_custom, status").or_("status.eq.Active,status.is.null").aexecute()
        all_app_roles = [r for r in (roles_res.data or []) if (r.get("status") or "Active").lower() == "active"]
        role_map = {}
        for r in all_app_roles:
            rname = (r.get("name") or "").lower()
            role_map[rname] = {
                "id": r.get("id"),
                "name": rname,
                "display_name": r.get("display_name") or rname.replace("_", " ").title(),
                "level": r.get("level") or 3,
                "parent_role_id": r.get("parent_role_id"),
                "role_type": r.get("role_type") or "SYSTEM"
            }

        # 2. Determine target user(s) and their role level
        target_ids_list = [uid.strip() for uid in target_user_ids.split(",") if uid.strip()] if target_user_ids else []
        target_profiles = []
        target_role_level = 99
        target_role_display = "User"

        if target_ids_list:
            t_res = await sb.table("profiles").select("id, full_name, role, school_id, manager_id").in_("id", target_ids_list).aexecute()
            target_profiles = t_res.data or []
            if target_profiles:
                levels = [role_map.get((p.get("role") or "").lower(), {}).get("level", 3) for p in target_profiles]
                target_role_level = min(levels)
                primary_role = (target_profiles[0].get("role") or "").lower()
                target_role_display = role_map.get(primary_role, {}).get("display_name", primary_role.title())
        elif target_role:
            rname = target_role.lower()
            target_role_level = role_map.get(rname, {}).get("level", 3)
            target_role_display = role_map.get(rname, {}).get("display_name", rname.title())

        # 3. Determine eligible manager roles dynamically based on Role Hierarchy:
        # A candidate manager's role level MUST be <= target_role_level (i.e. numerically lower or equal level = higher/equal authority)
        eligible_roles = []
        for rname, rinfo in role_map.items():
            if rinfo.get("level", 3) <= target_role_level:
                eligible_roles.append(rname)

        if not eligible_roles:
            eligible_roles = ["super_admin", "owner"] if target_role_level <= 1 else ["super_admin", "admin", "director", "principal"]

        # 5. Query active candidate profiles
        query = sb.table("profiles").select("id, user_id, full_name, email, role, department, designation, avatar_url, school_id, manager_id")
        
        if effective_school_id and str(effective_school_id).strip():
            query = query.eq("school_id", effective_school_id)
            
        if department and department != "All":
            query = query.eq("department", department)
            
        if q and q.strip():
            search_str = q.strip()
            query = query.or_(f"full_name.ilike.%{search_str}%,email.ilike.%{search_str}%,user_id.ilike.%{search_str}%")
            
        res = await query.order("full_name", ascending=True).aexecute()
        raw_profiles = res.data or []

        # 6. Filter candidates:
        # - Exclude target users themselves (cannot manage self)
        # - Exclude subordinate descendants (prevent circular loops)
        # - Must belong to eligible_roles
        target_ids_set = set(target_ids_list)
        
        subordinate_ids = set()
        if target_ids_set:
            all_profiles_res = await sb.table("profiles").select("id, manager_id").aexecute()
            all_p = all_profiles_res.data or []
            curr_parents = set(target_ids_set)
            while curr_parents:
                next_gen = {p["id"] for p in all_p if p.get("manager_id") in curr_parents and p["id"] not in subordinate_ids}
                if not next_gen:
                    break
                subordinate_ids.update(next_gen)
                curr_parents = next_gen

        # 7. Count direct reports
        direct_counts = {}
        if raw_profiles:
            mgr_ids = [m["id"] for m in raw_profiles]
            count_res = await sb.table("profiles").select("manager_id").in_("manager_id", mgr_ids).aexecute()
            for r in (count_res.data or []):
                m_id = r.get("manager_id")
                if m_id:
                    direct_counts[m_id] = direct_counts.get(m_id, 0) + 1

        managers_list = []
        eligible_roles_present = set()

        for p in raw_profiles:
            pid = str(p.get("id") or "")
            prole = (p.get("role") or "").lower()

            if pid in target_ids_set or pid in subordinate_ids:
                continue

            if prole not in eligible_roles:
                continue

            rmeta = role_map.get(prole, {})
            p["role_display_name"] = rmeta.get("display_name", prole.replace("_", " ").title())
            p["role_level"] = rmeta.get("level", 3)
            p["direct_reports_count"] = direct_counts.get(pid, 0)
            managers_list.append(p)
            eligible_roles_present.add(p["role_display_name"])

        # Sort: Highest authority (Level 1 -> 2 -> 3) first, then most direct reports, then name
        managers_list.sort(key=lambda x: (x.get("role_level", 99), -x.get("direct_reports_count", 0), x.get("full_name", "")))

        return {
            "success": True,
            "data": managers_list,
            "count": len(managers_list),
            "target_role_level": target_role_level,
            "target_role_display": target_role_display,
            "eligible_role_display_names": sorted(list(eligible_roles_present))
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch managers: {str(e)}")


@router.post("/users/assign-manager",
    summary="Assign or Clear Reporting Manager for Users",
    description="Assign a manager to one or multiple users, or clear their manager if manager_id is null."
)
async def assign_manager(
    payload: AssignManagerRequest,
    user=Depends(get_current_user)
):
    try:
        from datetime import datetime
        sb = get_supabase()
        caller_role = user.get("role", "").lower()
        caller_school_id = user.get("school_id")

        if not payload.user_ids:
            raise HTTPException(status_code=400, detail="At least one user ID must be provided")

        user_ids = list(set(payload.user_ids))

        # Check self-assignment / circular validation
        manager_data = None
        if payload.manager_id and payload.manager_id.strip() and payload.manager_id.lower() != "none":
            if payload.manager_id in user_ids:
                raise HTTPException(status_code=400, detail="A user cannot be assigned as their own reporting manager.")
                
            # Verify manager exists
            mgr_res = await sb.table("profiles").select("id, full_name, school_id, role, department").eq("id", payload.manager_id).maybe_single().aexecute()
            if not mgr_res.data:
                raise HTTPException(status_code=404, detail="Selected manager profile not found")
            manager_data = mgr_res.data

            if caller_role != "super_admin" and manager_data.get("school_id") != caller_school_id:
                raise HTTPException(status_code=403, detail="Manager belongs to a different institution")
            update_val = payload.manager_id
        else:
            update_val = None

        # Fetch users to verify permissions
        target_res = await sb.table("profiles").select("id, full_name, school_id, role").in_("id", user_ids).aexecute()
        targets = target_res.data or []
        if not targets:
            raise HTTPException(status_code=404, detail="No matching user profiles found")

        # Role Hierarchy Validation
        if manager_data and targets:
            roles_res = await sb.table("app_roles").select("name, level, display_name").aexecute()
            role_level_map = { (r.get("name") or "").lower(): r.get("level") or 3 for r in (roles_res.data or []) }
            
            mgr_role = (manager_data.get("role") or "").lower()
            mgr_level = role_level_map.get(mgr_role, 3)
            
            for t in targets:
                t_role = (t.get("role") or "").lower()
                t_level = role_level_map.get(t_role, 3)
                if mgr_level > t_level:
                    raise HTTPException(
                        status_code=400,
                        detail=f"Role Hierarchy Violation: Manager {manager_data.get('full_name')} (Level {mgr_level}) cannot be assigned to {t.get('full_name')} (Level {t_level}). Manager must have higher or equal rank in the role hierarchy."
                    )

        # Verify that all selected users belong to the exact same school
        target_schools = set(t.get("school_id") for t in targets if t.get("school_id"))
        if len(target_schools) > 1:
            raise HTTPException(
                status_code=400,
                detail="Cannot assign manager to users from multiple schools. All selected users must belong to the same school."
            )

        # If manager is specified, verify manager belongs to the same school as target users
        if manager_data and target_schools:
            target_school_id = list(target_schools)[0]
            mgr_school_id = manager_data.get("school_id")
            if mgr_school_id and mgr_school_id != target_school_id:
                raise HTTPException(
                    status_code=400,
                    detail="The selected reporting manager belongs to a different school than the selected user(s)."
                )

        if caller_role != "super_admin":
            for t in targets:
                if t.get("school_id") != caller_school_id:
                    raise HTTPException(status_code=403, detail=f"Access denied: User {t.get('full_name')} belongs to another school")

        valid_ids = [t["id"] for t in targets]

        # Update manager_id for all target users
        await sb.table("profiles").update({
            "manager_id": update_val,
            "updated_at": datetime.utcnow().isoformat()
        }).in_("id", valid_ids).aexecute()

        msg = f"Assigned {manager_data['full_name']} as reporting manager for {len(valid_ids)} user(s)" if manager_data else f"Cleared reporting manager for {len(valid_ids)} user(s)"

        return {
            "success": True,
            "message": msg,
            "updated_count": len(valid_ids),
            "manager": manager_data
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to assign manager: {str(e)}")


# ──────────────────────────────────────────────────────────────
# BULK IMPORT ENDPOINT
# ──────────────────────────────────────────────────────────────

class BulkImportUser(BaseModel):
    full_name: str
    email: str
    phone: Optional[str] = None
    password: str
    class_name: Optional[str] = None


class BulkImportRequest(BaseModel):
    school_id: Optional[str] = None
    role: str
    users: List[BulkImportUser]


@router.post("/bulk-import",
    summary="Bulk Import Users",
    description="Import a list of users under a specific role and school. Validates school presence and suspension."
)
async def bulk_import_users(
    request: BulkImportRequest,
    user=Depends(get_current_user)
):
    try:
        # Verify permission (only super_admin or admin can import)
        caller_role = user.get("role", "").lower()
        if caller_role != "super_admin" and request.school_id != user.get("school_id"):
            raise HTTPException(status_code=403, detail="Access denied: Cannot import users to another school")
            
        sb = get_supabase()
        
        # 1. Validation (suspension check)
        is_superadmin = request.role.lower() == "super_admin"
        if not is_superadmin:
            if not request.school_id:
                raise HTTPException(status_code=400, detail="School ID is required for non-superadmin users")
            school_res = await sb.table("schools").select("subscription_status").eq("id", request.school_id).maybe_single().aexecute()
            if not school_res.data:
                raise HTTPException(status_code=400, detail="The specified school does not exist")
            if school_res.data.get("subscription_status") == "suspended":
                raise HTTPException(status_code=400, detail="Cannot import users: The selected school/institute is suspended")
                
        success_count = 0
        errors = []
        
        for u in request.users:
            try:
                email = u.email.strip()
                # Basic validation
                if not email or "@" not in email:
                    errors.append({"email": email, "error": "Invalid email address format"})
                    continue
                if len(u.password) < 8:
                    errors.append({"email": email, "error": "Password must be at least 8 characters long"})
                    continue
                    
                # Check existing email in profiles
                existing = await sb.table("profiles").select("id").eq("email", email).maybe_single().aexecute()
                if existing.data:
                    errors.append({"email": email, "error": "Email already exists"})
                    continue
                    
                # Create in auth
                auth_response = await sb.auth().admin_create_user({
                    "email": email,
                    "password": u.password,
                    "app_metadata": {
                        "role": request.role
                    }
                })
                
                # Generate role-specific prefix
                role_lower = request.role.lower()
                if "student" in role_lower:
                    prefix = "STU"
                elif "teacher" in role_lower:
                    prefix = "TEA"
                elif "super" in role_lower:
                    prefix = "SUP"
                elif "admin" in role_lower:
                    prefix = "ADM"
                elif role_lower in ["principal", "director"]:
                    prefix = "MGT"
                else:
                    prefix = role_lower[:3].upper()
                generated_user_id = f"{prefix}-{uuid.uuid4().hex[:6].upper()}"
                
                # Insert profile
                await sb.table("profiles").insert({
                    "id": auth_response.user.id,
                    "school_id": request.school_id if not is_superadmin else None,
                    "user_id": generated_user_id,
                    "full_name": u.full_name,
                    "email": email,
                    "role": request.role,
                    "class": u.class_name,
                    "phone": u.phone,
                }).aexecute()
                
                success_count += 1
            except Exception as e:
                errors.append({"email": u.email, "error": str(e)})
                
        return {
            "success": True,
            "imported": success_count,
            "failed": len(errors),
            "errors": errors
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to process bulk import: {str(e)}")


# ──────────────────────────────────────────────────────────────
# BULK UPDATE AND DELETE ENDPOINTS
# ──────────────────────────────────────────────────────────────

class BulkUpdateRequest(BaseModel):
    user_ids: List[str]
    school_id: Optional[str] = None
    role: Optional[str] = None


class BulkDeleteRequest(BaseModel):
    user_ids: List[str]


@router.post("/bulk-update",
    summary="Bulk Update Users",
    description="Bulk update users' schools or roles. Restricts access to super_admin."
)
async def bulk_update_users(
    request: BulkUpdateRequest,
    user=Depends(get_current_user)
):
    try:
        caller_role = user.get("role", "").lower()
        if caller_role != "super_admin":
            raise HTTPException(status_code=403, detail="Access denied: Only super_admin can perform bulk updates")
            
        sb = get_supabase()
        
        # If school_id is provided, validate school is not suspended
        if request.school_id:
            school_res = await sb.table("schools").select("subscription_status").eq("id", request.school_id).maybe_single().aexecute()
            if not school_res.data:
                raise HTTPException(status_code=400, detail="The specified school/institute does not exist")
            if school_res.data.get("subscription_status") == "suspended":
                raise HTTPException(status_code=400, detail="Cannot update users: The selected school/institute is suspended")
                
        update_data = {}
        if request.school_id is not None:
            update_data["school_id"] = request.school_id if request.school_id != "" else None
        if request.role is not None:
            update_data["role"] = request.role
            
        if not update_data:
            return {"success": True, "updated": 0, "failed": 0, "errors": []}
            
        success_count = 0
        errors = []
        
        for uid in request.user_ids:
            try:
                # Update profiles table
                await sb.table("profiles").update(update_data).eq("id", uid).aexecute()
                
                # If role is updated, sync with auth user app_metadata using GoTrue admin endpoint
                if "role" in update_data:
                    admin_url = f"{settings.SUPABASE_URL}/auth/v1/admin/users/{uid}"
                    headers = {
                        "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
                        "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
                        "Content-Type": "application/json"
                    }
                    json_payload = {
                        "app_metadata": {
                            "role": request.role
                        }
                    }
                    async with httpx.AsyncClient() as client:
                        auth_res = await client.put(admin_url, headers=headers, json=json_payload, timeout=10.0)
                        if auth_res.status_code != 200:
                            logging.warning(f"Could not update app_metadata for user {uid} in auth")
                            
                success_count += 1
            except Exception as e:
                errors.append({"user_id": uid, "error": str(e)})
                
        return {
            "success": True,
            "updated": success_count,
            "failed": len(errors),
            "errors": errors
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to process bulk update: {str(e)}")


@router.post("/bulk-delete",
    summary="Bulk Delete Users",
    description="Bulk delete users from Supabase Auth and profiles. Restricts access to super_admin."
)
async def bulk_delete_users(
    request: BulkDeleteRequest,
    user=Depends(get_current_user)
):
    try:
        caller_role = user.get("role", "").lower()
        if caller_role != "super_admin":
            raise HTTPException(status_code=403, detail="Access denied: Only super_admin can perform bulk delete")
            
        sb = get_supabase()
        success_count = 0
        errors = []
        
        for uid in request.user_ids:
            try:
                # Delete from Supabase Auth
                admin_url = f"{settings.SUPABASE_URL}/auth/v1/admin/users/{uid}"
                headers = {
                    "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
                    "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
                }
                async with httpx.AsyncClient() as client:
                    auth_res = await client.delete(admin_url, headers=headers, timeout=10.0)
                    if auth_res.status_code not in [200, 204, 404]:
                        raise Exception(f"Auth deletion failed with status {auth_res.status_code}")
                        
                # Delete from profiles table
                await sb.table("profiles").delete().eq("id", uid).aexecute()
                
                success_count += 1
            except Exception as e:
                errors.append({"user_id": uid, "error": str(e)})
                
        return {
            "success": True,
            "deleted": success_count,
            "failed": len(errors),
            "errors": errors
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to process bulk delete: {str(e)}")






