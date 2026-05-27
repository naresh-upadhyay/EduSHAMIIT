from fastapi import APIRouter, HTTPException, status
from fastapi.responses import JSONResponse
from pydantic import BaseModel, validator
from typing import Optional, Dict, Any
from app.services.supabase_client import get_supabase
from app.services.email_service import get_email_service
from app.config import settings
from app.models import (
    LoginRequest, RegisterRequest, RefreshRequest, SendOtpRequest, 
    VerifyOtpRequest, ResetPasswordRequest, LoginResponse, RegisterResponse,
    RefreshResponse, OtpResponse, VerifyOtpResponse, ResetPasswordResponse,
    ErrorResponse
)
from jose import jwt
from datetime import datetime, timedelta, timezone
import httpx
import os
import uuid
import random
import logging
import re

router = APIRouter()

JWT_SECRET = os.getenv("SUPABASE_JWT_SECRET", os.getenv("JWT_SECRET", "eduSHAMIIT-jwt-secret-2026"))
JWT_ALGORITHM = "HS256"


def validate_email(email: str) -> str:
    """Validate email format"""
    email_regex = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    if not re.match(email_regex, email):
        raise ValueError("Invalid email format")
    return email


def validate_password(password: str) -> str:
    """Validate password strength"""
    if len(password) < 8:
        raise ValueError("Password must be at least 8 characters long")
    if not re.search(r'[A-Z]', password):
        raise ValueError("Password must contain at least one uppercase letter")
    if not re.search(r'[a-z]', password):
        raise ValueError("Password must contain at least one lowercase letter")
    if not re.search(r'\d', password):
        raise ValueError("Password must contain at least one number")
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
async def login(request: LoginRequest):
    """Authenticate user and return JWT token."""
    try:
        sb = get_supabase()
        email = request.email
        password = request.password

        auth_response = await sb.auth().sign_in_with_password({
            "email": email,
            "password": password,
        })

        user_id = auth_response.user.id
        profile = await sb.table("profiles").select("*").eq("id", user_id).maybe_single().aexecute()

        if not profile.data:
            raise HTTPException(status_code=404, detail="Profile not found")

        # profile.data is a dict (due to maybe_single in aexecute)
        p = profile.data

        # Enforce role matching if role is requested
        if request.role and p["role"].lower() != request.role.lower():
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

        auth_response = await sb.auth().sign_up({
            "email": request.email,
            "password": request.password,
        })

        await sb.table("profiles").insert({
            "id": auth_response.user.id,
            "school_id": request.school_id,
            "user_id": f"STU-{uuid.uuid4().hex[:6].upper()}",
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
        user_email = user.get("email", identifier)
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
            
        # 3. Delete from profiles table
        # We delete by the record's primary key (id) for precision
        await sb.table("profiles").delete().eq("id", auth_uuid).aexecute()
        
        return {
            "success": True,
            "message": f"User {identifier} deleted successfully. Auth record removed: {auth_deleted}."
        }
    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Error deleting user {identifier}: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to delete user: {str(e)}")
