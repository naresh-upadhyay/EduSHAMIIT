from fastapi import HTTPException, Depends, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError
import os
from app.config import settings
import time
from typing import Optional, Dict, Any, Callable
from functools import wraps

security = HTTPBearer()

import contextvars

from app.middleware.jwt_cache import get_cached_payload, set_cached_payload

# ContextVar for current user context (thread/async-safe context for tools)
_current_user_context = contextvars.ContextVar("current_user_context", default={})
_request_host_context = contextvars.ContextVar("request_host_context", default="")


def set_current_user_context(user: dict):
    """Set the current user context for tool access."""
    _current_user_context.set(user)


def get_current_user_id() -> str:
    """Get the current user ID from context (used by AI tools)."""
    return _current_user_context.get().get("id", "")


def set_request_host(host: str):
    """Set the current request host context."""
    return _request_host_context.set(host)


def get_request_host() -> str:
    """Get the current request host from context."""
    return _request_host_context.get()


def reset_request_host(token):
    """Reset the request host context using token."""
    _request_host_context.reset(token)


def get_public_supabase_url(supabase_url: str) -> str:
    """Dynamically resolve the public Supabase storage base URL or rewrite a full URL."""
    if not supabase_url:
        return supabase_url
        
    # 1. Try request host context (live browser request host)
    host = get_request_host()
    if not host:
        # Try ENVIRONMENT PUBLIC_URL
        import os
        host = os.environ.get("PUBLIC_URL")
        
    if host:
        host = host.rstrip("/")
        # If it's a complete URL, replace the base domain part
        for prefix in ["http://kong:8000", "http://supabase-kong:8000", "http://127.0.0.1:8000", "http://localhost:8000"]:
            if supabase_url.startswith(prefix):
                return supabase_url.replace(prefix, host)
        # If it's just the base URL prefix itself being resolved
        if supabase_url in ["http://kong:8000", "http://supabase-kong:8000", "http://127.0.0.1:8000", "http://localhost:8000"]:
            return host
            
        return supabase_url

    # 3. Local dev fallback substitutions (if host is not resolved at all)
    url = supabase_url.rstrip("/")
    for prefix in ["http://kong:8000", "http://supabase-kong:8000"]:
        if url.startswith(prefix):
            return url.replace(prefix, "http://127.0.0.1:8000")
    if url in ["http://kong:8000", "http://supabase-kong:8000"]:
        return "http://127.0.0.1:8000"
    return url


async def get_current_user(request: Request) -> dict:
    """Extract user context from JWT token with Redis caching."""
    token = None
    auth_header = request.headers.get("Authorization")
    if auth_header and auth_header.startswith("Bearer "):
        token = auth_header.split(" ")[1]
    
    if not token:
        token = request.query_params.get("token")
        
    if not token:
        raise HTTPException(status_code=401, detail="Not authenticated")

    # 1. Try Redis cache first
    cached = await get_cached_payload(token)
    if cached:
        user = {
            "id": cached.get("sub"),
            "school_id": cached.get("school_id"),
            "role": cached.get("role"),
            "class": cached.get("class"),
            "email": cached.get("email"),
        }
        if user["id"]:
            try:
                from app.services.supabase_client import get_supabase
                sb = get_supabase()
                active_check = await sb.table("user_active_sessions").select("id").eq("token", token).maybe_single().aexecute()
                if not active_check.data:
                    # Auto-heal active session entry for valid active JWT token
                    await sb.table("user_active_sessions").upsert({
                        "user_id": user["id"],
                        "token": token,
                        "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
                    }).aexecute()
            except Exception:
                pass
            set_current_user_context(user)
            return user

    # 2. Cache miss — decode JWT
    try:
        jwt_secret = settings.SUPABASE_JWT_SECRET or settings.JWT_SECRET
        payload = jwt.decode(
            token,
            jwt_secret,
            algorithms=["HS256"],
            options={"verify_aud": False}
        )

        user = {
            "id": payload.get("sub"),
            "school_id": payload.get("school_id"),
            "role": payload.get("role"),
            "class": payload.get("class"),
            "email": payload.get("email"),
        }

        if not user["id"]:
            raise HTTPException(status_code=401, detail="Invalid token: missing user ID")

        try:
            from app.services.supabase_client import get_supabase
            sb = get_supabase()
            active_check = await sb.table("user_active_sessions").select("id").eq("token", token).maybe_single().aexecute()
            if not active_check.data:
                # Auto-heal active session entry for valid active JWT token
                await sb.table("user_active_sessions").upsert({
                    "user_id": user["id"],
                    "token": token,
                    "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
                }).aexecute()
        except Exception:
            pass

        # 3. Cache the decoded payload for next time
        exp = payload.get("exp", 0)
        if exp:
            await set_cached_payload(token, payload, exp)

        # Set context for tools
        set_current_user_context(user)

        return user

    except JWTError as e:
        raise HTTPException(status_code=401, detail=f"Invalid token: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Authentication failed: {str(e)}")


async def require_school_id(request: Request, user: dict = Depends(get_current_user)) -> str:
    """Dependency to extract and validate school_id from headers, query params, JWT, or database profiles."""
    # 1. Check Header or Query parameter first
    req_school_id = request.headers.get("X-School-Id") or request.query_params.get("school_id")
    if req_school_id and req_school_id.strip():
        return req_school_id.strip()

    # 2. Check JWT user context
    school_id = user.get("school_id")
    if school_id and str(school_id).strip():
        return str(school_id).strip()

    # 3. Dynamic lookup from profiles table
    user_id = user.get("id")
    if user_id:
        try:
            from app.services.supabase_client import get_supabase
            sb = get_supabase()
            p_res = await sb.table("profiles").select("school_id, role").eq("id", user_id).maybe_single().aexecute()
            if p_res.data and p_res.data.get("school_id"):
                resolved_id = str(p_res.data["school_id"])
                user["school_id"] = resolved_id
                return resolved_id
            
            # 4. Super Admin fallback: if super admin has no specific school_id, default to first active school
            user_role = (user.get("role") or (p_res.data.get("role") if p_res.data else "")).lower()
            if user_role in ["super_admin", "owner", "admin"]:
                first_school = await sb.table("schools").select("id").order("created_at").limit(1).maybe_single().aexecute()
                if first_school.data and first_school.data.get("id"):
                    resolved_id = str(first_school.data["id"])
                    user["school_id"] = resolved_id
                    return resolved_id
        except Exception:
            pass

    raise HTTPException(status_code=400, detail="school_id required")


async def get_current_user_optional(request: Request) -> Optional[dict]:
    """Extract user from JWT token, returns None if not authenticated. Uses Redis cache."""
    token = None
    auth_header = request.headers.get("Authorization")
    if auth_header and auth_header.startswith("Bearer "):
        token = auth_header.split(" ")[1]
    
    if not token:
        token = request.query_params.get("token")
        
    if not token:
        return None

    # 1. Try Redis cache first
    cached = await get_cached_payload(token)
    if cached:
        return {
            "id": cached.get("sub"),
            "school_id": cached.get("school_id"),
            "role": cached.get("role"),
            "class": cached.get("class"),
            "email": cached.get("email"),
        }
    # 2. Cache miss — decode JWT
    try:
        jwt_secret = settings.SUPABASE_JWT_SECRET or settings.JWT_SECRET
        payload = jwt.decode(
            token,
            jwt_secret,
            algorithms=["HS256"],
            options={"verify_aud": False}
        )
        # Cache this payload
        exp = payload.get("exp", 0)
        if exp:
            await set_cached_payload(token, payload, exp)
        return {
            "id": payload.get("sub"),
            "school_id": payload.get("school_id"),
            "role": payload.get("role"),
            "class": payload.get("class"),
            "email": payload.get("email"),
        }
    except JWTError:
        return None


def require_role(required_role: str):
    """Dependency factory to require a specific role for endpoint access."""
    async def role_checker(user: dict = Depends(get_current_user)) -> dict:
        user_role = user.get("role")
        if user_role != required_role:
            raise HTTPException(
                status_code=403,
                detail=f"Access denied. This endpoint requires {required_role} role."
            )
        return user
    return role_checker


def require_any_role(*allowed_roles: str):
    """Dependency factory to allow access if user has ANY of the listed roles.

    Example:
        require_any_role('admin', 'student_admin')  — admin OR student_admin can access.
    """
    async def role_checker(user: dict = Depends(get_current_user)) -> dict:
        user_role = user.get("role")
        if user_role not in allowed_roles:
            raise HTTPException(
                status_code=403,
                detail=(
                    f"Access denied. Required one of: {', '.join(allowed_roles)}. "
                    f"Your role: {user_role}"
                ),
            )
        return user
    return role_checker
# Pre-configured role checkers for common roles
require_teacher = require_role("teacher")
require_student = require_role("student")
require_admin = require_any_role(
    "admin", "super_admin", "director", "principal", "finance", "hr", 
    "transport", "library", "security", "sports", "support", "driver", 
    "hostel", "exam_ctrl"
)

# Admin sub-roles
# student_admin: manages student-side data; admin can also access everything.
require_student_admin = require_any_role(
    "admin", "student_admin", "super_admin", "director", "principal", "finance", 
    "hr", "transport", "library", "security", "sports", "support", "driver", 
    "hostel", "exam_ctrl"
)
# teacher_admin: manages teacher-side data; admin can also access everything.
require_teacher_admin = require_any_role(
    "admin", "teacher_admin", "super_admin", "director", "principal", "finance", 
    "hr", "transport", "library", "security", "sports", "support", "driver", 
    "hostel", "exam_ctrl"
)
