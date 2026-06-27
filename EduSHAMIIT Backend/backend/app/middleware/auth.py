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


def set_current_user_context(user: dict):
    """Set the current user context for tool access."""
    _current_user_context.set(user)


def get_current_user_id() -> str:
    """Get the current user ID from context (used by AI tools)."""
    return _current_user_context.get().get("id", "")


async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> dict:
    """Extract user context from JWT token with Redis caching."""
    token = credentials.credentials

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


async def require_school_id(user: dict = Depends(get_current_user)) -> str:
    """Dependency to extract and validate school_id from JWT."""
    school_id = user.get("school_id")
    if not school_id:
        raise HTTPException(status_code=400, detail="school_id required")
    return school_id


async def get_current_user_optional(request: Request) -> Optional[dict]:
    """Extract user from JWT token, returns None if not authenticated. Uses Redis cache."""
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        return None

    token = auth_header.split(" ")[1]

    # 1. Try Redis cache first
    cached = await get_cached_payload(token)
    if cached:
        return {
            "id": cached.get("sub"),
            "school_id": cached.get("school_id"),
            "role": cached.get("role"),
            "class": cached.get("class"),
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
require_admin = require_role("admin")

# Admin sub-roles
# student_admin: manages student-side data; admin can also access everything.
require_student_admin = require_any_role("admin", "student_admin")
# teacher_admin: manages teacher-side data; admin can also access everything.
require_teacher_admin = require_any_role("admin", "teacher_admin")
