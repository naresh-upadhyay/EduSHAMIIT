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
    except Exception as e:
        # Fallback: compute manually
        summary = await _compute_summary_manually(sb, school_id)

    return {"success": True, "data": summary}


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
    q = sb.table("driver_assignments").select("*, drivers(*), vehicle:bus_routes!driver_assignments_vehicle_id_fkey(*), route:bus_routes!driver_assignments_route_id_fkey(*)")
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


