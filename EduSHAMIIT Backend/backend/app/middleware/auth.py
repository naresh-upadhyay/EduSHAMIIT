from fastapi import HTTPException, Depends, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError
import os
from typing import Optional, Dict, Any, Callable
from functools import wraps

security = HTTPBearer()

# Global context for current user (used by tools)
_current_user_context: Dict[str, Any] = {}


def set_current_user_context(user: dict):
    """Set the current user context for tool access."""
    global _current_user_context
    _current_user_context = user


def get_current_user_id() -> str:
    """Get the current user ID from context (used by AI tools)."""
    return _current_user_context.get("id", "")


async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> dict:
    """Extract user context from JWT token."""
    try:
        jwt_secret = os.getenv("SUPABASE_JWT_SECRET", os.getenv("JWT_SECRET", "eduSHAMIIT-jwt-secret-2026"))
        payload = jwt.decode(
            credentials.credentials,
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
    """Extract user from JWT token, returns None if not authenticated."""
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        return None

    token = auth_header.split(" ")[1]
    try:
        jwt_secret = os.getenv("SUPABASE_JWT_SECRET", os.getenv("JWT_SECRET", "eduSHAMIIT-jwt-secret-2026"))
        payload = jwt.decode(
            token,
            jwt_secret,
            algorithms=["HS256"],
            options={"verify_aud": False}
        )
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


# Pre-configured role checkers for common roles
require_teacher = require_role("teacher")
require_student = require_role("student")
require_admin = require_role("admin")
