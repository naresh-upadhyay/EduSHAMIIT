"""
SHAMIIT SMS GATEWAY API - Enterprise Multi-SIM SMS Gateway Backend
Company: SHAMIIT Innovation and Technologies LLP
Tagline: Imagine Beyond Imagination

Handles:
- Device registration, token rotation, heartbeats, and emergency disable
- Real Android SIM inventory & conflict-safe configuration synchronization
- Atomic job leasing, scheduled SMS, multipart tracking, and delivery events
- Idempotent inbound SMS ingestion & webhook forwarding
- Automation rules engine, DLT-ready templates with strict variable validation
- Real-time statistics, analytics charts, and WebSocket event broadcasts
"""

import asyncio
import hashlib
import json
import logging
import re
import secrets
import uuid
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from typing import Any, Dict, List, Optional

import httpx
import psycopg2
from fastapi import (
    APIRouter,
    BackgroundTasks,
    HTTPException,
    Query,
    Request,
    WebSocket,
    WebSocketDisconnect,
)
from psycopg2.extras import RealDictCursor, register_uuid
from pydantic import BaseModel, Field

from app.config import settings
from app.middleware.auth import get_current_user_optional

register_uuid()
logger = logging.getLogger(__name__)

router = APIRouter()

DEFAULT_SCHOOL_ID = "11111111-1111-1111-1111-111111111111"

GSM7_BASIC = set(
    "@£$¥èéùìòÇ\nØø\rÅåΔ_ΦΓΛΩΠΨΣΘΞ\x1bÆæßÉ !\"#¤%&'()*+,-./0123456789:;<=>?"
    "¡ABCDEFGHIJKLMNOPQRSTUVWXYZÄÖÑÜ§¿abcdefghijklmnopqrstuvwxyzäöñüà"
)
GSM7_EXTENDED = set("^{}\\[~]|€")
PHONE_REGEX = re.compile(r"^(\+[1-9]\d{6,14}|[6-9]\d{9}|0[6-9]\d{9})$")
TEMPLATE_VAR_REGEX = re.compile(r"\{([a-zA-Z0-9_]+)\}")


# ============================================================================
# WEBSOCKET CONNECTION MANAGER
# ============================================================================
class SmsWsManager:
    def __init__(self):
        self.active_connections: Dict[str, List[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, school_id: str):
        await websocket.accept()
        self.active_connections.setdefault(school_id, []).append(websocket)

    def disconnect(self, websocket: WebSocket, school_id: str):
        conns = self.active_connections.get(school_id)
        if not conns:
            return
        if websocket in conns:
            conns.remove(websocket)
        if not conns:
            self.active_connections.pop(school_id, None)

    async def broadcast(self, school_id: str, message: dict):
        conns = list(self.active_connections.get(school_id, []))
        for conn in conns:
            try:
                await conn.send_json(message)
            except Exception:
                self.disconnect(conn, school_id)


ws_manager = SmsWsManager()


# ============================================================================
# HELPERS & VALIDATORS
# ============================================================================
async def exec_sql(sql: str, params: tuple = (), fetch: bool = True) -> List[Dict[str, Any]]:
    def _run():
        conn = psycopg2.connect(settings.DATABASE_URL, connect_timeout=5)
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(sql, params)
                if fetch and cur.description:
                    rows = cur.fetchall()
                    conn.commit()
                    return [dict(r) for r in rows]
                conn.commit()
                return []
        except Exception as e:
            conn.rollback()
            raise e
        finally:
            conn.close()

    return await asyncio.to_thread(_run)


def serialize_val(val: Any) -> Any:
    if isinstance(val, (datetime, date)):
        if isinstance(val, datetime) and val.tzinfo is None:
            val = val.replace(tzinfo=timezone.utc)
        return val.isoformat()
    if isinstance(val, Decimal):
        return float(val)
    if isinstance(val, uuid.UUID):
        return str(val)
    if isinstance(val, dict):
        return {k: serialize_val(v) for k, v in val.items()}
    if isinstance(val, list):
        return [serialize_val(x) for x in val]
    return val


def serialize_rows(rows: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    return [{k: serialize_val(v) for k, v in r.items()} for r in rows]


def normalize_phone_number(raw: str) -> str:
    cleaned = re.sub(r"[\s\-().]", "", (raw or "").strip())
    if not PHONE_REGEX.match(cleaned):
        raise HTTPException(
            status_code=400,
            detail=f"Invalid phone number format: '{raw}'. Expected Indian 10-digit or E.164 international format.",
        )
    if re.match(r"^[6-9]\d{9}$", cleaned):
        return f"+91{cleaned}"
    if re.match(r"^0[6-9]\d{9}$", cleaned):
        return f"+91{cleaned[1:]}"
    return cleaned


def analyze_sms_encoding(body: str) -> Dict[str, Any]:
    if not body:
        return {"encoding": "GSM7", "length": 0, "segment_count": 1, "per_segment_limit": 160}
    septets = 0
    is_gsm7 = True
    for ch in body:
        if ch in GSM7_BASIC:
            septets += 1
        elif ch in GSM7_EXTENDED:
            septets += 2
        else:
            is_gsm7 = False
            break

    if is_gsm7:
        if septets <= 160:
            return {"encoding": "GSM7", "length": septets, "segment_count": 1, "per_segment_limit": 160}
        segments = (septets + 152) // 153
        return {"encoding": "GSM7", "length": septets, "segment_count": segments, "per_segment_limit": 153}
    else:
        code_units = len(body.encode("utf-16-be")) // 2
        if code_units <= 70:
            return {"encoding": "UNICODE", "length": code_units, "segment_count": 1, "per_segment_limit": 70}
        segments = (code_units + 66) // 67
        return {"encoding": "UNICODE", "length": code_units, "segment_count": segments, "per_segment_limit": 67}


def render_template_strict(template_body: str, variables: Dict[str, Any], required_vars: Optional[List[str]] = None) -> str:
    found_vars = set(TEMPLATE_VAR_REGEX.findall(template_body))
    req = set(required_vars or found_vars)
    missing = [v for v in sorted(req) if v not in variables or str(variables[v]).strip() == ""]
    if missing:
        raise HTTPException(
            status_code=400,
            detail=f"Unresolved required template variables: {', '.join(missing)}",
        )
    rendered = template_body
    for k in found_vars:
        if k in variables and variables[k] is not None:
            rendered = rendered.replace(f"{{{k}}}", str(variables[k]))
    unresolved = TEMPLATE_VAR_REGEX.findall(rendered)
    if unresolved:
        raise HTTPException(
            status_code=400,
            detail=f"Unresolved template placeholders: {', '.join(sorted(set(unresolved)))}",
        )
    return rendered


async def resolve_school_id(
    request: Request = None,
    x_school_id: Optional[str] = None,
    x_device_id: Optional[str] = None,
) -> str:
    if x_school_id and isinstance(x_school_id, str) and x_school_id.strip():
        return x_school_id.strip()
    if request:
        hdr_school = request.headers.get("x-school-id") or request.headers.get("X-School-ID")
        if hdr_school and hdr_school.strip():
            return hdr_school.strip()
        hdr_device = request.headers.get("x-device-id") or request.headers.get("X-Device-ID")
        if hdr_device and not x_device_id:
            x_device_id = hdr_device
        try:
            user = await get_current_user_optional(request)
            if user and user.get("school_id"):
                return str(user["school_id"])
        except Exception:
            pass
    if x_device_id and isinstance(x_device_id, str):
        rows = await exec_sql(
            "SELECT school_id FROM public.sms_gateway_devices WHERE device_id = %s LIMIT 1",
            (x_device_id,),
        )
        if rows:
            return str(rows[0]["school_id"])
    return DEFAULT_SCHOOL_ID


def resolve_device_id(request: Request = None, explicit_device_id: Optional[str] = None) -> str:
    if explicit_device_id and explicit_device_id.strip():
        return explicit_device_id.strip()
    if request:
        hdr = request.headers.get("x-device-id") or request.headers.get("X-Device-ID")
        if hdr and hdr.strip():
            return hdr.strip()
    return "DEFAULT"


async def record_gateway_event(
    school_id: str,
    event_type: str,
    title: str,
    description: Optional[str] = None,
    device_id: Optional[str] = None,
    message_uuid: Optional[str] = None,
    sim_slot: Optional[int] = None,
    subscription_id: Optional[int] = None,
    application_source: Optional[str] = None,
    payload: Optional[Dict[str, Any]] = None,
    event_uuid: Optional[str] = None,
    event_timestamp: Optional[str] = None,
):
    eid = event_uuid or f"evt-{uuid.uuid4().hex}"
    ts = event_timestamp or datetime.now(timezone.utc).isoformat()
    await exec_sql(
        """
        INSERT INTO public.sms_gateway_events (
            school_id, event_uuid, device_id, message_uuid, event_type,
            title, description, sim_slot, subscription_id, application_source,
            payload, event_timestamp
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s::jsonb, %s::timestamptz)
        ON CONFLICT (event_uuid) DO NOTHING
        """,
        (
            school_id,
            eid,
            device_id,
            message_uuid,
            event_type,
            title,
            description,
            sim_slot,
            subscription_id,
            application_source,
            json.dumps(payload or {}),
            ts,
        ),
        fetch=False,
    )
    await ws_manager.broadcast(
        school_id,
        {
            "type": event_type,
            "event_uuid": eid,
            "title": title,
            "description": description,
            "message_uuid": message_uuid,
            "sim_slot": sim_slot,
            "subscription_id": subscription_id,
            "application_source": application_source,
            "timestamp": ts,
        },
    )


async def forward_webhook_async(url: str, payload: Dict[str, Any], rule_id: str, school_id: str):
    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            resp = await client.post(url, json=payload)
        await exec_sql(
            """
            INSERT INTO public.sms_gateway_rule_executions (
                school_id, rule_id, message_uuid, recipient_number, status, payload
            ) VALUES (%s, %s, %s, %s, %s, %s::jsonb)
            """,
            (
                school_id,
                rule_id,
                payload.get("message_uuid"),
                payload.get("sender_number"),
                "DELIVERED_WEBHOOK" if resp.status_code < 400 else f"WEBHOOK_HTTP_{resp.status_code}",
                json.dumps({"status_code": resp.status_code}),
            ),
            fetch=False,
        )
    except Exception as exc:
        await exec_sql(
            """
            INSERT INTO public.sms_gateway_rule_executions (
                school_id, rule_id, message_uuid, recipient_number, status, error_detail
            ) VALUES (%s, %s, %s, %s, 'WEBHOOK_FAILED', %s)
            """,
            (school_id, rule_id, payload.get("message_uuid"), payload.get("sender_number"), str(exc)),
            fetch=False,
        )


# ============================================================================
# SCHEMAS
# ============================================================================
class DeviceRegisterRequest(BaseModel):
    device_id: str
    device_name: str
    model: Optional[str] = "Android Device"
    manufacturer: Optional[str] = ""
    android_version: Optional[str] = "Android"
    app_version: Optional[str] = "1.0.0"
    school_id: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None


class DeviceHeartbeatRequest(BaseModel):
    device_id: str
    is_online: bool = True
    battery_level: int = 100
    is_charging: bool = False
    battery_optimization_disabled: bool = False
    network_type: str = "UNKNOWN"
    internet_connected: bool = True
    queue_size: int = 0
    uptime_seconds: int = 0
    active_sim_slot: Optional[int] = None
    active_subscription_id: Optional[int] = None
    api_latency_ms: Optional[int] = None


class SimRecordInput(BaseModel):
    subscription_id: int
    sim_slot_index: int
    carrier_name: str = "Unknown Carrier"
    display_name: str = ""
    country_iso: str = ""
    phone_number: Optional[str] = None
    sim_state: str = "READY"
    network_operator: str = ""
    network_type: str = "UNKNOWN"
    signal_strength_dbm: Optional[int] = None
    signal_level: int = 0
    signal_label: str = "Unknown"
    is_active: bool = True
    is_data_enabled: bool = False
    usage_mode: str = "SEND_RECEIVE"
    balance_info: str = "Not Available"
    validity_info: str = "Not Available"


class SimConfigurationUpdateRequest(BaseModel):
    device_id: Optional[str] = None
    sims: Optional[List[SimRecordInput]] = None
    preferred_sim_mode: Optional[str] = None  # SIM_1, SIM_2, MANUAL, AUTO_RULE
    preferred_subscription_id: Optional[int] = None
    preferred_sim_slot: Optional[int] = None
    secondary_subscription_id: Optional[int] = None
    secondary_sim_slot: Optional[int] = None
    auto_fallback_enabled: Optional[bool] = None
    switch_on_unavailable: Optional[bool] = None
    switch_on_network_error: Optional[bool] = None
    switch_back_on_recover: Optional[bool] = None


class GatewayConfigurationUpdateRequest(BaseModel):
    device_id: Optional[str] = None
    automated_messaging_enabled: Optional[bool] = None
    incoming_forwarding_enabled: Optional[bool] = None
    queue_sync_enabled: Optional[bool] = None
    scheduled_processing_enabled: Optional[bool] = None
    polling_interval_seconds: Optional[int] = None
    message_expiration_seconds: Optional[int] = None
    retention_days: Optional[int] = None
    emergency_disabled: Optional[bool] = None
    server_url: Optional[str] = None


class DeviceEventItem(BaseModel):
    event_uuid: Optional[str] = None
    message_uuid: Optional[str] = None
    event_type: str  # SMS_SUBMITTED, SMS_SENT, SMS_DELIVERED, SMS_FAILED, SIM_CHANGED, etc.
    title: Optional[str] = None
    description: Optional[str] = None
    sim_slot: Optional[int] = None
    subscription_id: Optional[int] = None
    carrier_name: Optional[str] = None
    failure_reason: Optional[str] = None
    part_statuses: Optional[List[Dict[str, Any]]] = None
    retry_count: Optional[int] = None
    lease_token: Optional[str] = None
    event_timestamp: Optional[str] = None


class DeviceEventsBatchRequest(BaseModel):
    device_id: str
    events: List[DeviceEventItem]


class InboundSmsRequest(BaseModel):
    device_id: str
    message_uuid: Optional[str] = None
    sender_number: str
    recipient_number: Optional[str] = None
    message_body: str
    receiving_sim_slot: Optional[int] = None
    receiving_subscription_id: Optional[int] = None
    carrier_name: Optional[str] = None
    received_at: Optional[str] = None


class SendSmsRequest(BaseModel):
    recipients: List[str]
    message_body: str
    subscription_id: Optional[int] = None
    sim_slot: Optional[int] = None
    priority: str = "NORMAL"
    scheduled_at: Optional[str] = None
    expires_at: Optional[str] = None
    template_id: Optional[str] = None
    template_variables: Optional[Dict[str, Any]] = None
    application_source: str = "SMS Gateway App"
    reference_id: Optional[str] = None
    delivery_report_requested: bool = True
    device_id: Optional[str] = None
    client_message_uuids: Optional[List[str]] = None


class DeviceSyncRequest(BaseModel):
    device_id: str
    sims: Optional[List[SimRecordInput]] = None
    events: Optional[List[DeviceEventItem]] = None
    inbound_messages: Optional[List[InboundSmsRequest]] = None
    outbound_messages: Optional[List[Dict[str, Any]]] = None


class AutomationRuleRequest(BaseModel):
    rule_name: str
    application_name: str
    trigger_event: str
    recipient_mapping: str = "parent_phone"
    template_id: Optional[str] = None
    message_template: str
    preferred_sim_slot: Optional[int] = None
    preferred_subscription_id: Optional[int] = None
    priority: str = "NORMAL"
    is_active: bool = True
    schedule_restriction: Optional[Dict[str, Any]] = None
    webhook_url: Optional[str] = None


class TriggerAutomationRequest(BaseModel):
    application_name: str
    trigger_event: str
    recipient_number: Optional[str] = None
    variables: Dict[str, Any] = Field(default_factory=dict)
    reference_id: Optional[str] = None


class TemplateRequest(BaseModel):
    template_name: str
    application_name: str = "EduSHAMIIT"
    category: str = "Notification"
    message_body: str
    required_variables: Optional[List[str]] = None
    dlt_template_id: Optional[str] = None
    dlt_header: Optional[str] = None
    default_priority: str = "NORMAL"
    preferred_sim_slot: Optional[int] = None
    is_active: bool = True


# ============================================================================
# HEALTH & SCHOOL INFO
# ============================================================================
@router.get("/sms-gateway/health")
async def sms_gateway_health():
    return {
        "status": "healthy",
        "service": "SHAMIIT SMS GATEWAY API",
        "company": "SHAMIIT Innovation and Technologies LLP",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


@router.get("/sms-gateway/school-info")
async def sms_gateway_school_info(request: Request, school_id: Optional[str] = None):
    sid = school_id or await resolve_school_id(request)
    rows = await exec_sql(
        "SELECT id, name, address, phone FROM public.schools WHERE id = %s LIMIT 1",
        (sid,),
    )
    if rows:
        return {"school_id": str(rows[0]["id"]), "school_name": rows[0]["name"]}
    return {"school_id": sid, "school_name": "Shami Innovation Academy"}


# ============================================================================
# DEVICE REGISTRATION, TOKEN & HEARTBEAT
# ============================================================================
@router.post("/device/register")
async def register_device(payload: DeviceRegisterRequest, request: Request):
    school_id = payload.school_id or await resolve_school_id(request, x_device_id=payload.device_id)
    raw_token = f"sms_{secrets.token_urlsafe(32)}"
    token_hash = hashlib.sha256(raw_token.encode()).hexdigest()

    existing = await exec_sql(
        "SELECT id, status FROM public.sms_gateway_devices WHERE device_id = %s LIMIT 1",
        (payload.device_id,),
    )
    if existing:
        await exec_sql(
            """
            UPDATE public.sms_gateway_devices
            SET school_id = %s,
                device_name = %s,
                model = %s,
                manufacturer = %s,
                android_version = %s,
                app_version = %s,
                is_online = TRUE,
                device_token_hash = COALESCE(device_token_hash, %s),
                token_issued_at = COALESCE(token_issued_at, NOW()),
                last_heartbeat_at = NOW(),
                last_sync_at = NOW(),
                metadata = COALESCE(metadata, '{}'::jsonb) || %s::jsonb,
                updated_at = NOW()
            WHERE device_id = %s
            """,
            (
                school_id,
                payload.device_name,
                payload.model or "Android Device",
                payload.manufacturer or "",
                payload.android_version or "Android",
                payload.app_version or "1.0.0",
                token_hash,
                json.dumps(payload.metadata or {}),
                payload.device_id,
            ),
            fetch=False,
        )
    else:
        await exec_sql(
            """
            INSERT INTO public.sms_gateway_devices (
                school_id, device_id, device_name, model, manufacturer,
                android_version, app_version, status, is_online,
                device_token_hash, token_issued_at, last_heartbeat_at, last_sync_at, metadata
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, 'ACTIVE', TRUE, %s, NOW(), NOW(), NOW(), %s::jsonb)
            """,
            (
                school_id,
                payload.device_id,
                payload.device_name,
                payload.model or "Android Device",
                payload.manufacturer or "",
                payload.android_version or "Android",
                payload.app_version or "1.0.0",
                token_hash,
                json.dumps(payload.metadata or {}),
            ),
            fetch=False,
        )

    await exec_sql(
        """
        INSERT INTO public.sms_gateway_settings (school_id, device_id)
        VALUES (%s, %s)
        ON CONFLICT (school_id, device_id) DO NOTHING
        """,
        (school_id, payload.device_id),
        fetch=False,
    )

    await record_gateway_event(
        school_id=school_id,
        event_type="GATEWAY_CONNECTED",
        title=f"Gateway registered: {payload.device_name}",
        description=f"Device {payload.device_id} ({payload.model}) connected.",
        device_id=payload.device_id,
    )

    return {
        "success": True,
        "device_id": payload.device_id,
        "school_id": school_id,
        "device_token": raw_token,
        "status": "ACTIVE",
    }


@router.post("/device/token/renew")
async def renew_device_token(request: Request, device_id: Optional[str] = None):
    did = resolve_device_id(request, device_id)
    school_id = await resolve_school_id(request, x_device_id=did)
    raw_token = f"sms_{secrets.token_urlsafe(32)}"
    token_hash = hashlib.sha256(raw_token.encode()).hexdigest()

    rows = await exec_sql(
        """
        UPDATE public.sms_gateway_devices
        SET device_token_hash = %s, token_issued_at = NOW(), updated_at = NOW()
        WHERE device_id = %s
        RETURNING device_id, school_id
        """,
        (token_hash, did),
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Device not registered")

    return {
        "success": True,
        "device_id": did,
        "device_token": raw_token,
        "issued_at": datetime.now(timezone.utc).isoformat(),
    }


@router.post("/device/emergency-disable")
async def emergency_disable_gateway(request: Request, disabled: bool = True, device_id: Optional[str] = None):
    did = resolve_device_id(request, device_id)
    school_id = await resolve_school_id(request, x_device_id=did)
    new_status = "EMERGENCY_DISABLED" if disabled else "ACTIVE"
    await exec_sql(
        "UPDATE public.sms_gateway_devices SET status = %s, updated_at = NOW() WHERE device_id = %s",
        (new_status, did),
        fetch=False,
    )
    await exec_sql(
        """
        INSERT INTO public.sms_gateway_settings (school_id, device_id, emergency_disabled)
        VALUES (%s, %s, %s)
        ON CONFLICT (school_id, device_id)
        DO UPDATE SET emergency_disabled = EXCLUDED.emergency_disabled, updated_at = NOW()
        """,
        (school_id, did, disabled),
        fetch=False,
    )
    await record_gateway_event(
        school_id=school_id,
        event_type="GATEWAY_DISCONNECTED" if disabled else "GATEWAY_CONNECTED",
        title="Emergency Gateway Disable Activated" if disabled else "Gateway Re-enabled",
        device_id=did,
    )
    return {"success": True, "emergency_disabled": disabled, "status": new_status}


@router.post("/device/heartbeat")
async def device_heartbeat(payload: DeviceHeartbeatRequest, request: Request):
    school_id = await resolve_school_id(request, x_device_id=payload.device_id)
    devices = await exec_sql(
        "SELECT id, status FROM public.sms_gateway_devices WHERE device_id = %s LIMIT 1",
        (payload.device_id,),
    )
    if not devices:
        await exec_sql(
            """
            INSERT INTO public.sms_gateway_devices (
                school_id, device_id, device_name, is_online, battery_level,
                is_charging, battery_optimization_disabled, network_type,
                internet_connected, uptime_seconds, active_sim_slot,
                active_subscription_id, last_heartbeat_at
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, NOW())
            """,
            (
                school_id,
                payload.device_id,
                payload.device_id,
                payload.is_online,
                payload.battery_level,
                payload.is_charging,
                payload.battery_optimization_disabled,
                payload.network_type,
                payload.internet_connected,
                payload.uptime_seconds,
                payload.active_sim_slot,
                payload.active_subscription_id,
            ),
            fetch=False,
        )
        devices = await exec_sql(
            "SELECT id, status FROM public.sms_gateway_devices WHERE device_id = %s LIMIT 1",
            (payload.device_id,),
        )

    device_pk = devices[0]["id"]
    await exec_sql(
        """
        UPDATE public.sms_gateway_devices
        SET is_online = %s,
            battery_level = %s,
            is_charging = %s,
            battery_optimization_disabled = %s,
            network_type = %s,
            internet_connected = %s,
            uptime_seconds = %s,
            active_sim_slot = %s,
            active_subscription_id = %s,
            last_heartbeat_at = NOW(),
            updated_at = NOW()
        WHERE id = %s
        """,
        (
            payload.is_online,
            payload.battery_level,
            payload.is_charging,
            payload.battery_optimization_disabled,
            payload.network_type,
            payload.internet_connected,
            payload.uptime_seconds,
            payload.active_sim_slot,
            payload.active_subscription_id,
            device_pk,
        ),
        fetch=False,
    )

    client_ip = request.client.host if request.client else None
    await exec_sql(
        """
        INSERT INTO public.sms_gateway_device_heartbeats (
            device_pk, school_id, is_online, battery_level, is_charging,
            battery_optimization_disabled, network_type, queue_size,
            uptime_seconds, active_sim_slot, active_subscription_id,
            api_latency_ms, ip_address
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """,
        (
            device_pk,
            school_id,
            payload.is_online,
            payload.battery_level,
            payload.is_charging,
            payload.battery_optimization_disabled,
            payload.network_type,
            payload.queue_size,
            payload.uptime_seconds,
            payload.active_sim_slot,
            payload.active_subscription_id,
            payload.api_latency_ms,
            client_ip,
        ),
        fetch=False,
    )

    return {
        "success": True,
        "server_time": datetime.now(timezone.utc).isoformat(),
        "device_status": devices[0]["status"],
    }


# ============================================================================
# SIM CONFIGURATION & CONFLICT RESOLUTION
# ============================================================================
async def _get_or_init_settings(school_id: str, device_id: str) -> Dict[str, Any]:
    rows = await exec_sql(
        """
        SELECT * FROM public.sms_gateway_settings
        WHERE school_id = %s AND device_id = %s LIMIT 1
        """,
        (school_id, device_id),
    )
    if rows:
        return serialize_rows(rows)[0]
    rows = await exec_sql(
        """
        SELECT * FROM public.sms_gateway_settings
        WHERE school_id = %s AND device_id = 'DEFAULT' LIMIT 1
        """,
        (school_id,),
    )
    if rows:
        return serialize_rows(rows)[0]
    await exec_sql(
        """
        INSERT INTO public.sms_gateway_settings (school_id, device_id)
        VALUES (%s, %s)
        ON CONFLICT (school_id, device_id) DO NOTHING
        """,
        (school_id, device_id),
        fetch=False,
    )
    rows = await exec_sql(
        "SELECT * FROM public.sms_gateway_settings WHERE school_id = %s AND device_id = %s LIMIT 1",
        (school_id, device_id),
    )
    return serialize_rows(rows)[0]


@router.get("/sms/sim-configuration")
async def get_sim_configuration(request: Request, device_id: Optional[str] = None):
    did = resolve_device_id(request, device_id)
    school_id = await resolve_school_id(request, x_device_id=did)
    sims = await exec_sql(
        """
        SELECT * FROM public.sms_gateway_sims
        WHERE school_id = %s AND (%s = 'DEFAULT' OR device_id = %s)
        ORDER BY sim_slot_index ASC, subscription_id ASC
        """,
        (school_id, did, did),
    )
    cfg = await _get_or_init_settings(school_id, did)
    return {
        "device_id": did,
        "sims": serialize_rows(sims),
        "configuration": cfg,
    }


@router.post("/device/sim-configuration")
async def sync_sim_configuration(payload: SimConfigurationUpdateRequest, request: Request):
    did = resolve_device_id(request, payload.device_id)
    school_id = await resolve_school_id(request, x_device_id=did)

    conflicts: List[str] = []

    # Device is source of truth for observed SIM hardware inventory
    if payload.sims is not None:
        observed_sub_ids = [s.subscription_id for s in payload.sims]
        if observed_sub_ids:
            await exec_sql(
                """
                UPDATE public.sms_gateway_sims
                SET is_active = FALSE, sim_state = 'REMOVED', updated_at = NOW()
                WHERE device_id = %s AND subscription_id != ALL(%s)
                """,
                (did, observed_sub_ids),
                fetch=False,
            )
        else:
            await exec_sql(
                """
                UPDATE public.sms_gateway_sims
                SET is_active = FALSE, sim_state = 'REMOVED', updated_at = NOW()
                WHERE device_id = %s
                """,
                (did,),
                fetch=False,
            )

        for sim in payload.sims:
            await exec_sql(
                """
                INSERT INTO public.sms_gateway_sims (
                    school_id, device_id, subscription_id, sim_slot_index,
                    carrier_name, display_name, country_iso, phone_number,
                    sim_state, network_operator, network_type,
                    signal_strength_dbm, signal_level, signal_label,
                    is_active, is_data_enabled, usage_mode, balance_info, validity_info, last_seen_at
                ) VALUES (
                    %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, NOW()
                )
                ON CONFLICT (device_id, subscription_id) DO UPDATE SET
                    school_id = EXCLUDED.school_id,
                    sim_slot_index = EXCLUDED.sim_slot_index,
                    carrier_name = EXCLUDED.carrier_name,
                    display_name = EXCLUDED.display_name,
                    country_iso = EXCLUDED.country_iso,
                    phone_number = COALESCE(EXCLUDED.phone_number, public.sms_gateway_sims.phone_number),
                    sim_state = EXCLUDED.sim_state,
                    network_operator = EXCLUDED.network_operator,
                    network_type = EXCLUDED.network_type,
                    signal_strength_dbm = EXCLUDED.signal_strength_dbm,
                    signal_level = EXCLUDED.signal_level,
                    signal_label = EXCLUDED.signal_label,
                    is_active = EXCLUDED.is_active,
                    is_data_enabled = EXCLUDED.is_data_enabled,
                    usage_mode = EXCLUDED.usage_mode,
                    balance_info = EXCLUDED.balance_info,
                    validity_info = EXCLUDED.validity_info,
                    last_seen_at = NOW(),
                    updated_at = NOW()
                """,
                (
                    school_id,
                    did,
                    sim.subscription_id,
                    sim.sim_slot_index,
                    sim.carrier_name,
                    sim.display_name or sim.carrier_name,
                    sim.country_iso,
                    sim.phone_number,
                    sim.sim_state,
                    sim.network_operator,
                    sim.network_type,
                    sim.signal_strength_dbm,
                    sim.signal_level,
                    sim.signal_label,
                    sim.is_active,
                    sim.is_data_enabled,
                    sim.usage_mode,
                    sim.balance_info,
                    sim.validity_info,
                ),
                fetch=False,
            )

    current_cfg = await _get_or_init_settings(school_id, did)
    active_sims = await exec_sql(
        """
        SELECT subscription_id, sim_slot_index, carrier_name, usage_mode
        FROM public.sms_gateway_sims
        WHERE device_id = %s AND is_active = TRUE
        ORDER BY sim_slot_index ASC
        """,
        (did,),
    )
    active_sub_ids = {int(s["subscription_id"]) for s in active_sims}

    pref_sub = payload.preferred_subscription_id if payload.preferred_subscription_id is not None else current_cfg.get("preferred_subscription_id")
    pref_slot = payload.preferred_sim_slot if payload.preferred_sim_slot is not None else current_cfg.get("preferred_sim_slot")
    pref_mode = payload.preferred_sim_mode or current_cfg.get("preferred_sim_mode", "SIM_1")
    auto_fallback = payload.auto_fallback_enabled if payload.auto_fallback_enabled is not None else current_cfg.get("auto_fallback_enabled", False)
    sec_sub = payload.secondary_subscription_id if payload.secondary_subscription_id is not None else current_cfg.get("secondary_subscription_id")
    sec_slot = payload.secondary_sim_slot if payload.secondary_sim_slot is not None else current_cfg.get("secondary_sim_slot")

    # Conflict resolution: Never allow backend settings to silently select a missing subscription ID
    if active_sub_ids and pref_sub is not None and int(pref_sub) not in active_sub_ids:
        conflicts.append(
            f"Preferred subscription {pref_sub} is no longer present on device {did}."
        )
        if auto_fallback and sec_sub is not None and int(sec_sub) in active_sub_ids:
            pref_sub = int(sec_sub)
            pref_slot = sec_slot
            conflicts.append(f"Applied configured fallback to secondary subscription {pref_sub}.")
        else:
            pref_sub = None
            conflicts.append("Cleared unavailable preferred subscription (fallback disabled or secondary unavailable).")

    await exec_sql(
        """
        INSERT INTO public.sms_gateway_settings (
            school_id, device_id, preferred_sim_mode, preferred_subscription_id,
            preferred_sim_slot, secondary_subscription_id, secondary_sim_slot,
            auto_fallback_enabled, switch_on_unavailable, switch_on_network_error,
            switch_back_on_recover
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT (school_id, device_id) DO UPDATE SET
            preferred_sim_mode = EXCLUDED.preferred_sim_mode,
            preferred_subscription_id = EXCLUDED.preferred_subscription_id,
            preferred_sim_slot = EXCLUDED.preferred_sim_slot,
            secondary_subscription_id = EXCLUDED.secondary_subscription_id,
            secondary_sim_slot = EXCLUDED.secondary_sim_slot,
            auto_fallback_enabled = EXCLUDED.auto_fallback_enabled,
            switch_on_unavailable = EXCLUDED.switch_on_unavailable,
            switch_on_network_error = EXCLUDED.switch_on_network_error,
            switch_back_on_recover = EXCLUDED.switch_back_on_recover,
            updated_at = NOW()
        """,
        (
            school_id,
            did,
            pref_mode,
            pref_sub,
            pref_slot,
            sec_sub,
            sec_slot,
            auto_fallback,
            payload.switch_on_unavailable if payload.switch_on_unavailable is not None else current_cfg.get("switch_on_unavailable", True),
            payload.switch_on_network_error if payload.switch_on_network_error is not None else current_cfg.get("switch_on_network_error", False),
            payload.switch_back_on_recover if payload.switch_back_on_recover is not None else current_cfg.get("switch_back_on_recover", True),
        ),
        fetch=False,
    )

    if conflicts:
        await record_gateway_event(
            school_id=school_id,
            event_type="SIM_CHANGED",
            title="SIM Configuration Revalidated",
            description=" ".join(conflicts),
            device_id=did,
            subscription_id=pref_sub,
            sim_slot=pref_slot,
        )

    updated = await _get_or_init_settings(school_id, did)
    sims_rows = await exec_sql(
        "SELECT * FROM public.sms_gateway_sims WHERE device_id = %s ORDER BY sim_slot_index ASC",
        (did,),
    )
    return {
        "success": True,
        "conflicts": conflicts,
        "configuration": updated,
        "sims": serialize_rows(sims_rows),
    }


@router.get("/device/configuration")
async def get_device_configuration(request: Request, device_id: Optional[str] = None):
    did = resolve_device_id(request, device_id)
    school_id = await resolve_school_id(request, x_device_id=did)
    cfg = await _get_or_init_settings(school_id, did)
    sims = await exec_sql(
        "SELECT * FROM public.sms_gateway_sims WHERE device_id = %s ORDER BY sim_slot_index ASC",
        (did,),
    )
    device = await exec_sql(
        "SELECT * FROM public.sms_gateway_devices WHERE device_id = %s LIMIT 1",
        (did,),
    )
    return {
        "device_id": did,
        "device": serialize_rows(device)[0] if device else None,
        "configuration": cfg,
        "sims": serialize_rows(sims),
    }


@router.put("/device/configuration")
async def update_device_configuration(payload: GatewayConfigurationUpdateRequest, request: Request):
    did = resolve_device_id(request, payload.device_id)
    school_id = await resolve_school_id(request, x_device_id=did)
    current = await _get_or_init_settings(school_id, did)

    await exec_sql(
        """
        INSERT INTO public.sms_gateway_settings (
            school_id, device_id, automated_messaging_enabled,
            incoming_forwarding_enabled, queue_sync_enabled,
            scheduled_processing_enabled, polling_interval_seconds,
            message_expiration_seconds, retention_days, emergency_disabled, server_url
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT (school_id, device_id) DO UPDATE SET
            automated_messaging_enabled = EXCLUDED.automated_messaging_enabled,
            incoming_forwarding_enabled = EXCLUDED.incoming_forwarding_enabled,
            queue_sync_enabled = EXCLUDED.queue_sync_enabled,
            scheduled_processing_enabled = EXCLUDED.scheduled_processing_enabled,
            polling_interval_seconds = EXCLUDED.polling_interval_seconds,
            message_expiration_seconds = EXCLUDED.message_expiration_seconds,
            retention_days = EXCLUDED.retention_days,
            emergency_disabled = EXCLUDED.emergency_disabled,
            server_url = EXCLUDED.server_url,
            updated_at = NOW()
        """,
        (
            school_id,
            did,
            payload.automated_messaging_enabled if payload.automated_messaging_enabled is not None else current.get("automated_messaging_enabled", True),
            payload.incoming_forwarding_enabled if payload.incoming_forwarding_enabled is not None else current.get("incoming_forwarding_enabled", True),
            payload.queue_sync_enabled if payload.queue_sync_enabled is not None else current.get("queue_sync_enabled", True),
            payload.scheduled_processing_enabled if payload.scheduled_processing_enabled is not None else current.get("scheduled_processing_enabled", True),
            payload.polling_interval_seconds if payload.polling_interval_seconds is not None else current.get("polling_interval_seconds", 15),
            payload.message_expiration_seconds if payload.message_expiration_seconds is not None else current.get("message_expiration_seconds", 86400),
            payload.retention_days if payload.retention_days is not None else current.get("retention_days", 90),
            payload.emergency_disabled if payload.emergency_disabled is not None else current.get("emergency_disabled", False),
            payload.server_url or current.get("server_url", "https://eduapi.shamiit.com"),
        ),
        fetch=False,
    )
    return {"success": True, "configuration": await _get_or_init_settings(school_id, did)}


# ============================================================================
# JOB LEASING, EVENTS, INBOUND & SYNC
# ============================================================================
@router.get("/device/jobs")
async def get_device_jobs(
    request: Request,
    device_id: Optional[str] = None,
    limit: int = Query(10, ge=1, le=50),
    lease_seconds: int = Query(120, ge=30, le=600),
):
    did = resolve_device_id(request, device_id)
    school_id = await resolve_school_id(request, x_device_id=did)
    cfg = await _get_or_init_settings(school_id, did)

    if cfg.get("emergency_disabled"):
        return {"jobs": [], "emergency_disabled": True}

    # Expire stale jobs past expires_at and release expired leases back to QUEUED
    await exec_sql(
        """
        UPDATE public.sms_gateway_messages
        SET status = 'EXPIRED', failure_reason = 'Message expired before dispatch', updated_at = NOW()
        WHERE school_id = %s
          AND status IN ('QUEUED', 'SCHEDULED')
          AND expires_at IS NOT NULL
          AND expires_at < NOW()
        """,
        (school_id,),
        fetch=False,
    )

    lease_token = f"lease-{uuid.uuid4().hex}"

    def _lease_jobs():
        conn = psycopg2.connect(settings.DATABASE_URL, connect_timeout=5)
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(
                    """
                    WITH candidate AS (
                        SELECT id
                        FROM public.sms_gateway_messages
                        WHERE school_id = %s
                          AND direction = 'OUTBOUND'
                          AND (
                              status = 'QUEUED'
                              OR (status = 'SCHEDULED' AND scheduled_at IS NOT NULL AND scheduled_at <= NOW())
                              OR (status = 'LEASED' AND leased_until IS NOT NULL AND leased_until < NOW())
                          )
                          AND (device_id IS NULL OR device_id = '' OR device_id = %s)
                        ORDER BY
                            CASE priority
                                WHEN 'URGENT' THEN 1
                                WHEN 'HIGH' THEN 2
                                WHEN 'NORMAL' THEN 3
                                ELSE 4
                            END,
                            created_at ASC
                        LIMIT %s
                        FOR UPDATE SKIP LOCKED
                    )
                    UPDATE public.sms_gateway_messages m
                    SET status = 'LEASED',
                        device_id = %s,
                        lease_token = %s,
                        leased_until = NOW() + (%s || ' seconds')::interval,
                        updated_at = NOW()
                    FROM candidate
                    WHERE m.id = candidate.id
                    RETURNING m.*;
                    """,
                    (school_id, did, limit, did, lease_token, str(lease_seconds)),
                )
                rows = cur.fetchall()
                conn.commit()
                return [dict(r) for r in rows]
        except Exception as exc:
            conn.rollback()
            raise exc
        finally:
            conn.close()

    jobs = await asyncio.to_thread(_lease_jobs)
    return {"jobs": serialize_rows(jobs), "lease_token": lease_token, "device_id": did}


@router.post("/device/events")
async def ingest_device_events(payload: DeviceEventsBatchRequest, request: Request):
    school_id = await resolve_school_id(request, x_device_id=payload.device_id)
    processed = 0

    for ev in payload.events:
        processed += 1
        etype = ev.event_type.upper()
        if ev.message_uuid:
            if etype == "SMS_SUBMITTED":
                await exec_sql(
                    """
                    UPDATE public.sms_gateway_messages
                    SET status = CASE WHEN status IN ('SENT', 'DELIVERED') THEN status ELSE 'SENDING' END,
                        submitted_at = COALESCE(submitted_at, NOW()),
                        sending_sim_slot = COALESCE(%s, sending_sim_slot),
                        sending_subscription_id = COALESCE(%s, sending_subscription_id),
                        carrier_name = COALESCE(%s, carrier_name),
                        part_statuses = COALESCE(%s::jsonb, part_statuses),
                        updated_at = NOW()
                    WHERE message_uuid = %s
                    """,
                    (
                        ev.sim_slot,
                        ev.subscription_id,
                        ev.carrier_name,
                        json.dumps(ev.part_statuses) if ev.part_statuses is not None else None,
                        ev.message_uuid,
                    ),
                    fetch=False,
                )
            elif etype == "SMS_SENT":
                await exec_sql(
                    """
                    UPDATE public.sms_gateway_messages
                    SET status = CASE WHEN status = 'DELIVERED' THEN 'DELIVERED' ELSE 'SENT' END,
                        submitted_at = COALESCE(submitted_at, NOW()),
                        sending_sim_slot = COALESCE(%s, sending_sim_slot),
                        sending_subscription_id = COALESCE(%s, sending_subscription_id),
                        carrier_name = COALESCE(%s, carrier_name),
                        part_statuses = COALESCE(%s::jsonb, part_statuses),
                        updated_at = NOW()
                    WHERE message_uuid = %s
                    """,
                    (
                        ev.sim_slot,
                        ev.subscription_id,
                        ev.carrier_name,
                        json.dumps(ev.part_statuses) if ev.part_statuses is not None else None,
                        ev.message_uuid,
                    ),
                    fetch=False,
                )
                if ev.subscription_id is not None:
                    await exec_sql(
                        "UPDATE public.sms_gateway_sims SET sent_count = sent_count + 1 WHERE device_id = %s AND subscription_id = %s",
                        (payload.device_id, ev.subscription_id),
                        fetch=False,
                    )
            elif etype == "SMS_DELIVERED":
                await exec_sql(
                    """
                    UPDATE public.sms_gateway_messages
                    SET status = 'DELIVERED',
                        delivered_at = NOW(),
                        part_statuses = COALESCE(%s::jsonb, part_statuses),
                        updated_at = NOW()
                    WHERE message_uuid = %s
                    """,
                    (
                        json.dumps(ev.part_statuses) if ev.part_statuses is not None else None,
                        ev.message_uuid,
                    ),
                    fetch=False,
                )
            elif etype == "SMS_FAILED":
                await exec_sql(
                    """
                    UPDATE public.sms_gateway_messages
                    SET status = 'FAILED',
                        failure_reason = COALESCE(%s, failure_reason),
                        retry_count = COALESCE(%s, retry_count + 1),
                        part_statuses = COALESCE(%s::jsonb, part_statuses),
                        updated_at = NOW()
                    WHERE message_uuid = %s
                    """,
                    (
                        ev.failure_reason or ev.description,
                        ev.retry_count,
                        json.dumps(ev.part_statuses) if ev.part_statuses is not None else None,
                        ev.message_uuid,
                    ),
                    fetch=False,
                )
                if ev.subscription_id is not None:
                    await exec_sql(
                        "UPDATE public.sms_gateway_sims SET failed_count = failed_count + 1 WHERE device_id = %s AND subscription_id = %s",
                        (payload.device_id, ev.subscription_id),
                        fetch=False,
                    )

        await record_gateway_event(
            school_id=school_id,
            event_type=etype,
            title=ev.title or f"{etype} ({ev.message_uuid or payload.device_id})",
            description=ev.description or ev.failure_reason,
            device_id=payload.device_id,
            message_uuid=ev.message_uuid,
            sim_slot=ev.sim_slot,
            subscription_id=ev.subscription_id,
            event_uuid=ev.event_uuid,
            event_timestamp=ev.event_timestamp,
        )

    return {"success": True, "processed": processed}


@router.post("/device/inbound")
async def ingest_inbound_sms(
    payload: InboundSmsRequest,
    request: Request,
    background_tasks: BackgroundTasks,
):
    school_id = await resolve_school_id(request, x_device_id=payload.device_id)
    msg_uuid = payload.message_uuid or f"in-{uuid.uuid4().hex}"
    enc = analyze_sms_encoding(payload.message_body)
    recv_ts = payload.received_at or datetime.now(timezone.utc).isoformat()

    inserted = await exec_sql(
        """
        INSERT INTO public.sms_gateway_messages (
            school_id, message_uuid, device_id, direction,
            sender_number, recipient_number, message_body,
            encoding, segment_count, receiving_sim_slot,
            receiving_subscription_id, carrier_name, application_source,
            status, received_at, sync_status
        ) VALUES (
            %s, %s, %s, 'INBOUND',
            %s, %s, %s,
            %s, %s, %s,
            %s, %s, 'Incoming Network SMS',
            'RECEIVED', %s::timestamptz, 'SYNCED'
        )
        ON CONFLICT (message_uuid) DO NOTHING
        RETURNING id
        """,
        (
            school_id,
            msg_uuid,
            payload.device_id,
            payload.sender_number,
            payload.recipient_number or "Device SIM",
            payload.message_body,
            enc["encoding"],
            enc["segment_count"],
            payload.receiving_sim_slot,
            payload.receiving_subscription_id,
            payload.carrier_name,
            recv_ts,
        ),
    )

    if inserted:
        if payload.receiving_subscription_id is not None:
            await exec_sql(
                "UPDATE public.sms_gateway_sims SET received_count = received_count + 1 WHERE device_id = %s AND subscription_id = %s",
                (payload.device_id, payload.receiving_subscription_id),
                fetch=False,
            )

        await record_gateway_event(
            school_id=school_id,
            event_type="SMS_RECEIVED",
            title=f"SMS Received from {payload.sender_number}",
            description=payload.message_body[:120],
            device_id=payload.device_id,
            message_uuid=msg_uuid,
            sim_slot=payload.receiving_sim_slot,
            subscription_id=payload.receiving_subscription_id,
            application_source="Incoming Network SMS",
        )

        # Evaluate active INCOMING_SMS forwarding rules
        cfg = await _get_or_init_settings(school_id, payload.device_id)
        if cfg.get("incoming_forwarding_enabled", True):
            rules = await exec_sql(
                """
                SELECT * FROM public.sms_gateway_automation_rules
                WHERE school_id = %s AND is_active = TRUE
                  AND UPPER(trigger_event) IN ('INCOMING_SMS', 'INCOMING SMS')
                  AND webhook_url IS NOT NULL AND webhook_url != ''
                """,
                (school_id,),
            )
            for r in rules:
                await exec_sql(
                    "UPDATE public.sms_gateway_automation_rules SET execution_count = execution_count + 1, last_triggered_at = NOW() WHERE id = %s",
                    (r["id"],),
                    fetch=False,
                )
                background_tasks.add_task(
                    forward_webhook_async,
                    r["webhook_url"],
                    {
                        "message_uuid": msg_uuid,
                        "sender_number": payload.sender_number,
                        "message_body": payload.message_body,
                        "sim_slot": payload.receiving_sim_slot,
                        "subscription_id": payload.receiving_subscription_id,
                        "received_at": recv_ts,
                        "device_id": payload.device_id,
                    },
                    str(r["id"]),
                    school_id,
                )

    return {"success": True, "message_uuid": msg_uuid, "duplicate": len(inserted) == 0}


@router.post("/device/sync")
async def device_sync(payload: DeviceSyncRequest, request: Request, background_tasks: BackgroundTasks):
    school_id = await resolve_school_id(request, x_device_id=payload.device_id)
    synced_inbound = 0
    synced_events = 0
    synced_outbound = 0

    if payload.sims is not None:
        await sync_sim_configuration(
            SimConfigurationUpdateRequest(device_id=payload.device_id, sims=payload.sims),
            request,
        )

    if payload.inbound_messages:
        for inb in payload.inbound_messages:
            await ingest_inbound_sms(inb, request, background_tasks)
            synced_inbound += 1

    if payload.outbound_messages:
        for msg in payload.outbound_messages:
            muid = msg.get("message_uuid") or f"out-{uuid.uuid4().hex}"
            body = msg.get("message_body", "")
            enc = analyze_sms_encoding(body)
            await exec_sql(
                """
                INSERT INTO public.sms_gateway_messages (
                    school_id, message_uuid, device_id, direction,
                    sender_number, recipient_number, message_body,
                    encoding, segment_count, sending_sim_slot, sending_subscription_id,
                    carrier_name, application_source, reference_id, priority, status,
                    delivery_report_requested, queued_at, submitted_at, delivered_at,
                    retry_count, failure_reason, sync_status, part_statuses
                ) VALUES (
                    %s, %s, %s, 'OUTBOUND',
                    %s, %s, %s,
                    %s, %s, %s, %s,
                    %s, %s, %s, %s, %s,
                    %s, COALESCE(%s::timestamptz, NOW()), %s::timestamptz, %s::timestamptz,
                    %s, %s, 'SYNCED', %s::jsonb
                )
                ON CONFLICT (message_uuid) DO UPDATE SET
                    status = EXCLUDED.status,
                    submitted_at = COALESCE(EXCLUDED.submitted_at, public.sms_gateway_messages.submitted_at),
                    delivered_at = COALESCE(EXCLUDED.delivered_at, public.sms_gateway_messages.delivered_at),
                    retry_count = GREATEST(public.sms_gateway_messages.retry_count, EXCLUDED.retry_count),
                    failure_reason = COALESCE(EXCLUDED.failure_reason, public.sms_gateway_messages.failure_reason),
                    part_statuses = EXCLUDED.part_statuses,
                    sync_status = 'SYNCED',
                    updated_at = NOW()
                """,
                (
                    school_id,
                    muid,
                    payload.device_id,
                    msg.get("sender_number"),
                    msg.get("recipient_number", ""),
                    body,
                    msg.get("encoding") or enc["encoding"],
                    msg.get("segment_count") or enc["segment_count"],
                    msg.get("sending_sim_slot"),
                    msg.get("sending_subscription_id"),
                    msg.get("carrier_name"),
                    msg.get("application_source") or "SMS Gateway App",
                    msg.get("reference_id"),
                    msg.get("priority") or "NORMAL",
                    msg.get("status") or "QUEUED",
                    bool(msg.get("delivery_report_requested", True)),
                    msg.get("queued_at"),
                    msg.get("submitted_at"),
                    msg.get("delivered_at"),
                    int(msg.get("retry_count", 0)),
                    msg.get("failure_reason"),
                    json.dumps(msg.get("part_statuses") or []),
                ),
                fetch=False,
            )
            synced_outbound += 1

    if payload.events:
        res = await ingest_device_events(
            DeviceEventsBatchRequest(device_id=payload.device_id, events=payload.events),
            request,
        )
        synced_events = res["processed"]

    await exec_sql(
        "UPDATE public.sms_gateway_devices SET last_sync_at = NOW(), is_online = TRUE WHERE device_id = %s",
        (payload.device_id,),
        fetch=False,
    )
    await record_gateway_event(
        school_id=school_id,
        event_type="BACKEND_SYNCED",
        title="Backend synchronization completed",
        description=f"Inbound: {synced_inbound}, Outbound: {synced_outbound}, Events: {synced_events}",
        device_id=payload.device_id,
    )

    return {
        "success": True,
        "synced_inbound": synced_inbound,
        "synced_outbound": synced_outbound,
        "synced_events": synced_events,
        "synced_at": datetime.now(timezone.utc).isoformat(),
    }


# ============================================================================
# SMS SUBMISSION, HISTORY, DETAILS & STATISTICS
# ============================================================================
@router.post("/sms/send")
async def send_sms(payload: SendSmsRequest, request: Request):
    school_id = await resolve_school_id(request, x_device_id=payload.device_id)
    if not payload.recipients:
        raise HTTPException(status_code=400, detail="At least one recipient is required")

    message_body = payload.message_body
    if payload.template_id:
        tpl_rows = await exec_sql(
            "SELECT * FROM public.sms_gateway_templates WHERE id = %s AND school_id = %s LIMIT 1",
            (payload.template_id, school_id),
        )
        if not tpl_rows:
            raise HTTPException(status_code=404, detail="Template not found")
        tpl = tpl_rows[0]
        message_body = render_template_strict(
            tpl["message_body"],
            payload.template_variables or {},
            tpl.get("required_variables") or [],
        )

    if not message_body or not message_body.strip():
        raise HTTPException(status_code=400, detail="Message body cannot be empty")

    normalized_recipients = [normalize_phone_number(r) for r in payload.recipients]
    enc = analyze_sms_encoding(message_body)
    is_scheduled = bool(payload.scheduled_at and payload.scheduled_at.strip())
    initial_status = "SCHEDULED" if is_scheduled else "QUEUED"

    carrier_name = None
    if payload.subscription_id is not None:
        sim_rows = await exec_sql(
            "SELECT carrier_name, sim_slot_index, usage_mode, is_active FROM public.sms_gateway_sims WHERE subscription_id = %s AND school_id = %s LIMIT 1",
            (payload.subscription_id, school_id),
        )
        if sim_rows:
            if not sim_rows[0]["is_active"]:
                raise HTTPException(status_code=400, detail="Selected SIM subscription is currently unavailable")
            if sim_rows[0]["usage_mode"] == "RECEIVE_ONLY":
                raise HTTPException(status_code=400, detail="Selected SIM is configured as Receive Only")
            carrier_name = sim_rows[0]["carrier_name"]
            if payload.sim_slot is None:
                payload.sim_slot = sim_rows[0]["sim_slot_index"]

    created_messages = []
    for idx, recipient in enumerate(normalized_recipients):
        muid = (
            payload.client_message_uuids[idx]
            if payload.client_message_uuids and idx < len(payload.client_message_uuids)
            else f"msg-{uuid.uuid4().hex}"
        )
        rows = await exec_sql(
            """
            INSERT INTO public.sms_gateway_messages (
                school_id, message_uuid, device_id, direction,
                recipient_number, message_body, encoding, segment_count,
                sending_sim_slot, sending_subscription_id, carrier_name,
                application_source, reference_id, template_id, priority,
                status, delivery_report_requested, scheduled_at, expires_at
            ) VALUES (
                %s, %s, %s, 'OUTBOUND',
                %s, %s, %s, %s,
                %s, %s, %s,
                %s, %s, %s, %s,
                %s, %s, %s::timestamptz, %s::timestamptz
            )
            ON CONFLICT (message_uuid) DO UPDATE SET updated_at = NOW()
            RETURNING *
            """,
            (
                school_id,
                muid,
                payload.device_id,
                recipient,
                message_body,
                enc["encoding"],
                enc["segment_count"],
                payload.sim_slot,
                payload.subscription_id,
                carrier_name,
                payload.application_source,
                payload.reference_id,
                payload.template_id,
                payload.priority.upper(),
                initial_status,
                payload.delivery_report_requested,
                payload.scheduled_at if is_scheduled else None,
                payload.expires_at,
            ),
        )
        created_messages.extend(serialize_rows(rows))
        await record_gateway_event(
            school_id=school_id,
            event_type="SMS_SUBMITTED",
            title=f"SMS {initial_status.title()} to {recipient}",
            description=message_body[:100],
            device_id=payload.device_id,
            message_uuid=muid,
            sim_slot=payload.sim_slot,
            subscription_id=payload.subscription_id,
            application_source=payload.application_source,
        )

    return {
        "success": True,
        "count": len(created_messages),
        "status": initial_status,
        "encoding": enc,
        "messages": created_messages,
    }


@router.get("/sms/history")
async def get_sms_history(
    request: Request,
    status: Optional[str] = None,
    direction: Optional[str] = None,
    sim_slot: Optional[int] = None,
    application: Optional[str] = None,
    search: Optional[str] = None,
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    limit: int = Query(50, ge=1, le=500),
    offset: int = Query(0, ge=0),
):
    school_id = await resolve_school_id(request)
    clauses = ["school_id = %s"]
    params: List[Any] = [school_id]

    if status and status.upper() != "ALL":
        clauses.append("UPPER(status) = %s")
        params.append(status.upper())
    if direction and direction.upper() != "ALL":
        clauses.append("UPPER(direction) = %s")
        params.append(direction.upper())
    if sim_slot is not None:
        clauses.append("(sending_sim_slot = %s OR receiving_sim_slot = %s)")
        params.extend([sim_slot, sim_slot])
    if application and application.upper() != "ALL":
        clauses.append("application_source ILIKE %s")
        params.append(f"%{application}%")
    if search and search.strip():
        q = f"%{search.strip()}%"
        clauses.append(
            "(recipient_number ILIKE %s OR sender_number ILIKE %s OR message_body ILIKE %s OR message_uuid ILIKE %s OR application_source ILIKE %s OR COALESCE(reference_id, '') ILIKE %s)"
        )
        params.extend([q, q, q, q, q, q])
    if start_date:
        clauses.append("created_at >= %s::timestamptz")
        params.append(start_date)
    if end_date:
        clauses.append("created_at <= %s::timestamptz")
        params.append(end_date)

    where_sql = " AND ".join(clauses)
    total_rows = await exec_sql(
        f"SELECT COUNT(*) AS cnt FROM public.sms_gateway_messages WHERE {where_sql}",
        tuple(params),
    )
    items = await exec_sql(
        f"""
        SELECT * FROM public.sms_gateway_messages
        WHERE {where_sql}
        ORDER BY created_at DESC
        LIMIT %s OFFSET %s
        """,
        tuple(params + [limit, offset]),
    )
    return {
        "total": int(total_rows[0]["cnt"]) if total_rows else 0,
        "items": serialize_rows(items),
        "limit": limit,
        "offset": offset,
    }


@router.get("/sms/messages/{message_uuid}")
async def get_message_detail(message_uuid: str, request: Request):
    school_id = await resolve_school_id(request)
    rows = await exec_sql(
        "SELECT * FROM public.sms_gateway_messages WHERE message_uuid = %s AND school_id = %s LIMIT 1",
        (message_uuid, school_id),
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Message not found")
    events = await exec_sql(
        "SELECT * FROM public.sms_gateway_events WHERE message_uuid = %s ORDER BY event_timestamp DESC",
        (message_uuid,),
    )
    return {
        "message": serialize_rows(rows)[0],
        "events": serialize_rows(events),
    }


@router.get("/sms/statistics")
async def get_sms_statistics(
    request: Request,
    timeframe: str = Query("24h"),
    device_id: Optional[str] = None,
):
    did = resolve_device_id(request, device_id)
    school_id = await resolve_school_id(request, x_device_id=did)

    today_stats = await exec_sql(
        """
        SELECT
            COUNT(*) FILTER (WHERE direction = 'OUTBOUND' AND status IN ('SENT', 'DELIVERED') AND created_at >= DATE_TRUNC('day', NOW())) AS sent_today,
            COUNT(*) FILTER (WHERE direction = 'INBOUND' AND created_at >= DATE_TRUNC('day', NOW())) AS received_today,
            COUNT(*) FILTER (WHERE direction = 'OUTBOUND' AND status = 'DELIVERED' AND created_at >= DATE_TRUNC('day', NOW())) AS delivered_today,
            COUNT(*) FILTER (WHERE direction = 'OUTBOUND' AND status = 'FAILED' AND created_at >= DATE_TRUNC('day', NOW())) AS failed_today,
            COUNT(*) FILTER (WHERE status IN ('QUEUED', 'LEASED', 'SENDING')) AS queue_size,
            COUNT(*) FILTER (WHERE status = 'SCHEDULED') AS scheduled_count,
            COUNT(*) AS total_messages
        FROM public.sms_gateway_messages
        WHERE school_id = %s
        """,
        (school_id,),
    )
    s = today_stats[0] if today_stats else {}
    sent_today = int(s.get("sent_today") or 0)
    delivered_today = int(s.get("delivered_today") or 0)
    failed_today = int(s.get("failed_today") or 0)
    denom = delivered_today + failed_today
    delivery_rate = round((delivered_today / denom) * 100.0, 1) if denom > 0 else (100.0 if sent_today > 0 and failed_today == 0 else 0.0)

    # Hourly activity (last 24h)
    hourly = await exec_sql(
        """
        SELECT
            TO_CHAR(DATE_TRUNC('hour', created_at), 'HH24:00') AS label,
            DATE_TRUNC('hour', created_at) AS bucket,
            COUNT(*) FILTER (WHERE direction = 'OUTBOUND' AND status IN ('SENT', 'DELIVERED')) AS sent,
            COUNT(*) FILTER (WHERE direction = 'INBOUND') AS received,
            COUNT(*) FILTER (WHERE status = 'DELIVERED') AS delivered,
            COUNT(*) FILTER (WHERE status = 'FAILED') AS failed
        FROM public.sms_gateway_messages
        WHERE school_id = %s AND created_at >= NOW() - INTERVAL '24 hours'
        GROUP BY DATE_TRUNC('hour', created_at)
        ORDER BY bucket ASC
        """,
        (school_id,),
    )

    app_usage = await exec_sql(
        """
        SELECT application_source, COUNT(*) AS count
        FROM public.sms_gateway_messages
        WHERE school_id = %s
        GROUP BY application_source
        ORDER BY count DESC
        LIMIT 8
        """,
        (school_id,),
    )

    sim_usage = await exec_sql(
        """
        SELECT
            COALESCE(sending_sim_slot, receiving_sim_slot, 0) AS sim_slot,
            COALESCE(MAX(carrier_name), 'SIM ' || (COALESCE(sending_sim_slot, receiving_sim_slot, 0) + 1)) AS carrier_name,
            COUNT(*) AS total,
            COUNT(*) FILTER (WHERE direction = 'OUTBOUND') AS sent,
            COUNT(*) FILTER (WHERE direction = 'INBOUND') AS received
        FROM public.sms_gateway_messages
        WHERE school_id = %s
          AND COALESCE(sending_sim_slot, receiving_sim_slot) IS NOT NULL
        GROUP BY COALESCE(sending_sim_slot, receiving_sim_slot, 0)
        ORDER BY sim_slot ASC
        """,
        (school_id,),
    )

    recent_events = await exec_sql(
        """
        SELECT * FROM public.sms_gateway_events
        WHERE school_id = %s
        ORDER BY event_timestamp DESC
        LIMIT 25
        """,
        (school_id,),
    )

    devices = await exec_sql(
        """
        SELECT * FROM public.sms_gateway_devices
        WHERE school_id = %s AND (%s = 'DEFAULT' OR device_id = %s)
        ORDER BY last_heartbeat_at DESC NULLS LAST
        LIMIT 1
        """,
        (school_id, did, did),
    )

    return {
        "sent_today": sent_today,
        "received_today": int(s.get("received_today") or 0),
        "delivered_today": delivered_today,
        "failed_today": failed_today,
        "queue_size": int(s.get("queue_size") or 0),
        "scheduled_count": int(s.get("scheduled_count") or 0),
        "total_messages": int(s.get("total_messages") or 0),
        "delivery_rate": delivery_rate,
        "hourly_activity": serialize_rows(hourly),
        "app_usage": serialize_rows(app_usage),
        "sim_usage": serialize_rows(sim_usage),
        "recent_events": serialize_rows(recent_events),
        "active_device": serialize_rows(devices)[0] if devices else None,
        "timeframe": timeframe,
    }


# ============================================================================
# AUTOMATION RULES & APPLICATION TRIGGERS
# ============================================================================
@router.get("/automation/rules")
async def list_automation_rules(request: Request):
    school_id = await resolve_school_id(request)
    rows = await exec_sql(
        """
        SELECT * FROM public.sms_gateway_automation_rules
        WHERE school_id = %s
        ORDER BY created_at DESC
        """,
        (school_id,),
    )
    return {"items": serialize_rows(rows)}


@router.post("/automation/rules")
async def create_automation_rule(payload: AutomationRuleRequest, request: Request):
    school_id = await resolve_school_id(request)
    rows = await exec_sql(
        """
        INSERT INTO public.sms_gateway_automation_rules (
            school_id, rule_name, application_name, trigger_event,
            recipient_mapping, template_id, message_template,
            preferred_sim_slot, preferred_subscription_id,
            priority, is_active, schedule_restriction, webhook_url
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s::jsonb, %s)
        RETURNING *
        """,
        (
            school_id,
            payload.rule_name,
            payload.application_name,
            payload.trigger_event,
            payload.recipient_mapping,
            payload.template_id,
            payload.message_template,
            payload.preferred_sim_slot,
            payload.preferred_subscription_id,
            payload.priority.upper(),
            payload.is_active,
            json.dumps(payload.schedule_restriction or {}),
            payload.webhook_url,
        ),
    )
    return {"success": True, "rule": serialize_rows(rows)[0]}


@router.put("/automation/rules/{rule_id}")
async def update_automation_rule(rule_id: str, payload: AutomationRuleRequest, request: Request):
    school_id = await resolve_school_id(request)
    rows = await exec_sql(
        """
        UPDATE public.sms_gateway_automation_rules
        SET rule_name = %s,
            application_name = %s,
            trigger_event = %s,
            recipient_mapping = %s,
            template_id = %s,
            message_template = %s,
            preferred_sim_slot = %s,
            preferred_subscription_id = %s,
            priority = %s,
            is_active = %s,
            schedule_restriction = %s::jsonb,
            webhook_url = %s,
            updated_at = NOW()
        WHERE id = %s AND school_id = %s
        RETURNING *
        """,
        (
            payload.rule_name,
            payload.application_name,
            payload.trigger_event,
            payload.recipient_mapping,
            payload.template_id,
            payload.message_template,
            payload.preferred_sim_slot,
            payload.preferred_subscription_id,
            payload.priority.upper(),
            payload.is_active,
            json.dumps(payload.schedule_restriction or {}),
            payload.webhook_url,
            rule_id,
            school_id,
        ),
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Automation rule not found")
    return {"success": True, "rule": serialize_rows(rows)[0]}


@router.delete("/automation/rules/{rule_id}")
async def delete_automation_rule(rule_id: str, request: Request):
    school_id = await resolve_school_id(request)
    rows = await exec_sql(
        "DELETE FROM public.sms_gateway_automation_rules WHERE id = %s AND school_id = %s RETURNING id",
        (rule_id, school_id),
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Automation rule not found")
    return {"success": True}


@router.post("/automation/rules/{rule_id}/duplicate")
async def duplicate_automation_rule(rule_id: str, request: Request):
    school_id = await resolve_school_id(request)
    rows = await exec_sql(
        """
        INSERT INTO public.sms_gateway_automation_rules (
            school_id, rule_name, application_name, trigger_event,
            recipient_mapping, template_id, message_template,
            preferred_sim_slot, preferred_subscription_id,
            priority, is_active, schedule_restriction, webhook_url
        )
        SELECT school_id, rule_name || ' (Copy)', application_name, trigger_event,
               recipient_mapping, template_id, message_template,
               preferred_sim_slot, preferred_subscription_id,
               priority, FALSE, schedule_restriction, webhook_url
        FROM public.sms_gateway_automation_rules
        WHERE id = %s AND school_id = %s
        RETURNING *
        """,
        (rule_id, school_id),
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Automation rule not found")
    return {"success": True, "rule": serialize_rows(rows)[0]}


@router.get("/automation/rules/{rule_id}/executions")
async def get_rule_executions(rule_id: str, request: Request):
    school_id = await resolve_school_id(request)
    rows = await exec_sql(
        """
        SELECT * FROM public.sms_gateway_rule_executions
        WHERE rule_id = %s AND school_id = %s
        ORDER BY executed_at DESC
        LIMIT 100
        """,
        (rule_id, school_id),
    )
    return {"items": serialize_rows(rows)}


@router.post("/automation/rules/{rule_id}/test")
async def test_automation_rule(rule_id: str, request: Request, body: Dict[str, Any] = None):
    school_id = await resolve_school_id(request)
    rows = await exec_sql(
        "SELECT * FROM public.sms_gateway_automation_rules WHERE id = %s AND school_id = %s LIMIT 1",
        (rule_id, school_id),
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Automation rule not found")
    rule = rows[0]
    variables = (body or {}).get("variables", {})
    rendered = render_template_strict(rule["message_template"], variables)
    recipient = (body or {}).get("recipient_number")
    if recipient:
        recipient = normalize_phone_number(recipient)
        send_res = await send_sms(
            SendSmsRequest(
                recipients=[recipient],
                message_body=rendered,
                sim_slot=rule.get("preferred_sim_slot"),
                subscription_id=rule.get("preferred_subscription_id"),
                priority=rule.get("priority", "NORMAL"),
                application_source=rule["application_name"],
                reference_id=f"rule-test-{rule_id}",
            ),
            request,
        )
        msg_uuid = send_res["messages"][0]["message_uuid"]
    else:
        msg_uuid = None

    await exec_sql(
        """
        INSERT INTO public.sms_gateway_rule_executions (
            school_id, rule_id, message_uuid, recipient_number, status, payload
        ) VALUES (%s, %s, %s, %s, %s, %s::jsonb)
        """,
        (
            school_id,
            rule_id,
            msg_uuid,
            recipient,
            "TEST_QUEUED" if msg_uuid else "DRY_RUN_OK",
            json.dumps({"rendered": rendered}),
        ),
        fetch=False,
    )
    return {"success": True, "rendered_message": rendered, "message_uuid": msg_uuid}


@router.post("/automation/trigger")
async def trigger_automation_event(payload: TriggerAutomationRequest, request: Request):
    school_id = await resolve_school_id(request)
    rules = await exec_sql(
        """
        SELECT * FROM public.sms_gateway_automation_rules
        WHERE school_id = %s
          AND is_active = TRUE
          AND LOWER(application_name) = LOWER(%s)
          AND LOWER(trigger_event) = LOWER(%s)
        """,
        (school_id, payload.application_name, payload.trigger_event),
    )
    queued = []
    for r in rules:
        target = payload.recipient_number or payload.variables.get(r["recipient_mapping"])
        if not target:
            continue
        recipient = normalize_phone_number(str(target))
        rendered = render_template_strict(r["message_template"], payload.variables)
        send_res = await send_sms(
            SendSmsRequest(
                recipients=[recipient],
                message_body=rendered,
                sim_slot=r.get("preferred_sim_slot"),
                subscription_id=r.get("preferred_subscription_id"),
                priority=r.get("priority", "NORMAL"),
                application_source=r["application_name"],
                reference_id=payload.reference_id,
            ),
            request,
        )
        muid = send_res["messages"][0]["message_uuid"]
        queued.append(muid)
        await exec_sql(
            "UPDATE public.sms_gateway_automation_rules SET execution_count = execution_count + 1, last_triggered_at = NOW() WHERE id = %s",
            (r["id"],),
            fetch=False,
        )
        await exec_sql(
            """
            INSERT INTO public.sms_gateway_rule_executions (
                school_id, rule_id, message_uuid, recipient_number, status, payload
            ) VALUES (%s, %s, %s, %s, 'QUEUED', %s::jsonb)
            """,
            (school_id, r["id"], muid, recipient, json.dumps(payload.variables)),
            fetch=False,
        )
    return {"success": True, "rules_matched": len(rules), "queued_messages": queued}


# ============================================================================
# MESSAGE TEMPLATES
# ============================================================================
@router.get("/templates")
async def list_templates(request: Request):
    school_id = await resolve_school_id(request)
    rows = await exec_sql(
        "SELECT * FROM public.sms_gateway_templates WHERE school_id = %s ORDER BY created_at DESC",
        (school_id,),
    )
    return {"items": serialize_rows(rows)}


@router.post("/templates")
async def create_template(payload: TemplateRequest, request: Request):
    school_id = await resolve_school_id(request)
    detected_vars = sorted(set(TEMPLATE_VAR_REGEX.findall(payload.message_body)))
    req_vars = payload.required_variables if payload.required_variables is not None else detected_vars

    rows = await exec_sql(
        """
        INSERT INTO public.sms_gateway_templates (
            school_id, template_name, application_name, category,
            message_body, available_variables, required_variables,
            dlt_template_id, dlt_header, default_priority, preferred_sim_slot, is_active
        ) VALUES (%s, %s, %s, %s, %s, %s::jsonb, %s::jsonb, %s, %s, %s, %s, %s)
        RETURNING *
        """,
        (
            school_id,
            payload.template_name,
            payload.application_name,
            payload.category,
            payload.message_body,
            json.dumps(detected_vars),
            json.dumps(req_vars),
            payload.dlt_template_id,
            payload.dlt_header,
            payload.default_priority.upper(),
            payload.preferred_sim_slot,
            payload.is_active,
        ),
    )
    return {"success": True, "template": serialize_rows(rows)[0]}


@router.put("/templates/{template_id}")
async def update_template(template_id: str, payload: TemplateRequest, request: Request):
    school_id = await resolve_school_id(request)
    detected_vars = sorted(set(TEMPLATE_VAR_REGEX.findall(payload.message_body)))
    req_vars = payload.required_variables if payload.required_variables is not None else detected_vars

    rows = await exec_sql(
        """
        UPDATE public.sms_gateway_templates
        SET template_name = %s,
            application_name = %s,
            category = %s,
            message_body = %s,
            available_variables = %s::jsonb,
            required_variables = %s::jsonb,
            dlt_template_id = %s,
            dlt_header = %s,
            default_priority = %s,
            preferred_sim_slot = %s,
            is_active = %s,
            updated_at = NOW()
        WHERE id = %s AND school_id = %s
        RETURNING *
        """,
        (
            payload.template_name,
            payload.application_name,
            payload.category,
            payload.message_body,
            json.dumps(detected_vars),
            json.dumps(req_vars),
            payload.dlt_template_id,
            payload.dlt_header,
            payload.default_priority.upper(),
            payload.preferred_sim_slot,
            payload.is_active,
            template_id,
            school_id,
        ),
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Template not found")
    return {"success": True, "template": serialize_rows(rows)[0]}


@router.delete("/templates/{template_id}")
async def delete_template(template_id: str, request: Request):
    school_id = await resolve_school_id(request)
    rows = await exec_sql(
        "DELETE FROM public.sms_gateway_templates WHERE id = %s AND school_id = %s RETURNING id",
        (template_id, school_id),
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Template not found")
    return {"success": True}


# ============================================================================
# REAL-TIME WEBSOCKET ENDPOINT
# ============================================================================
@router.websocket("/sms-gateway/ws")
async def sms_gateway_websocket(websocket: WebSocket, school_id: str = DEFAULT_SCHOOL_ID):
    await ws_manager.connect(websocket, school_id)
    try:
        while True:
            data = await websocket.receive_text()
            if "PING" in data:
                await websocket.send_json({"type": "PONG", "ts": datetime.now(timezone.utc).isoformat()})
    except WebSocketDisconnect:
        ws_manager.disconnect(websocket, school_id)
    except Exception:
        ws_manager.disconnect(websocket, school_id)
