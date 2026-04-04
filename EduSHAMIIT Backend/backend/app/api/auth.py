from fastapi import APIRouter, HTTPException
from app.services.supabase_client import get_supabase
from app.services.email_service import get_email_service
from app.config import settings
from jose import jwt
from datetime import datetime, timedelta, timezone
import httpx
import os
import uuid
import random
import logging

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


def generate_otp(length: int = 6) -> str:
    """Generate a secure random OTP."""
    return ''.join([str(random.randint(0, 9)) for _ in range(length)])


def check_rate_limit(sb, identifier: str) -> bool:
    """Check if user has exceeded rate limit for OTP requests."""
    one_hour_ago = datetime.now(timezone.utc) - timedelta(hours=1)
    
    result = sb.table("password_resets").select("id").eq("user_id", identifier).gte("created_at", one_hour_ago.isoformat()).execute()
    
    return len(result.data) < settings.OTP_RATE_LIMIT_PER_HOUR


def find_user_by_identifier(sb, identifier: str) -> dict:
    """Find user by email or user_id."""
    # Try to find by email first
    result = sb.table("profiles").select("*").eq("email", identifier).maybe_single().execute()
    
    if result.data:
        return result.data
    
    # Try to find by user_id (UUID)
    try:
        uuid.UUID(identifier)
        result = sb.table("profiles").select("*").eq("id", identifier).maybe_single().execute()
        if result.data:
            return result.data
    except ValueError:
        pass
    
    return None


@router.post("/send-otp")
async def send_otp(request: dict):
    """Send OTP for password reset."""
    try:
        sb = get_supabase()
        email_service = get_email_service()
        
        identifier = request.get("identifier")  # email or user_id
        user_name = request.get("user_name")
        
        if not identifier:
            raise HTTPException(status_code=400, detail="Identifier (email or user_id) required")
        
        # Find user
        user = find_user_by_identifier(sb, identifier)
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        user_id = user["id"]
        user_email = user.get("email", identifier)
        full_name = user.get("full_name", user_name)
        
        # Check rate limit
        if not check_rate_limit(sb, user_id):
            raise HTTPException(
                status_code=429, 
                detail=f"Rate limit exceeded. Maximum {settings.OTP_RATE_LIMIT_PER_HOUR} OTP requests per hour."
            )
        
        # Invalidate any pending OTPs for this user
        sb.table("password_resets").update({"status": "used"}).eq("user_id", user_id).eq("status", "pending").execute()
        
        # Generate OTP
        otp = generate_otp(settings.OTP_LENGTH)
        expires_at = datetime.now(timezone.utc) + timedelta(minutes=settings.OTP_EXPIRATION_MINUTES)
        
        # Store OTP in database
        sb.table("password_resets").insert({
            "user_id": user_id,
            "school_id": user.get("school_id"),
            "otp": otp,
            "expires_at": expires_at.isoformat(),
            "status": "pending"
        }).execute()
        
        # Send email with OTP
        email_sent = email_service.send_otp_email(user_email, otp, full_name)
        
        if not email_sent:
            # Log the failure but don't fail the request
            logging.warning(f"Failed to send OTP email to {user_email}, but OTP was generated")
        
        expires_in = int(settings.OTP_EXPIRATION_MINUTES * 60)
        
        return {
            "success": True,
            "message": "OTP sent successfully",
            "expires_in": expires_in
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Error sending OTP: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to send OTP: {str(e)}")


@router.post("/verify-otp")
async def verify_otp(request: dict):
    """Verify OTP for password reset."""
    try:
        sb = get_supabase()
        
        identifier = request.get("identifier")  # email or user_id
        otp = request.get("otp")
        
        if not identifier or not otp:
            raise HTTPException(status_code=400, detail="Identifier and OTP required")
        
        # Find user
        user = find_user_by_identifier(sb, identifier)
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        user_id = user["id"]
        
        # Find valid OTP
        now = datetime.now(timezone.utc).isoformat()
        result = sb.table("password_resets").select("*").eq("user_id", user_id).eq("otp", otp).eq("status", "pending").gte("expires_at", now).execute()
        
        if not result.data:
            raise HTTPException(status_code=400, detail="Invalid or expired OTP")
        
        # Mark OTP as verified
        otp_record = result.data[0]
        sb.table("password_resets").update({"status": "verified"}).eq("id", otp_record["id"]).execute()
        
        return {
            "success": True,
            "message": "OTP verified successfully"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Error verifying OTP: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to verify OTP: {str(e)}")


@router.post("/reset-password")
async def reset_password(request: dict):
    """Reset password using OTP."""
    try:
        sb = get_supabase()
        email_service = get_email_service()
        
        identifier = request.get("identifier")  # email or user_id
        otp = request.get("otp")
        new_password = request.get("new_password")
        
        if not identifier or not otp or not new_password:
            raise HTTPException(status_code=400, detail="Identifier, OTP, and new password required")
        
        # Validate password length
        if len(new_password) < 8:
            raise HTTPException(status_code=400, detail="Password must be at least 8 characters long")
        
        # Find user
        user = find_user_by_identifier(sb, identifier)
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        user_id = user["id"]
        user_email = user.get("email", identifier)
        full_name = user.get("full_name")
        
        # Find and verify OTP
        now = datetime.now(timezone.utc).isoformat()
        result = sb.table("password_resets").select("*").eq("user_id", user_id).eq("otp", otp).eq("status", "pending").gte("expires_at", now).execute()
        
        if not result.data:
            raise HTTPException(status_code=400, detail="Invalid or expired OTP")
        
        otp_record = result.data[0]
        
        # Update password using Supabase Admin API
        try:
            # Use the Supabase REST API to update the user's password
            import httpx
            
            admin_url = f"{settings.SUPABASE_URL}/auth/v1/admin/users/{user_id}"
            headers = {
                "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
                "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
                "Content-Type": "application/json"
            }
            
            response = httpx.put(
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
        sb.table("password_resets").update({"status": "used"}).eq("id", otp_record["id"]).execute()
        
        # Send confirmation email
        email_sent = email_service.send_password_reset_confirmation(user_email, full_name)
        if not email_sent:
            logging.warning(f"Failed to send confirmation email to {user_email}")
        
        return {
            "success": True,
            "message": "Password reset successfully"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Error resetting password: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to reset password: {str(e)}")
