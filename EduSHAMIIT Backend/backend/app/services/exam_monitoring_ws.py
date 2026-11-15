"""
Authenticated Real-Time Exam Monitoring WebSocket Manager + Redis Pub/Sub Bridge.
Supports multi-worker Gunicorn/Uvicorn fanout across invigilators and candidates
with strict tenant, exam-access, and audience isolation.
"""
import asyncio
import json
import logging
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Set
from fastapi import WebSocket
from jose import jwt, JWTError

from app.config import settings
from app.cache.redis_client import get_redis

logger = logging.getLogger(__name__)


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def authenticate_ws_jwt(websocket: WebSocket) -> Optional[Dict[str, Any]]:
    """
    Validate Bearer token or ?token=... query parameter for WebSocket connections.
    Returns decoded user dict or None if invalid/missing.
    """
    token = None
    auth_header = websocket.headers.get("authorization") or websocket.headers.get("Authorization")
    if auth_header and auth_header.startswith("Bearer "):
        token = auth_header.split(" ", 1)[1].strip()
    if not token:
        token = websocket.query_params.get("token")
    if not token:
        return None

    jwt_secret = settings.SUPABASE_JWT_SECRET or settings.JWT_SECRET
    if not jwt_secret:
        return None

    try:
        payload = jwt.decode(
            token,
            jwt_secret,
            algorithms=["HS256"],
            options={"verify_aud": False},
        )
        user_id = payload.get("sub")
        if not user_id:
            return None

        school_id = (
            payload.get("school_id")
            or websocket.headers.get("x-school-id")
            or websocket.query_params.get("school_id")
        )
        return {
            "id": str(user_id),
            "school_id": str(school_id) if school_id else None,
            "role": str(payload.get("role") or "student"),
            "full_name": payload.get("full_name") or payload.get("name") or payload.get("email") or "User",
            "email": payload.get("email"),
        }
    except JWTError:
        return None
    except Exception:
        return None


class ExamMonitoringWSManager:
    """
    Manages WebSocket connections per exam room across invigilators and candidates,
    backed by Redis Pub/Sub for multi-worker Gunicorn delivery.
    """

    def __init__(self) -> None:
        self._invigilators: Dict[str, Dict[str, Set[WebSocket]]] = {}
        self._candidates: Dict[str, Dict[str, Set[WebSocket]]] = {}
        self._sub_tasks: Dict[str, asyncio.Task] = {}
        self._seq: int = 0
        self._lock = asyncio.Lock()

    async def _ensure_redis_subscriber(self, exam_id: str) -> None:
        async with self._lock:
            existing = self._sub_tasks.get(exam_id)
            if existing and not existing.done():
                return
            rc = get_redis()
            if not rc:
                return
            self._sub_tasks[exam_id] = asyncio.create_task(self._redis_listener(exam_id))

    async def _redis_listener(self, exam_id: str) -> None:
        channel = f"exam_monitor:{exam_id}"
        pubsub = None
        try:
            rc = get_redis()
            if not rc:
                return
            pubsub = rc.pubsub()
            await pubsub.subscribe(channel)
            async for message in pubsub.listen():
                if message.get("type") != "message":
                    continue
                raw = message.get("data")
                if not raw:
                    continue
                try:
                    envelope = json.loads(raw) if isinstance(raw, str) else raw
                except Exception:
                    continue
                await self._dispatch_local(exam_id, envelope)
        except asyncio.CancelledError:
            pass
        except Exception as exc:
            logger.debug("Redis exam_monitor listener stopped for %s: %s", exam_id, exc)
        finally:
            if pubsub is not None:
                try:
                    await pubsub.unsubscribe(channel)
                    await pubsub.close()
                except Exception:
                    pass

    async def connect_invigilator(self, exam_id: str, actor_id: str, websocket: WebSocket) -> None:
        await websocket.accept()
        canon_exam = str(exam_id).lower().strip()
        canon_actor = str(actor_id).lower().strip()
        async with self._lock:
            self._invigilators.setdefault(canon_exam, {}).setdefault(canon_actor, set()).add(websocket)
        await self._ensure_redis_subscriber(canon_exam)

    async def connect_candidate(self, exam_id: str, candidate_id: str, websocket: WebSocket) -> None:
        await websocket.accept()
        canon_exam = str(exam_id).lower().strip()
        canon_cand = str(candidate_id).lower().strip()
        async with self._lock:
            self._candidates.setdefault(canon_exam, {}).setdefault(canon_cand, set()).add(websocket)
        await self._ensure_redis_subscriber(canon_exam)

    async def disconnect(self, exam_id: str, user_id: str, websocket: WebSocket, is_invigilator: bool) -> None:
        canon_exam = str(exam_id).lower().strip()
        canon_user = str(user_id).lower().strip()
        async with self._lock:
            bucket = self._invigilators if is_invigilator else self._candidates
            room = bucket.get(canon_exam)
            if room and canon_user in room:
                room[canon_user].discard(websocket)
                if not room[canon_user]:
                    room.pop(canon_user, None)
            if room is not None and not room:
                bucket.pop(canon_exam, None)

            has_any = bool(self._invigilators.get(canon_exam)) or bool(self._candidates.get(canon_exam))
            if not has_any and canon_exam in self._sub_tasks:
                task = self._sub_tasks.pop(canon_exam)
                if not task.done():
                    task.cancel()

    async def _send_safe(self, ws: WebSocket, text_payload: str) -> bool:
        try:
            await ws.send_text(text_payload)
            return True
        except Exception:
            return False

    async def _dispatch_local(self, exam_id: str, envelope: Dict[str, Any]) -> None:
        audience = envelope.get("audience", "all")
        targets = envelope.get("target_candidate_ids")
        target_set = set(str(x).lower().strip() for x in targets) if targets else None
        payload_str = json.dumps(envelope, default=str)
        canon_exam_id = str(exam_id).lower().strip()

        stale: List[tuple] = []

        if audience in ("invigilators", "all"):
            inv_room = self._invigilators.get(canon_exam_id, {}) or self._invigilators.get(exam_id, {})
            for uid, sockets in list(inv_room.items()):
                for ws in list(sockets):
                    ok = await self._send_safe(ws, payload_str)
                    if not ok:
                        stale.append((True, uid, ws))

        if audience in ("candidates", "all"):
            cand_room = self._candidates.get(canon_exam_id, {}) or self._candidates.get(exam_id, {})
            for cid, sockets in list(cand_room.items()):
                if target_set is not None and str(cid).lower().strip() not in target_set:
                    continue
                for ws in list(sockets):
                    ok = await self._send_safe(ws, payload_str)
                    if not ok:
                        stale.append((False, cid, ws))

        for is_inv, uid, ws in stale:
            await self.disconnect(canon_exam_id, uid, ws, is_inv)

    async def broadcast(
        self,
        exam_id: str,
        event: str,
        data: Dict[str, Any],
        audience: str = "all",
        target_candidate_ids: Optional[List[str]] = None,
    ) -> None:
        self._seq += 1
        canon_exam_id = str(exam_id).lower().strip()
        envelope = {
            "seq": self._seq,
            "event": event,
            "exam_id": canon_exam_id,
            "timestamp": _now_iso(),
            "audience": audience,
            "target_candidate_ids": [str(x).lower().strip() for x in target_candidate_ids] if target_candidate_ids else None,
            "data": data,
        }

        # Dispatch locally so connected sockets get the event immediately
        await self._dispatch_local(canon_exam_id, envelope)

        rc = get_redis()
        if rc is not None:
            try:
                await rc.publish(f"exam_monitor:{canon_exam_id}", json.dumps(envelope, default=str))
            except Exception as exc:
                logger.debug("Redis publish error for %s: %s", canon_exam_id, exc)


exam_monitoring_ws_manager = ExamMonitoringWSManager()


async def handle_exam_monitoring_ws(websocket: WebSocket, exam_id: str) -> None:
    """
    Authenticated WebSocket endpoint for authorized invigilators/admins monitoring an exam.
    """
    import uuid as _uuid
    from fastapi import WebSocketDisconnect
    from app.services.supabase_client import get_supabase

    try:
        exam_uuid = str(_uuid.UUID(str(exam_id)))
    except Exception:
        await websocket.close(code=4404)
        return

    user = authenticate_ws_jwt(websocket)
    if not user:
        await websocket.close(code=4401)
        return

    school_id = user.get("school_id")
    actor_id = user.get("id")
    actor_role = user.get("role", "")

    # Verify tenant & monitoring permission through PostgreSQL _can_monitor_exam / overview RPC
    try:
        sb = get_supabase()
        rpc_res = await sb.rpc("rpc_get_exam_monitoring_overview", {
            "p_school_id": school_id,
            "p_exam_id": exam_uuid,
            "p_actor_id": actor_id,
            "p_actor_role": actor_role,
        }).aexecute()
        data = rpc_res.data
        if isinstance(data, list):
            data = data[0] if data else {}
        if not isinstance(data, dict) or data.get("success") is not True:
            code = 4404 if (isinstance(data, dict) and data.get("status") == 404) else 4403
            await websocket.close(code=code)
            return
    except Exception as exc:
        logger.warning("WS monitoring auth check failed for %s: %s", exam_uuid, exc)
        await websocket.close(code=4500)
        return

    await exam_monitoring_ws_manager.connect_invigilator(exam_uuid, actor_id, websocket)
    await websocket.send_text(json.dumps({
        "seq": 0,
        "event": "monitoring_connected",
        "exam_id": exam_uuid,
        "timestamp": _now_iso(),
        "data": {"actor_id": actor_id, "role": actor_role},
    }))

    try:
        while True:
            raw = await websocket.receive_text()
            try:
                msg = json.loads(raw)
            except Exception:
                continue
            msg_type = (msg.get("type") or msg.get("event") or "").lower()
            if msg_type == "ping":
                await websocket.send_text(json.dumps({
                    "seq": 0,
                    "event": "pong",
                    "exam_id": exam_uuid,
                    "timestamp": _now_iso(),
                    "data": {},
                }))
    except WebSocketDisconnect:
        pass
    except Exception as exc:
        logger.debug("Invigilator WS loop closed for %s: %s", exam_uuid, exc)
    finally:
        await exam_monitoring_ws_manager.disconnect(exam_uuid, actor_id, websocket, is_invigilator=True)


async def handle_exam_candidate_ws(websocket: WebSocket, exam_id: str) -> None:
    """
    Authenticated WebSocket endpoint for candidates actively taking an examination.
    Receives targeted commands, pause/resume signals, warnings, extra time updates,
    and announcements; accepts real-time telemetry and proctoring events.
    """
    import uuid as _uuid
    from fastapi import WebSocketDisconnect
    from app.services.supabase_client import get_supabase

    try:
        exam_uuid = str(_uuid.UUID(str(exam_id)))
    except Exception:
        await websocket.close(code=4404)
        return

    user = authenticate_ws_jwt(websocket)
    if not user:
        await websocket.close(code=4401)
        return

    school_id = user.get("school_id")
    candidate_id = user.get("id")

    try:
        sb = get_supabase()
        ex_res = await sb.table("exams").select("id, school_id").eq("id", exam_uuid).maybe_single().aexecute()
        ex = ex_res.data
        if not ex:
            await websocket.close(code=4404)
            return
        if school_id and ex.get("school_id") and str(ex.get("school_id")) != str(school_id):
            await websocket.close(code=4403)
            return
        if not school_id:
            school_id = str(ex.get("school_id") or "")
    except Exception:
        await websocket.close(code=4500)
        return

    await exam_monitoring_ws_manager.connect_candidate(exam_uuid, candidate_id, websocket)
    await websocket.send_text(json.dumps({
        "seq": 0,
        "event": "candidate_connected",
        "exam_id": exam_uuid,
        "timestamp": _now_iso(),
        "data": {"candidate_id": candidate_id},
    }))

    try:
        while True:
            raw = await websocket.receive_text()
            try:
                msg = json.loads(raw)
            except Exception:
                continue
            msg_type = (msg.get("type") or msg.get("event") or "").lower()
            if msg_type == "ping":
                await websocket.send_text(json.dumps({
                    "seq": 0,
                    "event": "pong",
                    "exam_id": exam_uuid,
                    "timestamp": _now_iso(),
                    "data": {},
                }))
                continue

            if msg_type in ("heartbeat", "telemetry", "proctor_event"):
                payload = msg.get("payload") if isinstance(msg.get("payload"), dict) else msg
                try:
                    sb = get_supabase()
                    rpc_res = await sb.rpc("rpc_record_candidate_heartbeat_and_event", {
                        "p_school_id": school_id or None,
                        "p_exam_id": exam_uuid,
                        "p_candidate_id": candidate_id,
                        "p_payload": payload,
                    }).aexecute()
                    res_data = rpc_res.data
                    if isinstance(res_data, list):
                        res_data = res_data[0] if res_data else {}
                    if isinstance(res_data, dict) and res_data.get("success"):
                        await websocket.send_text(json.dumps({
                            "seq": 0,
                            "event": "heartbeat_ack",
                            "exam_id": exam_uuid,
                            "timestamp": _now_iso(),
                            "data": res_data,
                        }))
                        ev_name = "incident_recorded" if res_data.get("incident_id") else "candidate_heartbeat"
                        await exam_monitoring_ws_manager.broadcast(
                            exam_id=exam_uuid,
                            event=ev_name,
                            audience="invigilators",
                            data={
                                "candidate_id": candidate_id,
                                "monitoring_status": res_data.get("monitoring_status"),
                                "warnings_count": res_data.get("warnings_count"),
                                "is_paused": res_data.get("is_paused"),
                                "remaining_seconds": res_data.get("remaining_seconds"),
                                "incident_id": res_data.get("incident_id"),
                                "telemetry": payload,
                            },
                        )
                except Exception as hb_err:
                    logger.debug("Candidate WS heartbeat error: %s", hb_err)
    except WebSocketDisconnect:
        pass
    except Exception as exc:
        logger.debug("Candidate WS loop closed for %s: %s", exam_uuid, exc)
    finally:
        await exam_monitoring_ws_manager.disconnect(exam_uuid, candidate_id, websocket, is_invigilator=False)

