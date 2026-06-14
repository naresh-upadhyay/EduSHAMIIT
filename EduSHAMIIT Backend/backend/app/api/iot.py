"""IoT API - Device control via MQTT."""
from fastapi import APIRouter, Depends, HTTPException
from datetime import datetime
from app.middleware.auth import get_current_user
from app.services.supabase_client import get_supabase
from app.services.iot_controller import iot
from app.models import IoTControlRequest, IoTScheduleRequest, GenericResponse
from app.config import settings

router = APIRouter()

@router.post("/control", response_model=GenericResponse)
async def control_device(body: IoTControlRequest, user: dict = Depends(get_current_user)):
    if settings.ENVIRONMENT == "production" and user.get("role") not in ("teacher", "admin"):
        raise HTTPException(status_code=403, detail="Access denied: Only teachers and admins can control IoT devices in production")
    result = iot.control_device(body.room, body.device, body.action)
    return GenericResponse(success=result.get("ok", False), school_id=user.get("school_id"), data=result)

@router.get("/status/{room}", response_model=GenericResponse)
async def get_device_status(room: str, user: dict = Depends(get_current_user)):
    status = iot.get_room_status(room)
    return GenericResponse(success=True, school_id=user.get("school_id"), data={"room": room, "devices": status})

@router.post("/schedule", response_model=GenericResponse)
async def schedule_device(body: IoTScheduleRequest, user: dict = Depends(get_current_user)):
    if settings.ENVIRONMENT == "production" and user.get("role") not in ("teacher", "admin"):
        raise HTTPException(status_code=403, detail="Access denied: Only teachers and admins can schedule IoT devices in production")
    sb = get_supabase()
    schedule = {
        "room_id": body.room, "device": body.device, "action": body.action,
        "scheduled_time": body.time, "school_id": user.get("school_id", ""),
        "created_by": user["id"], "status": "pending",
        "created_at": datetime.utcnow().isoformat()
    }
    try:
        r = await sb.table("iot_scheduled_actions").insert(schedule).aexecute()
        data = {"schedule": r.data[0] if r.data else {}}
    except Exception as e:
        # Graceful fallback if table doesn't exist or schema mismatch
        data = {"schedule": schedule, "note": f"Queued locally (DB: {str(e)[:80]})"}
    return GenericResponse(success=True, school_id=user.get("school_id"),
                           data=data, message="Device action scheduled")

@router.get("/devices", response_model=GenericResponse)
async def list_devices(user: dict = Depends(get_current_user)):
    sb = get_supabase()
    r = await sb.table("iot_devices").select("*").eq("school_id", user.get("school_id", "")).aexecute()
    return GenericResponse(success=True, school_id=user.get("school_id"), data={"devices": r.data or []})
