"""
Vehicle Live Dashboard API
Provides real-time vehicle tracking, trip management, and alert endpoints.
"""
from fastapi import APIRouter, Depends, HTTPException, Query
from typing import Optional
from datetime import datetime, date
import uuid

from app.middleware.auth import get_current_user, require_any_role
from app.services.supabase_client import get_supabase

router = APIRouter()

require_transport_admin = require_any_role("super_admin", "director", "transport_admin", "admin")


# ──────────────────────────────────────────────
# Dashboard Summary
# ──────────────────────────────────────────────

@router.get("/dashboard/summary")
async def vehicle_dashboard_summary(
    school_id: Optional[str] = Query(None),
    user=Depends(require_transport_admin),
):
    """Returns aggregated KPIs for the Vehicle Live Dashboard."""
    sb = get_supabase()
    try:
        res = await sb.rpc("get_vehicle_dashboard_summary", {
            "p_school_id": school_id
        }).aexecute()
        summary = res.data if res.data else {}
        if isinstance(summary, list) and len(summary) > 0:
            summary = summary[0]
    except Exception as e:
        # Fallback: compute manually
        summary = await _compute_summary_manually(sb, school_id)

    return {"success": True, "data": summary}


@router.post("/diagnostics")
async def save_diagnostics(payload: dict):
    import json
    print("FRONTEND DIAGNOSTICS:", payload, flush=True)
    with open("diagnostics.txt", "a") as f:
        f.write(json.dumps(payload) + "\n")
    return {"success": True}



async def _compute_summary_manually(sb, school_id: Optional[str]):
    q = sb.table("bus_routes").select("live_status,students_on_board")
    if school_id:
        q = q.eq("school_id", school_id)
    routes = (await q.aexecute()).data or []

    counts = {
        "total_vehicles": len(routes),
        "on_route": 0, "at_school": 0, "returning": 0,
        "delayed": 0, "offline": 0, "idle": 0,
        "students_on_board": 0,
        "active_trips": 0, "completed_trips_today": 0,
        "critical_alerts": 0, "warning_alerts": 0,
    }
    for r in routes:
        status = r.get("live_status", "offline")
        if status in counts:
            counts[status] += 1
        counts["students_on_board"] += r.get("students_on_board", 0) or 0

    # Trips today
    tq = sb.table("vehicle_trips").select("status")
    if school_id:
        tq = tq.eq("school_id", school_id)
    trips = (await tq.aexecute()).data or []
    for t in trips:
        if t.get("status") == "in_progress":
            counts["active_trips"] += 1
        if t.get("status") == "completed":
            counts["completed_trips_today"] += 1

    # Alerts
    aq = sb.table("vehicle_live_alerts").select("severity").eq("is_resolved", False)
    if school_id:
        aq = aq.eq("school_id", school_id)
    alerts = (await aq.aexecute()).data or []
    for a in alerts:
        if a.get("severity") == "critical":
            counts["critical_alerts"] += 1
        elif a.get("severity") == "warning":
            counts["warning_alerts"] += 1

    return counts


# ──────────────────────────────────────────────
# Vehicles (Bus Routes enhanced)
# ──────────────────────────────────────────────

@router.get("/vehicles")
async def list_vehicles(
    school_id: Optional[str] = Query(None),
    live_status: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    user=Depends(require_transport_admin),
):
    """List all vehicles with live tracking data and latest GPS location."""
    sb = get_supabase()
    q = sb.table("bus_routes").select(
        "*, bus_stops(id,stop_name,stop_order)"
    )
    if school_id:
        q = q.eq("school_id", school_id)
    if live_status:
        q = q.eq("live_status", live_status)

    routes_res = await q.aexecute()
    vehicles = routes_res.data or []

    if search:
        s = search.lower()
        vehicles = [
            v for v in vehicles
            if s in (v.get("route_name") or "").lower()
            or s in (v.get("bus_number") or "").lower()
            or s in (v.get("driver_name") or "").lower()
            or s in (v.get("registration_no") or "").lower()
        ]

    # Attach latest GPS location for each vehicle
    route_ids = [v["id"] for v in vehicles]
    locations_map: dict = {}
    if route_ids:
        # Fetch latest location per route
        locs_res = await sb.table("bus_locations").select("*").in_(
            "route_id", route_ids
        ).order("recorded_at", ascending=False).limit(len(route_ids) * 2).aexecute()
        seen = set()
        for loc in (locs_res.data or []):
            rid = loc.get("route_id")
            if rid not in seen:
                locations_map[rid] = loc
                seen.add(rid)

    for v in vehicles:
        v["latest_location"] = locations_map.get(v["id"])

    total = len(vehicles)
    start = (page - 1) * page_size
    paginated = vehicles[start: start + page_size]

    return {
        "success": True,
        "data": {
            "vehicles": paginated,
            "total": total,
            "page": page,
            "page_size": page_size,
            "total_pages": max(1, (total + page_size - 1) // page_size),
        },
    }


@router.get("/vehicles/{vehicle_id}")
async def get_vehicle(vehicle_id: str, user=Depends(require_transport_admin)):
    sb = get_supabase()
    v = (await sb.table("bus_routes").select("*, bus_stops(*)").eq("id", vehicle_id).single().aexecute()).data
    if not v:
        raise HTTPException(status_code=404, detail="Vehicle not found")

    locs = (await sb.table("bus_locations").select("*").eq(
        "route_id", vehicle_id
    ).order("recorded_at", ascending=False).limit(20).aexecute()).data or []

    trips = (await sb.table("vehicle_trips").select("*").eq(
        "route_id", vehicle_id
    ).order("created_at", ascending=False).limit(10).aexecute()).data or []

    alerts = (await sb.table("vehicle_live_alerts").select("*").eq(
        "route_id", vehicle_id
    ).eq("is_resolved", False).order("created_at", ascending=False).aexecute()).data or []

    return {
        "success": True,
        "data": {
            "vehicle": v,
            "location_history": locs,
            "recent_trips": trips,
            "active_alerts": alerts,
        },
    }


@router.put("/vehicles/{vehicle_id}")
async def update_vehicle(vehicle_id: str, payload: dict, user=Depends(require_transport_admin)):
    """Update vehicle metadata and live status."""
    sb = get_supabase()
    allowed = {
        "route_name", "bus_number", "registration_no", "driver_name", "driver_phone",
        "driver_license_no", "assistant_name", "assistant_phone", "vehicle_type",
        "model", "year_of_mfg", "fuel_type", "total_capacity", "last_service_date",
        "insurance_expiry", "fitness_expiry", "gps_device_id", "live_status",
        "delay_minutes", "students_on_board", "status", "notes",
        "fuel_level_pct", "speed_kmh", "next_stop", "next_stop_eta",
        "chassis_no", "engine_no", "color", "insurance_status", "fitness_status",
        "pollution_status", "pollution_expiry", "puc_no", "permit_no", "permit_expiry"
    }
    data = {k: v for k, v in payload.items() if k in allowed}
    if not data:
        raise HTTPException(status_code=400, detail="No valid fields provided")
    data["updated_at"] = datetime.utcnow().isoformat()
    await sb.table("bus_routes").update(data).eq("id", vehicle_id).aexecute()
    return {"success": True, "message": "Vehicle updated"}


@router.post("/vehicles")
async def create_vehicle(payload: dict, user=Depends(require_transport_admin)):
    """Create a new vehicle."""
    sb = get_supabase()
    allowed = {
        "school_id", "route_name", "bus_number", "registration_no", "driver_name", "driver_phone",
        "driver_license_no", "assistant_name", "assistant_phone", "vehicle_type",
        "model", "year_of_mfg", "fuel_type", "total_capacity", "last_service_date",
        "insurance_expiry", "fitness_expiry", "gps_device_id", "live_status",
        "delay_minutes", "students_on_board", "status", "notes",
        "fuel_level_pct", "speed_kmh", "next_stop", "next_stop_eta",
        "chassis_no", "engine_no", "color", "insurance_status", "fitness_status",
        "pollution_status", "pollution_expiry", "puc_no", "permit_no", "permit_expiry"
    }
    data = {k: v for k, v in payload.items() if k in allowed}
    data["id"] = str(uuid.uuid4())
    if not data.get("school_id"):
        data["school_id"] = "e1f11111-1111-1111-1111-111111111111" # default to Greenfield Public School
    res = await sb.table("bus_routes").insert(data).aexecute()
    return {"success": True, "data": res.data[0] if res.data else data}


@router.delete("/vehicles/{vehicle_id}")
async def delete_vehicle(vehicle_id: str, user=Depends(require_transport_admin)):
    """Delete a vehicle."""
    sb = get_supabase()
    # Delete child constraints first
    await sb.table("student_transport").delete().eq("route_id", vehicle_id).aexecute()
    await sb.table("vehicle_documents").delete().eq("vehicle_id", vehicle_id).aexecute()
    await sb.table("vehicle_insurance_fitness").delete().eq("vehicle_id", vehicle_id).aexecute()
    await sb.table("gps_devices").delete().eq("vehicle_id", vehicle_id).aexecute()
    await sb.table("bus_locations").delete().eq("route_id", vehicle_id).aexecute()
    await sb.table("vehicle_trips").delete().eq("route_id", vehicle_id).aexecute()
    await sb.table("vehicle_live_alerts").delete().eq("route_id", vehicle_id).aexecute()
    
    await sb.table("bus_routes").delete().eq("id", vehicle_id).aexecute()
    return {"success": True, "message": "Vehicle deleted"}



@router.post("/vehicles/{vehicle_id}/location")
async def update_vehicle_location(vehicle_id: str, payload: dict, user=Depends(require_transport_admin)):
    """Push a new GPS location point for a vehicle."""
    sb = get_supabase()
    if not payload.get("latitude") or not payload.get("longitude"):
        raise HTTPException(status_code=400, detail="latitude and longitude required")

    route = (await sb.table("bus_routes").select("school_id").eq("id", vehicle_id).single().aexecute()).data
    if not route:
        raise HTTPException(status_code=404, detail="Vehicle not found")

    data = {
        "id": str(uuid.uuid4()),
        "school_id": route["school_id"],
        "route_id": vehicle_id,
        "latitude": payload["latitude"],
        "longitude": payload["longitude"],
        "speed": payload.get("speed"),
        "heading": payload.get("heading"),
        "eta_minutes": payload.get("eta_minutes"),
        "accuracy_m": payload.get("accuracy_m"),
        "engine_on": payload.get("engine_on", True),
        "odometer_km": payload.get("odometer_km"),
        "altitude_m": payload.get("altitude_m"),
        "signal_strength": payload.get("signal_strength", "good"),
        "recorded_at": datetime.utcnow().isoformat(),
    }
    await sb.table("bus_locations").insert(data).aexecute()

    # Update live_status if passed
    if payload.get("live_status"):
        await sb.table("bus_routes").update({
            "live_status": payload["live_status"],
            "students_on_board": payload.get("students_on_board"),
            "delay_minutes": payload.get("delay_minutes", 0),
            "updated_at": datetime.utcnow().isoformat(),
        }).eq("id", vehicle_id).aexecute()

    return {"success": True, "message": "Location updated"}


# ──────────────────────────────────────────────
# Trips
# ──────────────────────────────────────────────

@router.get("/trips")
async def list_trips(
    school_id: Optional[str] = Query(None),
    route_id: Optional[str] = Query(None),
    trip_date: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    user=Depends(require_transport_admin),
):
    sb = get_supabase()
    q = sb.table("vehicle_trips").select(
        "*, bus_routes(route_name, bus_number, driver_name, live_status, registration_no)"
    ).order("created_at", ascending=False)

    if school_id:
        q = q.eq("school_id", school_id)
    if route_id:
        q = q.eq("route_id", route_id)
    if status:
        q = q.eq("status", status)

    trips = (await q.aexecute()).data or []

    if trip_date:
        try:
            d = datetime.strptime(trip_date, "%Y-%m-%d").date()
            trips = [
                t for t in trips
                if t.get("created_at") and
                datetime.fromisoformat(t["created_at"].replace("Z", "+00:00")).date() == d
            ]
        except Exception:
            pass

    total = len(trips)
    start = (page - 1) * page_size
    paginated = trips[start: start + page_size]
    return {
        "success": True,
        "data": {
            "trips": paginated,
            "total": total,
            "page": page,
            "page_size": page_size,
            "total_pages": max(1, (total + page_size - 1) // page_size),
        },
    }


@router.post("/trips")
async def create_trip(payload: dict, user=Depends(require_transport_admin)):
    sb = get_supabase()
    if not payload.get("route_id"):
        raise HTTPException(status_code=400, detail="route_id required")

    route = (await sb.table("bus_routes").select("school_id").eq(
        "id", payload["route_id"]
    ).single().aexecute()).data
    if not route:
        raise HTTPException(status_code=404, detail="Vehicle not found")

    data = {
        "id": str(uuid.uuid4()),
        "school_id": payload.get("school_id") or route["school_id"],
        "route_id": payload["route_id"],
        "trip_type": payload.get("trip_type", "morning"),
        "status": payload.get("status", "scheduled"),
        "scheduled_start": payload.get("scheduled_start"),
        "students_count": payload.get("students_count", 0),
        "notes": payload.get("notes"),
    }
    res = await sb.table("vehicle_trips").insert(data).aexecute()
    return {"success": True, "data": res.data[0] if res.data else data}


@router.put("/trips/{trip_id}")
async def update_trip(trip_id: str, payload: dict, user=Depends(require_transport_admin)):
    sb = get_supabase()
    allowed = {
        "status", "trip_type", "scheduled_start", "actual_start", "actual_end",
        "students_count", "distance_km", "delay_minutes", "incident_count", "notes",
    }
    data = {k: v for k, v in payload.items() if k in allowed}
    if not data:
        raise HTTPException(status_code=400, detail="No valid fields provided")
    await sb.table("vehicle_trips").update(data).eq("id", trip_id).aexecute()
    return {"success": True, "message": "Trip updated"}


@router.delete("/trips/{trip_id}")
async def delete_trip(trip_id: str, user=Depends(require_transport_admin)):
    sb = get_supabase()
    await sb.table("vehicle_trips").delete().eq("id", trip_id).aexecute()
    return {"success": True, "message": "Trip deleted"}


# ──────────────────────────────────────────────
# Alerts
# ──────────────────────────────────────────────

@router.get("/alerts")
async def list_alerts(
    school_id: Optional[str] = Query(None),
    route_id: Optional[str] = Query(None),
    severity: Optional[str] = Query(None),
    is_resolved: Optional[bool] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    user=Depends(require_transport_admin),
):
    sb = get_supabase()
    q = sb.table("vehicle_live_alerts").select(
        "*, bus_routes(route_name,bus_number,driver_name)"
    ).order("created_at", ascending=False)

    if school_id:
        q = q.eq("school_id", school_id)
    if route_id:
        q = q.eq("route_id", route_id)
    if severity:
        q = q.eq("severity", severity)
    if is_resolved is not None:
        q = q.eq("is_resolved", is_resolved)

    alerts = (await q.aexecute()).data or []
    total = len(alerts)
    start = (page - 1) * page_size
    paginated = alerts[start: start + page_size]
    return {
        "success": True,
        "data": {
            "alerts": paginated,
            "total": total,
            "page": page,
            "page_size": page_size,
            "total_pages": max(1, (total + page_size - 1) // page_size),
        },
    }


@router.post("/alerts")
async def create_alert(payload: dict, user=Depends(require_transport_admin)):
    sb = get_supabase()
    if not payload.get("title") or not payload.get("alert_type"):
        raise HTTPException(status_code=400, detail="title and alert_type required")

    school_id = payload.get("school_id")
    if not school_id and payload.get("route_id"):
        route = (await sb.table("bus_routes").select("school_id").eq(
            "id", payload["route_id"]
        ).single().aexecute()).data
        school_id = route["school_id"] if route else None

    data = {
        "id": str(uuid.uuid4()),
        "school_id": school_id,
        "route_id": payload.get("route_id"),
        "trip_id": payload.get("trip_id"),
        "alert_type": payload["alert_type"],
        "severity": payload.get("severity", "info"),
        "title": payload["title"],
        "message": payload.get("message"),
        "latitude": payload.get("latitude"),
        "longitude": payload.get("longitude"),
        "is_resolved": False,
    }
    res = await sb.table("vehicle_live_alerts").insert(data).aexecute()
    return {"success": True, "data": res.data[0] if res.data else data}


@router.put("/alerts/{alert_id}/resolve")
async def resolve_alert(alert_id: str, payload: dict, user=Depends(require_transport_admin)):
    sb = get_supabase()
    await sb.table("vehicle_live_alerts").update({
        "is_resolved": True,
        "resolved_at": datetime.utcnow().isoformat(),
        "resolved_by": payload.get("resolved_by", "System"),
    }).eq("id", alert_id).aexecute()
    return {"success": True, "message": "Alert resolved"}


@router.delete("/alerts/{alert_id}")
async def delete_alert(alert_id: str, user=Depends(require_transport_admin)):
    sb = get_supabase()
    await sb.table("vehicle_live_alerts").delete().eq("id", alert_id).aexecute()
    return {"success": True, "message": "Alert deleted"}


# ──────────────────────────────────────────────
# Live Location History
# ──────────────────────────────────────────────

@router.get("/vehicles/{vehicle_id}/locations")
async def vehicle_location_history(
    vehicle_id: str,
    limit: int = Query(50, ge=1, le=200),
    user=Depends(require_transport_admin),
):
    sb = get_supabase()
    locs = (await sb.table("bus_locations").select("*").eq(
        "route_id", vehicle_id
    ).order("recorded_at", ascending=False).limit(limit).aexecute()).data or []
    return {"success": True, "data": locs}


# ──────────────────────────────────────────────
# Top Delayed Vehicles
# ──────────────────────────────────────────────

@router.get("/top-delayed")
async def top_delayed_vehicles(
    school_id: Optional[str] = Query(None),
    limit: int = Query(5, ge=1, le=20),
    user=Depends(require_transport_admin),
):
    sb = get_supabase()
    q = sb.table("bus_routes").select(
        "id,route_name,bus_number,driver_name,delay_minutes,students_on_board,live_status,registration_no"
    ).order("delay_minutes", ascending=False).limit(limit)
    if school_id:
        q = q.eq("school_id", school_id)
    vehicles = (await q.aexecute()).data or []
    return {"success": True, "data": vehicles}


# ──────────────────────────────────────────────
# Vehicle Categories
# ──────────────────────────────────────────────

@router.get("/categories")
async def list_categories(
    school_id: Optional[str] = Query(None),
    user=Depends(require_transport_admin),
):
    sb = get_supabase()
    q = sb.table("vehicle_categories").select("*").order("name")
    if school_id:
        q = q.eq("school_id", school_id)
    res = await q.aexecute()
    return {"success": True, "data": res.data or []}

@router.post("/categories")
async def create_category(payload: dict, user=Depends(require_transport_admin)):
    sb = get_supabase()
    data = {
        "id": str(uuid.uuid4()),
        "school_id": payload.get("school_id") or "e1f11111-1111-1111-1111-111111111111",
        "name": payload["name"],
        "description": payload.get("description"),
        "capacity": payload.get("capacity", 52),
        "fuel_type": payload.get("fuel_type", "Diesel"),
        "category_code": payload.get("category_code"),
        "transmission": payload.get("transmission", "Manual"),
        "luggage_capacity": payload.get("luggage_capacity", "500 L"),
        "status": payload.get("status", "Active"),
    }
    res = await sb.table("vehicle_categories").insert(data).aexecute()
    return {"success": True, "data": res.data[0] if res.data else data}

@router.put("/categories/{cat_id}")
async def update_category(cat_id: str, payload: dict, user=Depends(require_transport_admin)):
    sb = get_supabase()
    allowed = {"name", "description", "capacity", "fuel_type", "category_code", "transmission", "luggage_capacity", "status"}
    data = {k: v for k, v in payload.items() if k in allowed}
    data["updated_at"] = datetime.utcnow().isoformat()
    await sb.table("vehicle_categories").update(data).eq("id", cat_id).aexecute()
    return {"success": True, "message": "Category updated"}

@router.delete("/categories/{cat_id}")
async def delete_category(cat_id: str, user=Depends(require_transport_admin)):
    sb = get_supabase()
    # Nullify category references on bus routes or set defaults before delete
    await sb.table("vehicle_categories").delete().eq("id", cat_id).aexecute()
    return {"success": True, "message": "Category deleted"}


# ──────────────────────────────────────────────
# Vehicle Documents
# ──────────────────────────────────────────────

from fastapi import UploadFile, File

@router.post("/documents/upload")
async def upload_vehicle_document_file(
    file: UploadFile = File(...),
    user=Depends(require_transport_admin),
):
    """Upload a vehicle document file to Supabase Storage documents bucket and return its public URL."""
    from app.config import settings
    import httpx
    
    file_bytes = await file.read()
    if len(file_bytes) == 0:
        raise HTTPException(status_code=400, detail="Empty file")
    if len(file_bytes) > 20 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="File too large (max 20 MB)")

    safe_name = file.filename or "document"
    extension = safe_name.rsplit(".", 1)[-1].lower() if "." in safe_name else "bin"
    doc_id = str(uuid.uuid4())

    storage_path = f"vehicle/{doc_id}.{extension}"
    supabase_url = settings.SUPABASE_URL.rstrip("/")
    storage_url = f"{supabase_url}/storage/v1/object/documents/{storage_path}"
    headers = {
        "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
        "Content-Type": file.content_type or "application/octet-stream",
        "x-upsert": "true",
    }

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            upload_response = await client.post(storage_url, headers=headers, content=file_bytes)
        
        if upload_response.status_code not in (200, 201):
            raise HTTPException(
                status_code=500,
                detail=f"Storage upload failed: {upload_response.text}"
            )
    except Exception as e:
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(status_code=500, detail=f"Storage upload request failed: {str(e)}")

    from app.middleware.auth import get_public_supabase_url
    public_url_base = get_public_supabase_url(supabase_url)
    file_url = f"{public_url_base}/storage/v1/object/public/documents/{storage_path}"

    return {"success": True, "data": {"url": file_url}}


@router.get("/documents")
async def list_documents(
    school_id: Optional[str] = Query(None),
    vehicle_id: Optional[str] = Query(None),
    user=Depends(require_transport_admin),
):
    sb = get_supabase()
    q = sb.table("vehicle_documents").select("*, bus_routes(route_name, bus_number, registration_no, vehicle_type)")
    if school_id:
        q = q.eq("school_id", school_id)
    if vehicle_id:
        q = q.eq("vehicle_id", vehicle_id)
    res = await q.aexecute()
    return {"success": True, "data": res.data or []}

@router.post("/documents")
async def create_document(payload: dict, user=Depends(require_transport_admin)):
    sb = get_supabase()
    data = {
        "id": str(uuid.uuid4()),
        "school_id": payload.get("school_id") or "11111111-1111-1111-1111-111111111111",
        "vehicle_id": payload["vehicle_id"],
        "document_type": payload["document_type"],
        "document_name": payload.get("document_name"),
        "document_no": payload["document_no"],
        "issued_date": payload.get("issued_date"),
        "expiry_date": payload["expiry_date"],
        "status": payload.get("status", "Valid"),
        "document_url": payload.get("document_url"),
        "remarks": payload.get("remarks"),
        "policy_no": payload.get("policy_no"),
        "provider": payload.get("provider"),
        "uploaded_by": payload.get("uploaded_by", "Transport Manager"),
        "uploaded_on": datetime.utcnow().isoformat(),
    }
    res = await sb.table("vehicle_documents").insert(data).aexecute()
    return {"success": True, "data": res.data[0] if res.data else data}

@router.put("/documents/{doc_id}")
async def update_document(doc_id: str, payload: dict, user=Depends(require_transport_admin)):
    sb = get_supabase()
    allowed = {
        "document_type", "document_name", "document_no", "issued_date", 
        "expiry_date", "status", "document_url", "remarks", 
        "policy_no", "provider", "uploaded_by"
    }
    data = {k: v for k, v in payload.items() if k in allowed}
    data["updated_at"] = datetime.utcnow().isoformat()
    await sb.table("vehicle_documents").update(data).eq("id", doc_id).aexecute()
    return {"success": True, "message": "Document updated"}

@router.delete("/documents/{doc_id}")
async def delete_document(doc_id: str, user=Depends(require_transport_admin)):
    sb = get_supabase()
    await sb.table("vehicle_documents").delete().eq("id", doc_id).aexecute()
    return {"success": True, "message": "Document deleted"}


# ──────────────────────────────────────────────
# Vehicle Insurance & Fitness
# ──────────────────────────────────────────────

@router.get("/insurance-fitness")
async def list_insurance_fitness(
    school_id: Optional[str] = Query(None),
    vehicle_id: Optional[str] = Query(None),
    user=Depends(require_transport_admin),
):
    sb = get_supabase()
    q = sb.table("vehicle_insurance_fitness").select("*, bus_routes(route_name, bus_number, registration_no)")
    if school_id:
        q = q.eq("school_id", school_id)
    if vehicle_id:
        q = q.eq("vehicle_id", vehicle_id)
    res = await q.aexecute()
    return {"success": True, "data": res.data or []}

@router.post("/insurance-fitness")
async def create_insurance_fitness(payload: dict, user=Depends(require_transport_admin)):
    sb = get_supabase()
    data = {
        "id": str(uuid.uuid4()),
        "school_id": payload.get("school_id"),
        "vehicle_id": payload["vehicle_id"],
        "policy_no": payload.get("policy_no"),
        "provider": payload.get("provider"),
        "insurance_start": payload.get("insurance_start"),
        "insurance_expiry": payload.get("insurance_expiry"),
        "insurance_status": payload.get("insurance_status", "Valid"),
        "fitness_cert_no": payload.get("fitness_cert_no"),
        "fitness_expiry": payload.get("fitness_expiry"),
        "fitness_status": payload.get("fitness_status", "Valid"),
        "pollution_cert_no": payload.get("pollution_cert_no"),
        "pollution_expiry": payload.get("pollution_expiry"),
        "pollution_status": payload.get("pollution_status", "Valid"),
        "puc_no": payload.get("puc_no"),
        "permit_no": payload.get("permit_no"),
        "permit_expiry": payload.get("permit_expiry"),
    }
    res = await sb.table("vehicle_insurance_fitness").insert(data).aexecute()
    return {"success": True, "data": res.data[0] if res.data else data}

@router.put("/insurance-fitness/{inf_id}")
async def update_insurance_fitness(inf_id: str, payload: dict, user=Depends(require_transport_admin)):
    sb = get_supabase()
    allowed = {
        "policy_no", "provider", "insurance_start", "insurance_expiry", "insurance_status",
        "fitness_cert_no", "fitness_expiry", "fitness_status", "pollution_cert_no",
        "pollution_expiry", "pollution_status", "puc_no", "permit_no", "permit_expiry"
    }
    data = {k: v for k, v in payload.items() if k in allowed}
    data["updated_at"] = datetime.utcnow().isoformat()
    await sb.table("vehicle_insurance_fitness").update(data).eq("id", inf_id).aexecute()
    return {"success": True, "message": "Insurance/Fitness details updated"}

@router.delete("/insurance-fitness/{inf_id}")
async def delete_insurance_fitness(inf_id: str, user=Depends(require_transport_admin)):
    sb = get_supabase()
    await sb.table("vehicle_insurance_fitness").delete().eq("id", inf_id).aexecute()
    return {"success": True, "message": "Insurance/Fitness details deleted"}


# ──────────────────────────────────────────────
# GPS Devices
# ──────────────────────────────────────────────

@router.get("/gps-devices")
async def list_gps_devices(
    school_id: Optional[str] = Query(None),
    vehicle_id: Optional[str] = Query(None),
    user=Depends(require_transport_admin),
):
    sb = get_supabase()
    q = sb.table("gps_devices").select("*, bus_routes(route_name, bus_number, registration_no, vehicle_type)")
    if school_id:
        q = q.eq("school_id", school_id)
    if vehicle_id:
        q = q.eq("vehicle_id", vehicle_id)
    res = await q.aexecute()
    return {"success": True, "data": res.data or []}

@router.post("/gps-devices")
async def create_gps_device(payload: dict, user=Depends(require_transport_admin)):
    sb = get_supabase()
    data = {
        "id": str(uuid.uuid4()),
        "school_id": payload.get("school_id"),
        "device_id": payload["device_id"],
        "model": payload.get("model"),
        "sim_no": payload.get("sim_no"),
        "operator": payload.get("operator"),
        "status": payload.get("status", "Active"),
        "installation_date": payload.get("installation_date"),
        "vehicle_id": payload.get("vehicle_id"),
        "imei_no": payload.get("imei_no"),
        "battery_level": payload.get("battery_level", 100),
        "signal_strength_pct": payload.get("signal_strength_pct", 100),
        "firmware_version": payload.get("firmware_version", "GTO6N_V7.2.1"),
        "expiry_date": payload.get("expiry_date"),
        "installed_by": payload.get("installed_by", "Transport Manager"),
        "current_location": payload.get("current_location", "Sector 62, Noida, UP"),
    }
    res = await sb.table("gps_devices").insert(data).aexecute()
    return {"success": True, "data": res.data[0] if res.data else data}

@router.put("/gps-devices/{gps_id}")
async def update_gps_device(gps_id: str, payload: dict, user=Depends(require_transport_admin)):
    sb = get_supabase()
    allowed = {
        "device_id", "model", "sim_no", "operator", "status", "installation_date", "vehicle_id",
        "imei_no", "battery_level", "signal_strength_pct", "firmware_version", "expiry_date",
        "installed_by", "current_location"
    }
    data = {k: v for k, v in payload.items() if k in allowed}
    data["updated_at"] = datetime.utcnow().isoformat()
    await sb.table("gps_devices").update(data).eq("id", gps_id).aexecute()
    return {"success": True, "message": "GPS Device updated"}

@router.delete("/gps-devices/{gps_id}")
async def delete_gps_device(gps_id: str, user=Depends(require_transport_admin)):
    sb = get_supabase()
    await sb.table("gps_devices").delete().eq("id", gps_id).aexecute()
    return {"success": True, "message": "GPS Device deleted"}

# ──────────────────────────────────────────────
# Drivers
# ──────────────────────────────────────────────

@router.get("/drivers")
async def list_drivers(
    school_id: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    user=Depends(require_transport_admin),
):
    sb = get_supabase()
    q = sb.table("drivers").select("*, bus_routes(route_name, bus_number, registration_no, vehicle_type)")
    if school_id:
        q = q.eq("school_id", school_id)
    if status:
        q = q.eq("status", status)
    res = await q.aexecute()
    return {"success": True, "data": res.data or []}

@router.post("/drivers")
async def create_driver(payload: dict, user=Depends(require_transport_admin)):
    sb = get_supabase()
    data = {
        "id": str(uuid.uuid4()),
        "school_id": payload.get("school_id"),
        "driver_code": payload["driver_code"],
        "name": payload["name"],
        "email": payload.get("email"),
        "phone": payload["phone"],
        "photo_url": payload.get("photo_url"),
        "license_no": payload["license_no"],
        "license_type": payload.get("license_type", "LMV"),
        "license_issue_date": payload.get("license_issue_date"),
        "license_expiry_date": payload.get("license_expiry_date"),
        "issuing_authority": payload.get("issuing_authority"),
        "experience_years": payload.get("experience_years", 0),
        "status": payload.get("status", "Inactive"),
        "assigned_vehicle_id": payload.get("assigned_vehicle_id"),
        "date_of_birth": payload.get("date_of_birth"),
        "blood_group": payload.get("blood_group"),
        "aadhar_no": payload.get("aadhar_no"),
        "address": payload.get("address"),
        "joined_date": payload.get("joined_date"),
    }
    
    # If assigned_vehicle_id is set, sync the vehicle's driver_name and driver_phone
    veh_id = payload.get("assigned_vehicle_id")
    if veh_id:
        await sb.table("bus_routes").update({
            "driver_name": payload["name"],
            "driver_phone": payload["phone"],
            "driver_license_no": payload["license_no"],
        }).eq("id", veh_id).aexecute()

    res = await sb.table("drivers").insert(data).aexecute()
    return {"success": True, "data": res.data[0] if res.data else data}

@router.put("/drivers/{driver_id}")
async def update_driver(driver_id: str, payload: dict, user=Depends(require_transport_admin)):
    sb = get_supabase()
    allowed = {
        "driver_code", "name", "email", "phone", "photo_url", "license_no",
        "license_type", "license_issue_date", "license_expiry_date", "issuing_authority",
        "experience_years", "status", "assigned_vehicle_id", "date_of_birth",
        "blood_group", "aadhar_no", "address", "joined_date"
    }
    data = {k: v for k, v in payload.items() if k in allowed}
    data["updated_at"] = datetime.utcnow().isoformat()
    
    # Sync bus_routes if assigned_vehicle_id changes/exists
    veh_id = payload.get("assigned_vehicle_id")
    if veh_id:
        name = payload.get("name")
        phone = payload.get("phone")
        lic = payload.get("license_no")
        update_data = {}
        if name: update_data["driver_name"] = name
        if phone: update_data["driver_phone"] = phone
        if lic: update_data["driver_license_no"] = lic
        if update_data:
            await sb.table("bus_routes").update(update_data).eq("id", veh_id).aexecute()

    await sb.table("drivers").update(data).eq("id", driver_id).aexecute()
    return {"success": True, "message": "Driver updated"}

@router.delete("/drivers/{driver_id}")
async def delete_driver(driver_id: str, user=Depends(require_transport_admin)):
    sb = get_supabase()
    await sb.table("drivers").delete().eq("id", driver_id).aexecute()
    return {"success": True, "message": "Driver deleted"}


# ──────────────────────────────────────────────
# Driver Documents
# ──────────────────────────────────────────────

@router.get("/drivers/documents")
async def list_driver_documents(
    school_id: Optional[str] = Query(None),
    driver_id: Optional[str] = Query(None),
    document_type: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    user=Depends(require_transport_admin),
):
    sb = get_supabase()
    q = sb.table("driver_documents").select("*, drivers(name, driver_code, photo_url, status)")
    if school_id:
        q = q.eq("school_id", school_id)
    if driver_id:
        q = q.eq("driver_id", driver_id)
    if document_type:
        q = q.eq("document_type", document_type)
    if status:
        q = q.eq("status", status)
    
    res = await q.aexecute()
    return {"success": True, "data": res.data or []}

@router.post("/drivers/documents")
async def create_driver_document(payload: dict, user=Depends(require_transport_admin)):
    sb = get_supabase()
    data = {
      "id": str(uuid.uuid4()),
      "school_id": payload.get("school_id") or "11111111-1111-1111-1111-111111111111",
      "driver_id": payload["driver_id"],
      "document_type": payload["document_type"],
      "document_no": payload["document_no"],
      "issued_date": payload.get("issued_date"),
      "expiry_date": payload.get("expiry_date"),
      "status": payload.get("status", "Valid"),
      "file_url": payload.get("file_url"),
      "file_name": payload.get("file_name"),
      "file_size": payload.get("file_size"),
      "issuing_authority": payload.get("issuing_authority"),
      "created_at": datetime.utcnow().isoformat(),
      "updated_at": datetime.utcnow().isoformat(),
    }
    res = await sb.table("driver_documents").insert(data).aexecute()
    return {"success": True, "data": res.data[0] if res.data else data}

@router.put("/drivers/documents/{doc_id}")
async def update_driver_document(doc_id: str, payload: dict, user=Depends(require_transport_admin)):
    sb = get_supabase()
    allowed = {
      "document_type", "document_no", "issued_date", "expiry_date", 
      "status", "file_url", "file_name", "file_size", "issuing_authority"
    }
    data = {k: v for k, v in payload.items() if k in allowed}
    data["updated_at"] = datetime.utcnow().isoformat()
    await sb.table("driver_documents").update(data).eq("id", doc_id).aexecute()
    return {"success": True, "message": "Document updated"}

@router.delete("/drivers/documents/{doc_id}")
async def delete_driver_document(doc_id: str, user=Depends(require_transport_admin)):
    sb = get_supabase()
    await sb.table("driver_documents").delete().eq("id", doc_id).aexecute()
    return {"success": True, "message": "Document deleted"}


# ──────────────────────────────────────────────
# Driver Performance
# ──────────────────────────────────────────────

@router.get("/drivers/performance")
async def list_driver_performance(
    school_id: Optional[str] = Query(None),
    driver_id: Optional[str] = Query(None),
    user=Depends(require_transport_admin),
):
    sb = get_supabase()
    # Join performance with driver details and driver's assigned vehicle details
    q = sb.table("driver_performance").select("*, drivers(*, bus_routes(registration_no, bus_number, vehicle_type))")
    if school_id:
        q = q.eq("school_id", school_id)
    if driver_id:
        q = q.eq("driver_id", driver_id)
    
    res = await q.aexecute()
    return {"success": True, "data": res.data or []}

@router.get("/drivers/performance/summary")
async def get_driver_performance_summary(
    school_id: Optional[str] = Query(None),
    user=Depends(require_transport_admin),
):
    sb = get_supabase()
    q = sb.table("driver_performance").select("attendance_score, safety_score, route_adherence_score, vehicle_care_score, feedback_score")
    if school_id:
        q = q.eq("school_id", school_id)
    res = await q.aexecute()
    records = res.data or []
    
    total_records = len(records)
    avg_score = 0.0
    excellent = 0
    good = 0
    needs_improvement = 0
    poor = 0
    
    if total_records > 0:
        total_sum = 0.0
        for r in records:
            # Calculate driver overall score as the average of components
            # Weights from mockup: Attendance (20%), Safety (30%), Route Adherence (20%), Vehicle Care (15%), Feedback (15%)
            score = (
                float(r.get("attendance_score") or 0.0) * 0.20 +
                float(r.get("safety_score") or 0.0) * 0.30 +
                float(r.get("route_adherence_score") or 0.0) * 0.20 +
                float(r.get("vehicle_care_score") or 0.0) * 0.15 +
                float(r.get("feedback_score") or 0.0) * 0.15
            )
            total_sum += score
            
            if score >= 4.5:
                excellent += 1
            elif score >= 3.5:
                good += 1
            elif score >= 2.5:
                needs_improvement += 1
            else:
                poor += 1
        avg_score = round(total_sum / total_records, 1)
        
    return {
        "success": True,
        "data": {
            "average_score": avg_score,
            "excellent_count": excellent,
            "good_count": good,
            "needs_improvement_count": needs_improvement,
            "poor_count": poor,
            "total_count": total_records
        }
    }


# ──────────────────────────────────────────────
# Driver Assignments
# ──────────────────────────────────────────────

@router.get("/drivers/assignments")
async def list_driver_assignments(
    school_id: Optional[str] = Query(None),
    driver_id: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    user=Depends(require_transport_admin),
):
    sb = get_supabase()
    q = sb.table("driver_assignments").select("*, drivers(*), vehicle:bus_routes!driver_assignments_vehicle_id_fkey(*), route:transport_routes!driver_assignments_route_id_fkey(*)")
    if school_id:
        q = q.eq("school_id", school_id)
    if driver_id:
        q = q.eq("driver_id", driver_id)
    if status:
        q = q.eq("status", status)
    
    res = await q.aexecute()
    return {"success": True, "data": res.data or []}

@router.post("/drivers/assignments")
async def create_driver_assignment(payload: dict, user=Depends(require_transport_admin)):
    sb = get_supabase()
    data = {
      "id": str(uuid.uuid4()),
      "school_id": payload.get("school_id") or "11111111-1111-1111-1111-111111111111",
      "driver_id": payload["driver_id"],
      "vehicle_id": payload.get("vehicle_id"),
      "route_id": payload.get("route_id"),
      "assignment_type": payload.get("assignment_type", "Route"),
      "start_date": payload["start_date"],
      "end_date": payload.get("end_date"),
      "shift": payload.get("shift", "General"),
      "status": payload.get("status", "Active"),
      "created_by": payload.get("created_by") or "Transport Manager",
      "notes": payload.get("notes"),
      "start_time": payload.get("start_time", "06:30 AM"),
      "end_time": payload.get("end_time", "09:30 AM"),
      "days": payload.get("days", "Mon,Tue,Wed,Thu,Fri"),
      "distance": payload.get("distance", 15.0),
      "estimated_duration": payload.get("estimated_duration", "45 mins"),
      "total_stops": payload.get("total_stops", 10),
      "created_at": datetime.utcnow().isoformat(),
      "updated_at": datetime.utcnow().isoformat(),
    }
    res = await sb.table("driver_assignments").insert(data).aexecute()
    return {"success": True, "data": res.data[0] if res.data else data}

@router.put("/drivers/assignments/{assign_id}")
async def update_driver_assignment(assign_id: str, payload: dict, user=Depends(require_transport_admin)):
    sb = get_supabase()
    allowed = {
      "vehicle_id", "route_id", "assignment_type", "start_date", 
      "end_date", "shift", "status", "notes", "start_time", 
      "end_time", "days", "distance", "estimated_duration", "total_stops"
    }
    data = {k: v for k, v in payload.items() if k in allowed}
    data["updated_at"] = datetime.utcnow().isoformat()
    await sb.table("driver_assignments").update(data).eq("id", assign_id).aexecute()
    return {"success": True, "message": "Assignment updated"}

@router.delete("/drivers/assignments/{assign_id}")
async def delete_driver_assignment(assign_id: str, user=Depends(require_transport_admin)):
    sb = get_supabase()
    await sb.table("driver_assignments").delete().eq("id", assign_id).aexecute()
    return {"success": True, "message": "Assignment deleted"}


# ──────────────────────────────────────────────
# Driver Training
# ──────────────────────────────────────────────

@router.get("/drivers/training")
async def list_driver_training(
    school_id: Optional[str] = Query(None),
    driver_id: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    user=Depends(require_transport_admin),
):
    sb = get_supabase()
    q = sb.table("driver_training").select("*, drivers(*)")
    if school_id:
        q = q.eq("school_id", school_id)
    if driver_id:
        q = q.eq("driver_id", driver_id)
    if status:
        q = q.eq("status", status)
    
    res = await q.aexecute()
    return {"success": True, "data": res.data or []}

@router.post("/drivers/training")
async def create_driver_training(payload: dict, user=Depends(require_transport_admin)):
    sb = get_supabase()
    data = {
      "id": str(uuid.uuid4()),
      "school_id": payload.get("school_id") or "11111111-1111-1111-1111-111111111111",
      "driver_id": payload["driver_id"],
      "training_program": payload["training_program"],
      "training_type": payload["training_type"],
      "provider": payload["provider"],
      "start_date": payload["start_date"],
      "end_date": payload.get("end_date"),
      "status": payload.get("status", "In Progress"),
      "certificate_url": payload.get("certificate_url"),
      "next_due_date": payload.get("next_due_date"),
      "start_time": payload.get("start_time", "09:00 AM"),
      "end_time": payload.get("end_time", "05:00 PM"),
      "created_at": datetime.utcnow().isoformat(),
      "updated_at": datetime.utcnow().isoformat(),
    }
    res = await sb.table("driver_training").insert(data).aexecute()
    return {"success": True, "data": res.data[0] if res.data else data}

@router.put("/drivers/training/{training_id}")
async def update_driver_training(training_id: str, payload: dict, user=Depends(require_transport_admin)):
    sb = get_supabase()
    allowed = {
      "training_program", "training_type", "provider", "start_date", 
      "end_date", "status", "certificate_url", "next_due_date",
      "start_time", "end_time"
    }
    data = {k: v for k, v in payload.items() if k in allowed}
    data["updated_at"] = datetime.utcnow().isoformat()
    await sb.table("driver_training").update(data).eq("id", training_id).aexecute()
    return {"success": True, "message": "Training updated"}

@router.delete("/drivers/training/{training_id}")
async def delete_driver_training(training_id: str, user=Depends(require_transport_admin)):
    sb = get_supabase()
    await sb.table("driver_training").delete().eq("id", training_id).aexecute()
    return {"success": True, "message": "Training deleted"}


# ──────────────────────────────────────────────
# Driver Violations
# ──────────────────────────────────────────────

@router.get("/drivers/violations")
async def list_driver_violations(
    school_id: Optional[str] = Query(None),
    driver_id: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    severity: Optional[str] = Query(None),
    user=Depends(require_transport_admin),
):
    sb = get_supabase()
    q = sb.table("driver_violations").select("*, drivers(*), bus_routes(*)")
    if school_id:
        q = q.eq("school_id", school_id)
    if driver_id:
        q = q.eq("driver_id", driver_id)
    if status:
        q = q.eq("status", status)
    if severity:
        q = q.eq("severity", severity)
    
    res = await q.aexecute()
    return {"success": True, "data": res.data or []}

@router.post("/drivers/violations")
async def create_driver_violation(payload: dict, user=Depends(require_transport_admin)):
    sb = get_supabase()
    data = {
      "id": str(uuid.uuid4()),
      "school_id": payload.get("school_id") or "11111111-1111-1111-1111-111111111111",
      "driver_id": payload["driver_id"],
      "violation_type": payload["violation_type"],
      "description": payload.get("description"),
      "date_time": payload["date_time"],
      "location": payload.get("location"),
      "vehicle_id": payload.get("vehicle_id"),
      "severity": payload.get("severity", "Medium"),
      "status": payload.get("status", "Pending"),
      "fine_amount": payload.get("fine_amount") or 0.0,
      "created_at": datetime.utcnow().isoformat(),
      "updated_at": datetime.utcnow().isoformat(),
    }
    res = await sb.table("driver_violations").insert(data).aexecute()
    return {"success": True, "data": res.data[0] if res.data else data}

@router.put("/drivers/violations/{violation_id}")
async def update_driver_violation(violation_id: str, payload: dict, user=Depends(require_transport_admin)):
    sb = get_supabase()
    allowed = {
      "violation_type", "description", "date_time", "location", 
      "vehicle_id", "severity", "status", "fine_amount"
    }
    data = {k: v for k, v in payload.items() if k in allowed}
    data["updated_at"] = datetime.utcnow().isoformat()
    await sb.table("driver_violations").update(data).eq("id", violation_id).aexecute()
    return {"success": True, "message": "Violation updated"}

@router.delete("/drivers/violations/{violation_id}")
async def delete_driver_violation(violation_id: str, user=Depends(require_transport_admin)):
    sb = get_supabase()
    await sb.table("driver_violations").delete().eq("id", violation_id).aexecute()
    return {"success": True, "message": "Violation deleted"}


# ──────────────────────────────────────────────
# Route Management
# ──────────────────────────────────────────────

@router.get("/routes")
async def list_routes(
    school_id: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    area: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    user=Depends(require_transport_admin),
):
    """List all routes with stops counts, assigned driver and vehicle details."""
    sb = get_supabase()
    
    # 1. Base Query for transport_routes joining vehicles (bus_routes) and drivers
    q = sb.table("transport_routes").select("*, bus_routes(*), drivers(*)")
    if school_id:
        q = q.eq("school_id", school_id)
    if status and status != "All":
        q = q.eq("status", status)
    if area and area != "All":
        q = q.ilike("area_zone", f"%{area}%")
        
    res = await q.aexecute()
    routes = res.data or []
    
    # 2. Get stops count and map to routes
    # Fetch all stops for the school
    stops_q = sb.table("transport_route_stops").select("route_id, distance_km") if hasattr(sb, 'table') else None
    stops_q = sb.table("transport_route_stops").select("route_id")
    if school_id:
        stops_q = stops_q.eq("school_id", school_id)
    stops_res = await stops_q.aexecute()
    stops = stops_res.data or []
    
    # Count stops per route
    stops_count_map = {}
    for stop in stops:
        rid = stop.get("route_id")
        stops_count_map[rid] = stops_count_map.get(rid, 0) + 1
        
    # Inject counts into routes data
    for r in routes:
        rid = r.get("id")
        r["stops_count"] = stops_count_map.get(rid, 0)
        
    # Filter by search string if provided
    if search:
        s = search.lower()
        filtered = []
        for r in routes:
            code = (r.get("route_code") or "").lower()
            name = (r.get("route_name") or "").lower()
            zone = (r.get("area_zone") or "").lower()
            bus_num = (r.get("bus_routes") or {}).get("bus_number", "") or ""
            bus_num = bus_num.lower()
            drv_name = (r.get("drivers") or {}).get("name", "") or ""
            drv_name = drv_name.lower()
            
            if s in code or s in name or s in zone or s in bus_num or s in drv_name:
                filtered.append(r)
        routes = filtered
        
    return {"success": True, "data": routes}


@router.get("/routes/{route_id}")
async def get_route(route_id: str, user=Depends(require_transport_admin)):
    """Get specific route and its stops."""
    sb = get_supabase()
    r_res = await sb.table("transport_routes").select("*, bus_routes(*), drivers(*)").eq("id", route_id).single().aexecute()
    route = r_res.data
    if not route:
        raise HTTPException(status_code=404, detail="Route not found")
        
    stops_res = await sb.table("transport_route_stops").select("*").eq("route_id", route_id).order("stop_order").aexecute()
    stops = stops_res.data or []
    
    return {
        "success": True,
        "data": {
            "route": route,
            "stops": stops
        }
    }


@router.post("/routes")
async def create_route(payload: dict, user=Depends(require_transport_admin)):
    """Create new route and optional stops."""
    sb = get_supabase()
    
    # Extract route details
    school_id = payload.get("school_id") or "11111111-1111-1111-1111-111111111111"
    route_data = {
        "id": str(uuid.uuid4()),
        "school_id": school_id,
        "route_code": payload["route_code"],
        "route_name": payload["route_name"],
        "area_zone": payload.get("area_zone"),
        "distance_km": payload.get("distance_km") or 0.0,
        "start_time": payload.get("start_time"),
        "end_time": payload.get("end_time"),
        "vehicle_id": payload.get("vehicle_id"),
        "driver_id": payload.get("driver_id"),
        "status": payload.get("status", "Active"),
        "created_at": datetime.utcnow().isoformat(),
        "updated_at": datetime.utcnow().isoformat(),
    }
    
    # Insert route
    res = await sb.table("transport_routes").insert(route_data).aexecute()
    inserted_route = res.data[0] if res.data else route_data
    
    # Insert stops if provided
    stops = payload.get("stops") or []
    inserted_stops = []
    if stops:
        for idx, stop in enumerate(stops):
            stop_data = {
                "id": str(uuid.uuid4()),
                "school_id": school_id,
                "route_id": route_data["id"],
                "stop_name": stop["stop_name"],
                "latitude": stop["latitude"],
                "longitude": stop["longitude"],
                "stop_order": stop.get("stop_order") or (idx + 1),
                "estimated_arrival": stop.get("estimated_arrival"),
                "created_at": datetime.utcnow().isoformat(),
                "updated_at": datetime.utcnow().isoformat(),
            }
            inserted_stops.append(stop_data)
        
        await sb.table("transport_route_stops").insert(inserted_stops).aexecute()
        
    return {
        "success": True,
        "data": {
            "route": inserted_route,
            "stops": inserted_stops
        }
    }


@router.put("/routes/{route_id}")
async def update_route(route_id: str, payload: dict, user=Depends(require_transport_admin)):
    """Update route and replace its stops."""
    sb = get_supabase()
    
    # Extract route details
    allowed = {
        "route_code", "route_name", "area_zone", "distance_km",
        "start_time", "end_time", "vehicle_id", "driver_id", "status"
    }
    route_data = {k: v for k, v in payload.items() if k in allowed}
    route_data["updated_at"] = datetime.utcnow().isoformat()
    
    # Update route
    await sb.table("transport_routes").update(route_data).eq("id", route_id).aexecute()
    
    # Handle stops replacement
    if "stops" in payload:
        # 1. Delete old stops
        await sb.table("transport_route_stops").delete().eq("route_id", route_id).aexecute()
        
        # 2. Insert new stops
        stops = payload["stops"] or []
        school_id = payload.get("school_id") or "11111111-1111-1111-1111-111111111111"
        inserted_stops = []
        if stops:
            for idx, stop in enumerate(stops):
                stop_data = {
                    "id": str(uuid.uuid4()),
                    "school_id": school_id,
                    "route_id": route_id,
                    "stop_name": stop["stop_name"],
                    "latitude": stop["latitude"],
                    "longitude": stop["longitude"],
                    "stop_order": stop.get("stop_order") or (idx + 1),
                    "estimated_arrival": stop.get("estimated_arrival"),
                    "created_at": datetime.utcnow().isoformat(),
                    "updated_at": datetime.utcnow().isoformat(),
                }
                inserted_stops.append(stop_data)
            
            await sb.table("transport_route_stops").insert(inserted_stops).aexecute()
            
    return {"success": True, "message": "Route updated successfully"}


@router.delete("/routes/{route_id}")
async def delete_route(route_id: str, user=Depends(require_transport_admin)):
    """Delete route (stops are deleted automatically via cascade)."""
    sb = get_supabase()
    await sb.table("transport_routes").delete().eq("id", route_id).aexecute()
    return {"success": True, "message": "Route deleted successfully"}


# ──────────────────────────────────────────────
# Stops CRUD Endpoints
# ──────────────────────────────────────────────

@router.get("/stops")
async def list_stops(
    school_id: Optional[str] = Query(None),
    route_id: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    stop_type: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    user=Depends(require_transport_admin),
):
    """List all stops with route details, search and filters."""
    sb = get_supabase()
    q = sb.table("transport_route_stops").select("*, transport_routes(*)").order("created_at", ascending=False)
    
    if school_id:
        q = q.eq("school_id", school_id)
    if route_id:
        q = q.eq("route_id", route_id)
    if status and status != "All":
        q = q.eq("status", status)
    if stop_type and stop_type != "All":
        q = q.eq("stop_type", stop_type)

    res = await q.aexecute()
    stops = res.data or []

    # Search filter (Python-side to support flexible sub-matching)
    if search:
        s = search.lower()
        filtered = []
        for st in stops:
            code = (st.get("stop_code") or "").lower()
            name = (st.get("stop_name") or "").lower()
            route_name = ((st.get("transport_routes") or {}).get("route_name") or "").lower()
            if s in code or s in name or s in route_name:
                filtered.append(st)
        stops = filtered

    total = len(stops)
    start = (page - 1) * page_size
    paginated = stops[start: start + page_size]

    return {
        "success": True,
        "data": {
            "stops": paginated,
            "total": total,
            "page": page,
            "page_size": page_size,
            "total_pages": max(1, (total + page_size - 1) // page_size),
        }
    }


@router.get("/stops/{stop_id}")
async def get_stop(stop_id: str, user=Depends(require_transport_admin)):
    """Get details of a single stop."""
    sb = get_supabase()
    res = await sb.table("transport_route_stops").select("*, transport_routes(*)").eq("id", stop_id).single().aexecute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Stop not found")
    return {"success": True, "data": res.data}


@router.post("/stops")
async def create_stop(payload: dict, user=Depends(require_transport_admin)):
    """Create a new stop."""
    sb = get_supabase()
    
    school_id = payload.get("school_id") or "11111111-1111-1111-1111-111111111111"
    
    # Auto-generate stop code if not provided
    stop_code = payload.get("stop_code")
    if not stop_code:
        count_res = await sb.table("transport_route_stops").select("id", count="exact").aexecute()
        count = count_res.count or 0
        stop_code = f"ST-{str(count + 1).zfill(3)}"

    stop_data = {
        "id": str(uuid.uuid4()),
        "school_id": school_id,
        "route_id": payload["route_id"],
        "stop_name": payload["stop_name"],
        "latitude": payload["latitude"],
        "longitude": payload["longitude"],
        "stop_order": payload.get("stop_order") or 1,
        "estimated_arrival": payload.get("estimated_arrival"),
        "stop_code": stop_code,
        "stop_type": payload.get("stop_type", "Pickup"),
        "pickup_drop_type": payload.get("pickup_drop_type", "Pickup Only"),
        "landmark": payload.get("landmark"),
        "radius_meters": payload.get("radius_meters") or 200,
        "status": payload.get("status", "Active"),
        "created_by": payload.get("created_by", "Transport Manager"),
        "created_at": datetime.utcnow().isoformat(),
        "updated_at": datetime.utcnow().isoformat(),
    }

    res = await sb.table("transport_route_stops").insert(stop_data).aexecute()
    return {"success": True, "data": res.data[0] if res.data else stop_data}


@router.put("/stops/{stop_id}")
async def update_stop(stop_id: str, payload: dict, user=Depends(require_transport_admin)):
    """Update a stop."""
    sb = get_supabase()
    
    allowed = {
        "route_id", "stop_name", "latitude", "longitude", "stop_order",
        "estimated_arrival", "stop_code", "stop_type", "pickup_drop_type",
        "landmark", "radius_meters", "status", "created_by"
    }
    
    stop_data = {k: v for k, v in payload.items() if k in allowed}
    stop_data["updated_at"] = datetime.utcnow().isoformat()
    
    await sb.table("transport_route_stops").update(stop_data).eq("id", stop_id).aexecute()
    return {"success": True, "message": "Stop updated successfully"}


@router.delete("/stops/{stop_id}")
async def delete_stop(stop_id: str, user=Depends(require_transport_admin)):
    """Delete a stop."""
    sb = get_supabase()
    await sb.table("transport_route_stops").delete().eq("id", stop_id).aexecute()
    return {"success": True, "message": "Stop deleted successfully"}


@router.get("/reports")
async def get_route_reports(
    school_id: Optional[str] = Query(None),
    start_date: Optional[str] = Query(None),
    end_date: Optional[str] = Query(None),
    route_id: Optional[str] = Query(None),
    vehicle_id: Optional[str] = Query(None),
    driver_id: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    user=Depends(require_transport_admin),
):
    from datetime import timedelta
    sb = get_supabase()
    
    # 1. Base date range defaults to last 30 days
    if not end_date:
        end_date = date.today().isoformat()
    if not start_date:
        start_date = (date.today() - timedelta(days=30)).isoformat()
        
    routes_q = sb.table("transport_routes").select("*, bus_routes(bus_number, driver_name), drivers(name)")
    if school_id:
        routes_q = routes_q.eq("school_id", school_id)
    routes_res = await routes_q.aexecute()
    routes_list = routes_res.data or []
    
    trips_q = sb.table("vehicle_trips").select("*, bus_routes(bus_number, route_name, driver_name)")
    if school_id:
        trips_q = trips_q.eq("school_id", school_id)
    
    trips_q = trips_q.gte("created_at", f"{start_date}T00:00:00Z")
    trips_q = trips_q.lte("created_at", f"{end_date}T23:59:59Z")
    
    trips_res = await trips_q.aexecute()
    trips_list = trips_res.data or []
    
    selected_vehicle_id = None
    if route_id:
        target_route = next((r for r in routes_list if str(r['id']) == str(route_id)), None)
        if target_route:
            selected_vehicle_id = target_route.get('vehicle_id')
            
    filtered_trips = []
    for t in trips_list:
        if selected_vehicle_id and str(t.get('route_id')) != str(selected_vehicle_id):
            continue
        if vehicle_id and str(t.get('route_id')) != str(vehicle_id):
            continue
        if status and status != 'All':
            t_status = (t.get('status') or '').lower()
            if status.lower() == 'completed' and t_status != 'completed':
                continue
            if status.lower() == 'cancelled' and t_status != 'cancelled':
                continue
            if status.lower() == 'delayed' and (t_status != 'completed' or t.get('delay_minutes', 0) <= 5):
                continue
            if status.lower() == 'on time' and (t_status != 'completed' or t.get('delay_minutes', 0) > 5):
                continue
        filtered_trips.append(t)
        
    total_trips = len(filtered_trips)
    completed_trips_count = sum(1 for t in filtered_trips if t.get('status') == 'completed')
    cancelled_trips_count = sum(1 for t in filtered_trips if t.get('status') == 'cancelled')
    on_time_trips_count = sum(1 for t in filtered_trips if t.get('status') == 'completed' and t.get('delay_minutes', 0) <= 5)
    delayed_trips_count = sum(1 for t in filtered_trips if t.get('status') == 'completed' and t.get('delay_minutes', 0) > 5)
    
    total_distance_km = float(sum(float(t.get('distance_km') or 0) for t in filtered_trips))
    total_students = int(sum(int(t.get('students_count') or 0) for t in filtered_trips))
    
    average_on_time_pct = round((on_time_trips_count / completed_trips_count * 100), 2) if completed_trips_count > 0 else 0.0
    cancellation_rate_pct = round((cancelled_trips_count / total_trips * 100), 2) if total_trips > 0 else 0.0
    
    total_routes_count = len(routes_list)
    
    daily_groups = {}
    for t in filtered_trips:
        dt_str = t.get('created_at', '')
        date_part = dt_str.split('T')[0] if dt_str else start_date
            
        if date_part not in daily_groups:
            daily_groups[date_part] = {
                "date": date_part,
                "total_distance": 0.0,
                "total_trips": 0,
                "on_time_trips": 0,
                "delayed_trips": 0,
                "cancelled_trips": 0,
            }
        
        daily_groups[date_part]["total_trips"] += 1
        if t.get('status') == 'completed':
            daily_groups[date_part]["total_distance"] += float(t.get('distance_km') or 0)
            if t.get('delay_minutes', 0) <= 5:
                daily_groups[date_part]["on_time_trips"] += 1
            else:
                daily_groups[date_part]["delayed_trips"] += 1
        elif t.get('status') == 'cancelled':
            daily_groups[date_part]["cancelled_trips"] += 1
            
    daily_trends = sorted(list(daily_groups.values()), key=lambda x: x['date'])
    for trend in daily_trends:
        trend["total_distance"] = round(trend["total_distance"], 2)
        
    route_details = []
    for r in routes_list:
        r_veh_id = r.get('vehicle_id')
        r_code = r.get('route_code', '')
        r_name = r.get('route_name', '')
        
        r_trips = [t for t in filtered_trips if str(t.get('route_id')) == str(r_veh_id)]
        r_total_trips = len(r_trips)
        r_completed = sum(1 for t in r_trips if t.get('status') == 'completed')
        r_cancelled = sum(1 for t in r_trips if t.get('status') == 'cancelled')
        r_on_time = sum(1 for t in r_trips if t.get('status') == 'completed' and t.get('delay_minutes', 0) <= 5)
        r_on_time_pct = round((r_on_time / r_completed * 100), 2) if r_completed > 0 else 0.0
        r_avg_delay = round(sum(int(t.get('delay_minutes', 0)) for t in r_trips) / r_completed, 1) if r_completed > 0 else 0.0
        r_dist = round(sum(float(t.get('distance_km') or 0) for t in r_trips), 2)
        r_students = sum(int(t.get('students_count') or 0) for t in r_trips)
        
        route_details.append({
            "route_id": str(r.get('id')),
            "route_code": r_code,
            "route_name": r_name,
            "total_trips": r_total_trips,
            "completed_trips": r_completed,
            "cancelled_trips": r_cancelled,
            "on_time_pct": r_on_time_pct,
            "avg_delay": r_avg_delay,
            "total_distance": r_dist,
            "students_transported": r_students,
        })
        
    route_details = sorted(route_details, key=lambda x: x['route_code'])
    
    routes_with_completed = [r for r in route_details if r['completed_trips'] > 0]
    
    best_route = max(routes_with_completed, key=lambda x: x['on_time_pct'], default=None)
    worst_route = min(routes_with_completed, key=lambda x: x['on_time_pct'], default=None)
    most_trips = max(route_details, key=lambda x: x['total_trips'], default=None)
    least_trips = min(route_details, key=lambda x: x['total_trips'], default=None)
    longest_route = max(route_details, key=lambda x: x['total_distance'], default=None)
    shortest_route = min(route_details, key=lambda x: x['total_distance'], default=None)
    
    summary = {
        "best_performing_route": {"name": best_route['route_name'] if best_route else "—", "value": f"{best_route['on_time_pct']}%" if best_route else "0.0%"},
        "worst_performing_route": {"name": worst_route['route_name'] if worst_route else "—", "value": f"{worst_route['on_time_pct']}%" if worst_route else "0.0%"},
        "most_trips_route": {"name": most_trips['route_name'] if most_trips else "—", "value": str(most_trips['total_trips']) if most_trips else "0"},
        "least_trips_route": {"name": least_trips['route_name'] if least_trips else "—", "value": str(least_trips['total_trips']) if least_trips else "0"},
        "longest_route": {"name": longest_route['route_name'] if longest_route else "—", "value": f"{longest_route['total_distance']} km" if longest_route else "0 km"},
        "shortest_route": {"name": shortest_route['route_name'] if shortest_route else "—", "value": f"{shortest_route['total_distance']} km" if shortest_route else "0 km"},
    }
    
    return {
        "success": True,
        "data": {
            "summary": {
                "total_routes": total_routes_count,
                "total_trips": total_trips,
                "total_distance": round(total_distance_km, 2),
                "total_students": total_students,
                "average_on_time": average_on_time_pct,
                "cancellation_rate": cancellation_rate_pct,
            },
            "status_donut": {
                "completed": completed_trips_count,
                "on_time": on_time_trips_count,
                "delayed": delayed_trips_count,
                "cancelled": cancelled_trips_count,
            },
            "trends": daily_trends,
            "routes_performance": route_details,
            "performance_summary": summary,
        }
    }





