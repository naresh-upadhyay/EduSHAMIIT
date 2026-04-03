from fastapi import APIRouter, HTTPException
from app.services.supabase_client import get_supabase
from jose import jwt
from datetime import datetime, timedelta
import os
import uuid

router = APIRouter()

JWT_SECRET = os.getenv("SUPABASE_JWT_SECRET", os.getenv("JWT_SECRET", "eduSHAMIIT-jwt-secret-2026"))
JWT_ALGORITHM = "HS256"


@router.post("/login")
async def login(request: dict):
    """Authenticate user and return JWT token."""
    try:
        sb = get_supabase()
        email = request.get("email")
        password = request.get("password")

        if not email or not password:
            raise HTTPException(status_code=400, detail="Email and password required")

        auth_response = sb.auth().sign_in_with_password({
            "email": email,
            "password": password,
        })

        user_id = auth_response.user.id
        profile = sb.table("profiles").select("*").eq("id", user_id).single().execute()

        if not profile.data:
            raise HTTPException(status_code=404, detail="Profile not found")

        # profile.data is a list, get the first element
        p = profile.data[0] if isinstance(profile.data, list) else profile.data

        token = jwt.encode(
            {
                "sub": user_id,
                "school_id": p["school_id"],
                "role": p["role"],
                "class": p.get("class"),
                "exp": datetime.utcnow() + timedelta(days=7),
            },
            JWT_SECRET,
            algorithm=JWT_ALGORITHM,
        )

        return {
            "success": True,
            "school_id": p["school_id"],
            "data": {
                "token": token,
                "refresh_token": auth_response.session.refresh_token,
                "user": {
                    "id": user_id,
                    "full_name": p["full_name"],
                    "role": p["role"],
                    "class": p.get("class"),
                    "school_id": p["school_id"],
                    "avatar_url": p.get("avatar_url"),
                },
            },
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Login failed: {str(e)}")


@router.post("/register")
async def register(request: dict):
    """Register new user."""
    try:
        sb = get_supabase()

        auth_response = sb.auth().sign_up({
            "email": request["email"],
            "password": request["password"],
        })

        sb.table("profiles").insert({
            "id": auth_response.user.id,
            "school_id": request["school_id"],
            "user_id": f"STU-{uuid.uuid4().hex[:6].upper()}",
            "full_name": request["full_name"],
            "role": request["role"],
            "class": request.get("class_name"),
        }).execute()

        return {"success": True, "message": "Registration successful"}
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Registration failed: {str(e)}")


@router.post("/refresh")
async def refresh_token(request: dict):
    """Refresh JWT token."""
    try:
        sb = get_supabase()
        refresh_token = request.get("refresh_token")

        if not refresh_token:
            raise HTTPException(status_code=400, detail="Refresh token required")

        auth_response = sb.auth().refresh_session(refresh_token)
        profile = sb.table("profiles").select("*").eq("id", auth_response.user.id).single().execute()

        p = profile.data
        token = jwt.encode(
            {
                "sub": auth_response.user.id,
                "school_id": p["school_id"],
                "role": p["role"],
                "exp": datetime.utcnow() + timedelta(days=7),
            },
            JWT_SECRET,
            algorithm=JWT_ALGORITHM,
        )

        return {"success": True, "data": {"token": token}}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Token refresh failed: {str(e)}")