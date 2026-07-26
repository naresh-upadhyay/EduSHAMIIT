"""
FastAPI GIS & TomTom Microservice Router.
Provides high-performance, Redis-cached route-aware POI searches, polyline downsampling,
and TomTom Search Along Route integrations.
"""
from fastapi import APIRouter, HTTPException, Query, Body, Depends
from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
import httpx
import json
import math
import hashlib
import time
import asyncio

from app.config import Settings
from app.cache.redis_client import get_redis
from app.middleware.auth import get_current_user

router = APIRouter(prefix="/gis", tags=["GIS & Maps Microservice"])
settings = Settings()

# ──────────────────────────────────────────────
# Pydantic Schemas
# ──────────────────────────────────────────────

class LatLngPoint(BaseModel):
    lat: float
    lon: float

class RoutePoiSearchRequest(BaseModel):
    category_key: str = Field(..., description="petrol, food, hospital, mechanic, parking")
    query_keyword: Optional[str] = ""
    route_points: List[LatLngPoint] = Field(default_factory=list)
    bus_location: Optional[LatLngPoint] = None
    max_radius_km: float = 3.0
    offset_km: float = 0.0
    ahead_only: bool = True
    is_emergency: bool = False

class PoiItem(BaseModel):
    display_name: str
    primary_title: str
    name: str
    lat: float
    lon: float
    detour_time_sec: Optional[int] = 0
    detour_dist_m: Optional[int] = 0
    detour_text: Optional[str] = ""
    source: str = "TomTom Microservice"
    category: str

class RoutePoiSearchResponse(BaseModel):
    success: bool = True
    cached: bool = False
    cache_engine: str = "none"
    count: int
    results: List[Dict[str, Any]]

# ──────────────────────────────────────────────
# Bus-Centric Route Slicing & Downsampling
# ──────────────────────────────────────────────

def get_route_ahead_segment(
    route_points: List[LatLngPoint],
    bus_loc: LatLngPoint,
    max_distance_km: float = 5.0,
    offset_km: float = 0.0
) -> List[LatLngPoint]:
    """
    Extracts ONLY the route segment starting near bus_loc (plus offset_km)
    extending forward up to max_distance_km ahead along the path.
    Guarantees POIs are hyper-localized near the bus position and direction of travel.
    """
    if not route_points or len(route_points) < 2:
        return [bus_loc, bus_loc]

    # 1. Locate nearest point on route to bus_loc
    min_dist = float("inf")
    nearest_idx = 0
    for i, pt in enumerate(route_points):
        d_lat = (pt.lat - bus_loc.lat) * 111.0
        d_lon = (pt.lon - bus_loc.lon) * 111.0 * math.cos(math.radians(bus_loc.lat))
        dist = math.sqrt(d_lat * d_lat + d_lon * d_lon)
        if dist < min_dist:
            min_dist = dist
            nearest_idx = i

    # 2. Advance by offset_km if requested for further path inspection
    curr_idx = nearest_idx
    if offset_km > 0.0 and nearest_idx < len(route_points) - 1:
        accum_offset = 0.0
        for i in range(nearest_idx, len(route_points) - 1):
            p1, p2 = route_points[i], route_points[i + 1]
            d_lat = (p2.lat - p1.lat) * 111.0
            d_lon = (p2.lon - p1.lon) * 111.0 * math.cos(math.radians((p1.lat + p2.lat) / 2.0))
            seg_dist = math.sqrt(d_lat * d_lat + d_lon * d_lon)
            accum_offset += seg_dist
            curr_idx = i + 1
            if accum_offset >= offset_km:
                break

    # 3. Extract forward segment up to max_distance_km
    start_pt = route_points[curr_idx]
    sliced_segment = [start_pt]
    accum_dist = 0.0

    for i in range(curr_idx, len(route_points) - 1):
        p1, p2 = route_points[i], route_points[i + 1]
        d_lat = (p2.lat - p1.lat) * 111.0
        d_lon = (p2.lon - p1.lon) * 111.0 * math.cos(math.radians((p1.lat + p2.lat) / 2.0))
        seg_dist = math.sqrt(d_lat * d_lat + d_lon * d_lon)

        sliced_segment.append(p2)
        accum_dist += seg_dist
        if accum_dist >= max_distance_km:
            break

    if len(sliced_segment) < 2:
        if curr_idx > 0:
            sliced_segment.insert(0, route_points[curr_idx - 1])
        else:
            sliced_segment.append(start_pt)

    return sliced_segment

def _perpendicular_distance_km(pt: LatLngPoint, line_start: LatLngPoint, line_end: LatLngPoint) -> float:
    avg_lat_rad = (line_start.lat + line_end.lat) / 2.0 * (math.pi / 180.0)
    dx = (line_end.lon - line_start.lon) * 111.0 * math.cos(avg_lat_rad)
    dy = (line_end.lat - line_start.lat) * 111.0

    mag = math.sqrt(dx * dx + dy * dy)
    if mag == 0.0:
        d_lat = (pt.lat - line_start.lat) * 111.0
        d_lon = (pt.lon - line_start.lon) * 111.0 * math.cos(avg_lat_rad)
        return math.sqrt(d_lat * d_lat + d_lon * d_lon)

    p_x = (pt.lon - line_start.lon) * 111.0 * math.cos(avg_lat_rad)
    p_y = (pt.lat - line_start.lat) * 111.0
    return abs(p_x * dy - p_y * dx) / mag


def douglas_peucker_simplify(points: List[LatLngPoint], epsilon_km: float = 0.02, max_points: int = 50) -> List[LatLngPoint]:
    if len(points) <= max_points:
        return points

    # Pre-subsample large polylines (> 150 points) for instant processing
    if len(points) > 150:
        step = (len(points) - 1) / 149.0
        points = [points[min(int(round(i * step)), len(points) - 1)] for i in range(150)]

    def _dp_recurse(pts: List[LatLngPoint], eps: float) -> List[LatLngPoint]:
        if len(pts) < 3:
            return pts
        max_dist = 0.0
        idx = 0
        end = len(pts) - 1
        for i in range(1, end):
            d = _perpendicular_distance_km(pts[i], pts[0], pts[end])
            if d > max_dist:
                max_dist = d
                idx = i
        if max_dist > eps:
            rec1 = _dp_recurse(pts[: idx + 1], eps)
            rec2 = _dp_recurse(pts[idx:], eps)
            return rec1[:-1] + rec2
        else:
            return [pts[0], pts[end]]

    simplified = _dp_recurse(points, epsilon_km)
    if len(simplified) > max_points:
        step = (len(simplified) - 1) / (max_points - 1)
        res = []
        for i in range(max_points):
            index = min(int(round(i * step)), len(simplified) - 1)
            if not res or res[-1] != simplified[index]:
                res.append(simplified[index])
        return res
    return simplified

def _sample_polyline_waypoints(route_points: List[LatLngPoint], bus_loc: LatLngPoint, gap_km: float = 2.0, max_dist_km: float = 15.0) -> List[LatLngPoint]:
    """
    Samples location waypoints along the active route polyline spaced ~2.0 km apart
    starting from the bus location moving forward.
    """
    if not route_points or len(route_points) < 2:
        return [bus_loc]

    min_dist = float("inf")
    nearest_idx = 0
    for i, pt in enumerate(route_points):
        d_lat = (pt.lat - bus_loc.lat) * 111.0
        d_lon = (pt.lon - bus_loc.lon) * 111.0 * math.cos(math.radians(bus_loc.lat))
        dist = math.sqrt(d_lat * d_lat + d_lon * d_lon)
        if dist < min_dist:
            min_dist = dist
            nearest_idx = i

    sampled = [route_points[nearest_idx]]
    accum_dist = 0.0
    last_sampled_accum = 0.0

    for i in range(nearest_idx, len(route_points) - 1):
        p1, p2 = route_points[i], route_points[i + 1]
        d_lat = (p2.lat - p1.lat) * 111.0
        d_lon = (p2.lon - p1.lon) * 111.0 * math.cos(math.radians((p1.lat + p2.lat) / 2.0))
        seg_dist = math.sqrt(d_lat * d_lat + d_lon * d_lon)
        accum_dist += seg_dist

        if (accum_dist - last_sampled_accum) >= gap_km:
            sampled.append(p2)
            last_sampled_accum = accum_dist

        if accum_dist >= max_dist_km:
            break

    return sampled


def _min_distance_to_polyline_km(pt_lat: float, pt_lon: float, polyline: List[LatLngPoint]) -> float:
    if not polyline:
        return float('inf')
    if len(polyline) == 1:
        d_lat = (pt_lat - polyline[0].lat) * 111.0
        d_lon = (pt_lon - polyline[0].lon) * 111.0 * math.cos(math.radians(pt_lat))
        return math.sqrt(d_lat * d_lat + d_lon * d_lon)

    min_dist = float('inf')
    for i in range(len(polyline) - 1):
        p1, p2 = polyline[i], polyline[i + 1]
        avg_lat_rad = (p1.lat + p2.lat) / 2.0 * (math.pi / 180.0)
        dx = (p2.lon - p1.lon) * 111.0 * math.cos(avg_lat_rad)
        dy = (p2.lat - p1.lat) * 111.0
        seg_len_sq = dx * dx + dy * dy
        if seg_len_sq == 0.0:
            d_lat = (pt_lat - p1.lat) * 111.0
            d_lon = (pt_lon - p1.lon) * 111.0 * math.cos(avg_lat_rad)
            dist = math.sqrt(d_lat * d_lat + d_lon * d_lon)
        else:
            px = (pt_lon - p1.lon) * 111.0 * math.cos(avg_lat_rad)
            py = (pt_lat - p1.lat) * 111.0
            t = max(0.0, min(1.0, (px * dx + py * dy) / seg_len_sq))
            proj_x = t * dx
            proj_y = t * dy
            dist_x = px - proj_x
            dist_y = py - proj_y
            dist = math.sqrt(dist_x * dist_x + dist_y * dist_y)
        if dist < min_dist:
            min_dist = dist
    return min_dist


def _build_search_query(category_key: str, fallback_query: str) -> str:
    key_lower = category_key.lower()
    if key_lower == 'petrol':
        return 'petrol'
    elif key_lower == 'food':
        return 'restaurant'
    elif key_lower == 'hospital':
        return 'hospital'
    elif key_lower == 'mechanic':
        return 'mechanic'
    elif key_lower == 'parking':
        return 'parking'
    return fallback_query if fallback_query else category_key

# ──────────────────────────────────────────────
# Endpoints
# ──────────────────────────────────────────────

@router.post("/places-on-the-way", response_model=RoutePoiSearchResponse)
async def get_places_on_the_way(req: RoutePoiSearchRequest, user=Depends(get_current_user)):
    """
    High-Performance TomTom Search Along Route with Redis Distributed Caching.
    Uses spatial polyline sampling with ~2km gaps to accurately discover Top 10 POIs on/near route.
    """
    tomtom_key = settings.TOMTOM_API_KEY
    if not tomtom_key:
        raise HTTPException(status_code=500, detail="TOMTOM_API_KEY is not configured in .env settings")

    # Safe resolution of bus_location
    bus_loc = req.bus_location
    if bus_loc is None:
        if req.route_points and len(req.route_points) > 0:
            bus_loc = req.route_points[0]
        else:
            bus_loc = LatLngPoint(lat=28.535512, lon=77.391023)

    category_key = req.category_key.lower()
    bus_lat_round = round(bus_loc.lat, 3)
    bus_lon_round = round(bus_loc.lon, 3)
    
    # Hash polyline points
    route_sig = ",".join([f"{round(p.lat, 3)},{round(p.lon, 3)}" for p in req.route_points[::5]]) if req.route_points else f"{bus_lat_round},{bus_lon_round}"
    spatial_hash = hashlib.sha256(f"{category_key}:{req.max_radius_km}:{req.is_emergency}:{route_sig}".encode()).hexdigest()[:16]
    redis_cache_key = f"gis:poi:{category_key}:{spatial_hash}"

    # 2. Redis Cache Lookup
    r = get_redis()
    if r:
        try:
            cached_data = await r.get(redis_cache_key)
            if cached_data:
                parsed = json.loads(cached_data)
                return RoutePoiSearchResponse(
                    success=True,
                    cached=True,
                    cache_engine="Redis Distributed Cache",
                    count=len(parsed),
                    results=parsed,
                )
        except Exception as e:
            print(f"[GIS Redis Cache] Cache read exception: {e}")

    # 3. Spatial Polyline Sampling (~2 km gap along active route)
    if req.route_points and len(req.route_points) >= 2:
        sampled_waypoints = _sample_polyline_waypoints(req.route_points, bus_loc, gap_km=2.0, max_dist_km=20.0)
    else:
        sampled_waypoints = [bus_loc]

    query = _build_search_query(category_key, req.query_keyword or "")
    from urllib.parse import quote
    encoded_query = quote(query)
    raw_candidates = []

    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            tasks = []
            radius_m = min(2500, max(1500, int(req.max_radius_km * 1000))) if not req.is_emergency else 20000
            for wp in sampled_waypoints:
                url = f"{settings.TOMTOM_BASE_URL}/poiSearch/{encoded_query}.json?key={tomtom_key}&lat={wp.lat}&lon={wp.lon}&radius={radius_m}&limit=10"
                tasks.append(client.get(url))

            responses = await asyncio.gather(*tasks, return_exceptions=True)
            for resp in responses:
                if isinstance(resp, httpx.Response) and resp.status_code == 200:
                    results = resp.json().get("results", [])
                    for item in results:
                        poi = item.get("poi", {})
                        addr = item.get("address", {})
                        pos = item.get("position", {})

                        lat = float(pos.get("lat", 0.0))
                        lon = float(pos.get("lon", 0.0))
                        if lat == 0.0 or lon == 0.0:
                            continue

                        name = str(poi.get("name", ""))
                        freeform = str(addr.get("freeformAddress", ""))
                        primary_title = name if name else (freeform.split(',')[0] if freeform else query)

                        raw_candidates.append({
                            "display_name": freeform if freeform else primary_title,
                            "primary_title": primary_title,
                            "name": primary_title,
                            "lat": lat,
                            "lon": lon,
                            "detour_time_sec": 0,
                            "detour_dist_m": 0,
                            "detour_text": "On route",
                            "source": "TomTom Microservice",
                            "category": category_key,
                        })
    except Exception as err:
        print(f"[GIS Microservice] Exception during TomTom sampling call: {err}")

    # 4. Strict Filter by Distance to Polyline
    parsed_pois = []
    max_poly_dist_km = 20.0 if req.is_emergency else 2.0  # Max 1-2 km away from route polyline!
    eval_polyline = req.route_points if req.route_points else [bus_loc]

    for item in raw_candidates:
        lat = item["lat"]
        lon = item["lon"]
        poly_dist = _min_distance_to_polyline_km(lat, lon, eval_polyline)

        if poly_dist <= max_poly_dist_km:
            item["detour_dist_m"] = int(poly_dist * 1000)
            item["detour_text"] = f"{round(poly_dist, 1)}km from route" if poly_dist > 0.1 else "On route"

            # Deduplicate by ~30 meters
            is_dup = any(abs(item["lat"] - existing["lat"]) < 0.0003 and abs(item["lon"] - existing["lon"]) < 0.0003 for existing in parsed_pois)
            if not is_dup:
                parsed_pois.append(item)

    # 5. Sort by proximity to polyline & take top 10
    parsed_pois.sort(key=lambda x: _min_distance_to_polyline_km(x["lat"], x["lon"], eval_polyline))
    parsed_pois = parsed_pois[:10]  # Top 10 nearest places!

    # Save to Redis Cache (TTL 10 mins = 600s)
    if r and parsed_pois:
        try:
            await r.setex(redis_cache_key, 600, json.dumps(parsed_pois))
        except Exception as ex:
            print(f"[GIS Redis Cache] Cache write exception: {ex}")

    return RoutePoiSearchResponse(
        success=True,
        cached=False,
        cache_engine="none",
        count=len(parsed_pois),
        results=parsed_pois,
    )


@router.get("/fuzzy-search")
async def fuzzy_search(query: str = Query(...), lat: Optional[float] = None, lon: Optional[float] = None, user=Depends(get_current_user)):
    """
    TomTom Fuzzy Search with Redis Caching for Location Bar Autocomplete.
    """
    if not query.strip():
        return {"success": True, "results": []}

    tomtom_key = settings.TOMTOM_API_KEY
    if not tomtom_key:
        raise HTTPException(status_code=500, detail="TOMTOM_API_KEY is not configured")

    clean_query = query.strip().lower()
    loc_key = f"{round(lat, 2)},{round(lon, 2)}" if lat and lon else "global"
    redis_key = f"gis:fuzzy:{clean_query}:{loc_key}"

    r = get_redis()
    if r:
        try:
            cached = await r.get(redis_key)
            if cached:
                return {"success": True, "cached": True, "results": json.loads(cached)}
        except Exception:
            pass

    from urllib.parse import quote
    encoded_q = quote(clean_query)
    url = f"{settings.TOMTOM_BASE_URL}/search/{encoded_q}.json?key={tomtom_key}&limit=10"
    if lat is not None and lon is not None:
        url += f"&lat={lat}&lon={lon}"

    try:
        async with httpx.AsyncClient(timeout=4.0) as client:
            res = await client.get(url)
            if res.status_code == 200:
                results = res.json().get("results", [])
                parsed = []
                for item in results:
                    poi = item.get("poi", {})
                    addr = item.get("address", {})
                    pos = item.get("position", {})

                    plat = float(pos.get("lat", 0.0))
                    plon = float(pos.get("lon", 0.0))
                    if plat == 0.0 or plon == 0.0:
                        continue

                    name = str(poi.get("name", ""))
                    freeform = str(addr.get("freeformAddress", ""))
                    title = name if name else (freeform.split(",")[0] if freeform else clean_query)

                    parsed.append({
                        "display_name": freeform if freeform else title,
                        "primary_title": title,
                        "name": title,
                        "lat": plat,
                        "lon": plon,
                        "source": "TomTom Microservice",
                    })

                if r and parsed:
                    try:
                        await r.setex(redis_key, 1200, json.dumps(parsed))
                    except Exception:
                        pass

                return {"success": True, "cached": False, "results": parsed}
    except Exception as e:
        print(f"[GIS Fuzzy Search] Exception: {e}")

    return {"success": False, "results": []}


@router.get("/config")
async def get_gis_config():
    """Returns microservice configuration and status."""
    r = get_redis()
    return {
        "status": "online",
        "provider": "TomTom Search Along Route API",
        "redis_cached": r is not None,
        "environment_configured": bool(settings.TOMTOM_API_KEY),
    }


@router.get("/route-geometry")
async def get_route_geometry(waypoints: str = Query(...)):
    """
    High-Performance OSRM Route Geometry Proxy with Redis Caching (24h TTL).
    Accepts waypoints string format: "lon1,lat1;lon2,lat2;lon3,lat3".
    Returns GeoJSON route coordinates array.
    """
    if not waypoints.strip():
        return {"success": False, "coordinates": []}

    redis_key = f"gis:route_geom:{hashlib.md5(waypoints.strip().encode()).hexdigest()}"
    r = get_redis()
    if r:
        try:
            cached = await r.get(redis_key)
            if cached:
                return {"success": True, "cached": True, "coordinates": json.loads(cached)}
        except Exception:
            pass

    endpoints = [
        f"https://router.project-osrm.org/route/v1/driving/{waypoints.strip()}?overview=full&geometries=geojson",
        f"https://routing.openstreetmap.de/routed-car/route/v1/driving/{waypoints.strip()}?overview=full&geometries=geojson",
    ]

    async with httpx.AsyncClient(timeout=6.0) as client:
        for url in endpoints:
            try:
                res = await client.get(url)
                if res.status_code == 200:
                    data = res.json()
                    routes = data.get("routes", [])
                    if routes:
                        coords = routes[0].get("geometry", {}).get("coordinates", [])
                        if coords:
                            if r:
                                try:
                                    await r.setex(redis_key, 86400, json.dumps(coords))
                                except Exception:
                                    pass
                            return {"success": True, "cached": False, "coordinates": coords}
            except Exception as e:
                print(f"[GIS Route Geometry] Error fetching from {url}: {e}")

    return {"success": False, "coordinates": []}
