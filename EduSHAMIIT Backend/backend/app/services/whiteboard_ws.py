"""
Authenticated Real-Time Collaborative Whiteboard WebSocket Manager.
Supports JWT authentication, institution isolation, backend RBAC validation,
rate limiting, throttled cursors/laser pointers, ordered operation persistence
via PostgreSQL stored procedures, and Redis Pub/Sub multi-worker fanout.
"""
import asyncio
import json
import logging
import os
import time
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
from fastapi import WebSocket, WebSocketDisconnect
from jose import jwt, JWTError
import psycopg2
from psycopg2.extras import RealDictCursor

from app.config import settings
from app.cache.redis_client import get_redis

logger = logging.getLogger(__name__)

DEFAULT_SCHOOL_ID = "11111111-1111-1111-1111-111111111111"
COLLAB_COLORS = [
    "#2563EB", "#DC2626", "#10B981", "#7C3AED",
    "#EA580C", "#0891B2", "#DB2777", "#4F46E5",
]


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


async def _exec_sp(sql: str, params: tuple = ()) -> List[Dict[str, Any]]:
    def _run():
        conn = psycopg2.connect(settings.DATABASE_URL, connect_timeout=5)
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(sql, params)
                rows = cur.fetchall() if cur.description else []
                conn.commit()
                return [dict(r) for r in rows]
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    return await asyncio.to_thread(_run)


def authenticate_whiteboard_ws_jwt(websocket: WebSocket) -> Optional[Dict[str, Any]]:
    """Validate Bearer token or ?token= query parameter for Whiteboard WS."""
    token = None
    auth_header = websocket.headers.get("authorization") or websocket.headers.get("Authorization")
    if auth_header and auth_header.startswith("Bearer "):
        token = auth_header.split(" ", 1)[1].strip()
    if not token:
        token = websocket.query_params.get("token")
    if not token:
        return None

    secrets_to_try = [s for s in [settings.SUPABASE_JWT_SECRET, settings.JWT_SECRET] if s]
    for secret in secrets_to_try:
        try:
            payload = jwt.decode(
                token,
                secret,
                algorithms=["HS256"],
                options={"verify_aud": False},
            )
            user_id = payload.get("sub") or payload.get("user_id")
            if not user_id:
                continue
            school_id = (
                payload.get("school_id")
                or websocket.headers.get("x-school-id")
                or websocket.query_params.get("school_id")
                or DEFAULT_SCHOOL_ID
            )
            return {
                "id": str(user_id),
                "school_id": str(school_id),
                "role": str(payload.get("role") or payload.get("user_role") or "student"),
                "full_name": payload.get("full_name") or payload.get("name") or payload.get("email") or "User",
            }
        except JWTError:
            continue
        except Exception:
            continue
    return None


class WhiteboardWSManager:
    """
    Manages collaborative whiteboard connections per whiteboard_id,
    handling presence, throttled cursors, and durable operation fanout.
    """

    def __init__(self) -> None:
        # whiteboard_id -> {conn_id: {"ws": WebSocket, "user": dict, "color": str, "connected_at": str}}
        self._rooms: Dict[str, Dict[str, Dict[str, Any]]] = {}
        self._sub_tasks: Dict[str, asyncio.Task] = {}
        self._lock = asyncio.Lock()
        self._worker_id: str = str(uuid.uuid4())

    async def _ensure_redis_subscriber(self, whiteboard_id: str) -> None:
        if os.environ.get("TESTING") == "1":
            return
        async with self._lock:
            existing = self._sub_tasks.get(whiteboard_id)
            if existing and not existing.done():
                return
            rc = get_redis()
            if not rc:
                return

            async def _listen():
                channel = f"wb_room:{whiteboard_id}"
                try:
                    pubsub = rc.pubsub()
                    await pubsub.subscribe(channel)
                    while whiteboard_id in self._rooms and self._rooms[whiteboard_id]:
                        msg = await pubsub.get_message(ignore_subscribe_messages=True, timeout=0.05)
                        if msg and msg.get("type") == "message":
                            raw = msg.get("data")
                            if isinstance(raw, bytes):
                                raw = raw.decode("utf-8")
                            try:
                                event = json.loads(raw)
                                if event.pop("_origin_worker", None) == self._worker_id:
                                    continue
                                exclude_conn = event.pop("_exclude_conn_id", None)
                                await self._local_broadcast(whiteboard_id, event, exclude_conn_id=exclude_conn)
                            except Exception:
                                pass
                        await asyncio.sleep(0.02)
                    await pubsub.close()
                except Exception as e:
                    logger.debug(f"[WhiteboardWS] Redis listener ended for {whiteboard_id}: {e}")

            self._sub_tasks[whiteboard_id] = asyncio.create_task(_listen())

    async def _local_broadcast(
        self,
        whiteboard_id: str,
        event: Dict[str, Any],
        exclude_conn_id: Optional[str] = None,
    ) -> None:
        peers = self._rooms.get(whiteboard_id)
        if not peers:
            return
        dead: List[str] = []
        for cid, entry in list(peers.items()):
            if exclude_conn_id and cid == exclude_conn_id:
                continue
            try:
                await entry["ws"].send_json(event)
            except Exception:
                dead.append(cid)
        for cid in dead:
            peers.pop(cid, None)

    async def broadcast_event(
        self,
        whiteboard_id: str,
        institution_id: str,
        session_id: Optional[str],
        user_id: Optional[str],
        event_type: str,
        payload: Dict[str, Any],
        page_id: Optional[str] = None,
        operation_id: Optional[str] = None,
        revision: Optional[int] = None,
        exclude_conn_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        envelope: Dict[str, Any] = {
            "event_id": str(uuid.uuid4()),
            "institution_id": institution_id,
            "session_id": session_id,
            "whiteboard_id": whiteboard_id,
            "page_id": page_id,
            "user_id": user_id,
            "event_type": event_type,
            "occurred_at": _now_iso(),
            "operation_id": operation_id,
            "revision": revision,
            "payload": payload,
        }
        # 1. Deliver immediately to peers connected to this worker
        await self._local_broadcast(whiteboard_id, envelope, exclude_conn_id=exclude_conn_id)

        # 2. Fanout across other Gunicorn workers via Redis Pub/Sub
        rc = get_redis()
        if rc and self._sub_tasks.get(whiteboard_id) and not self._sub_tasks[whiteboard_id].done():
            try:
                pub_payload = dict(envelope)
                pub_payload["_origin_worker"] = self._worker_id
                if exclude_conn_id:
                    pub_payload["_exclude_conn_id"] = exclude_conn_id
                await rc.publish(f"wb_room:{whiteboard_id}", json.dumps(pub_payload))
            except Exception:
                pass
        return envelope

    def get_collaborators(self, whiteboard_id: str) -> List[Dict[str, Any]]:
        peers = self._rooms.get(whiteboard_id, {})
        seen: Dict[str, Dict[str, Any]] = {}
        for entry in peers.values():
            u = entry["user"]
            uid = u["id"]
            seen[uid] = {
                "user_id": uid,
                "name": u["full_name"],
                "role": u["role"],
                "color": entry["color"],
                "connected_at": entry["connected_at"],
            }
        return list(seen.values())

    async def handle_connection(self, websocket: WebSocket, whiteboard_id: str) -> None:
        user = authenticate_whiteboard_ws_jwt(websocket)
        if not user:
            await websocket.close(code=4401, reason="Authentication required")
            return

        school_id = user["school_id"]
        # Verify board exists in user's institution and check permission
        try:
            perm_rows = await _exec_sp(
                "SELECT public.sp_get_whiteboard_user_permission(%s::UUID, %s::UUID, %s::UUID, %s::TEXT) AS perm;",
                (whiteboard_id, school_id, user["id"], user["role"]),
            )
            perm = perm_rows[0]["perm"] if perm_rows and perm_rows[0].get("perm") else {"allowed": False}
            if not perm.get("allowed"):
                await websocket.close(code=4403, reason="Access denied for whiteboard")
                return

            wb_meta_rows = await _exec_sp(
                "SELECT session_id, current_revision FROM public.live_class_whiteboards WHERE id = %s::UUID AND school_id = %s::UUID AND deleted_at IS NULL LIMIT 1;",
                (whiteboard_id, school_id),
            )
            if not wb_meta_rows:
                await websocket.close(code=4404, reason="Whiteboard not found")
                return
            session_id = str(wb_meta_rows[0]["session_id"]) if wb_meta_rows[0].get("session_id") else None
            current_revision = int(wb_meta_rows[0].get("current_revision") or 1)
        except Exception as e:
            logger.warning(f"[WhiteboardWS] Auth/DB check failed: {e}")
            await websocket.close(code=4500, reason="Internal error")
            return

        await websocket.accept()
        conn_id = str(uuid.uuid4())
        color = COLLAB_COLORS[abs(hash(user["id"])) % len(COLLAB_COLORS)]

        if whiteboard_id not in self._rooms:
            self._rooms[whiteboard_id] = {}
        self._rooms[whiteboard_id][conn_id] = {
            "ws": websocket,
            "user": user,
            "color": color,
            "connected_at": _now_iso(),
        }
        await self._ensure_redis_subscriber(whiteboard_id)

        # Send initial welcome & active collaborators
        collaborators = self.get_collaborators(whiteboard_id)
        await websocket.send_json({
            "event_id": str(uuid.uuid4()),
            "institution_id": school_id,
            "session_id": session_id,
            "whiteboard_id": whiteboard_id,
            "event_type": "whiteboard.opened",
            "occurred_at": _now_iso(),
            "revision": current_revision,
            "payload": {
                "conn_id": conn_id,
                "permission": perm,
                "collaborators": collaborators,
                "color": color,
            },
        })

        await self.broadcast_event(
            whiteboard_id=whiteboard_id,
            institution_id=school_id,
            session_id=session_id,
            user_id=user["id"],
            event_type="collaborator.joined",
            payload={
                "user": {
                    "user_id": user["id"],
                    "name": user["full_name"],
                    "role": user["role"],
                    "color": color,
                },
                "collaborators": collaborators,
            },
            exclude_conn_id=conn_id,
        )

        last_cursor_ts = 0.0
        op_window_start = time.monotonic()
        op_window_count = 0

        try:
            while True:
                msg = await websocket.receive_json()
                mtype = msg.get("event_type") or msg.get("type") or ""
                now_mono = time.monotonic()

                if mtype == "ping":
                    await websocket.send_json({"event_type": "pong", "ts": time.time()})
                    continue

                # Transient cursor & laser pointer (throttled to ~25Hz, never persisted to DB)
                if mtype in ("cursor.moved", "cursor_move", "laser.moved"):
                    if now_mono - last_cursor_ts < 0.04:
                        continue
                    last_cursor_ts = now_mono
                    await self.broadcast_event(
                        whiteboard_id=whiteboard_id,
                        institution_id=school_id,
                        session_id=session_id,
                        user_id=user["id"],
                        page_id=msg.get("page_id"),
                        event_type="laser.moved" if mtype == "laser.moved" else "cursor.moved",
                        payload={
                            "user_id": user["id"],
                            "name": user["full_name"],
                            "role": user["role"],
                            "color": color,
                            "x": msg.get("x", 0),
                            "y": msg.get("y", 0),
                            "tool": msg.get("tool", "select"),
                        },
                        exclude_conn_id=conn_id,
                    )
                    continue

                if mtype == "selection.changed":
                    await self.broadcast_event(
                        whiteboard_id=whiteboard_id,
                        institution_id=school_id,
                        session_id=session_id,
                        user_id=user["id"],
                        page_id=msg.get("page_id"),
                        event_type="selection.changed",
                        payload={
                            "user_id": user["id"],
                            "name": user["full_name"],
                            "color": color,
                            "selected_ids": msg.get("selected_ids", []),
                        },
                        exclude_conn_id=conn_id,
                    )
                    continue

                # Ephemeral stroke preview (real-time low-latency ink while drawing)
                if mtype in ("stroke.started", "stroke.updated"):
                    # Verify latest edit permission
                    live_perm_rows = await _exec_sp(
                        "SELECT public.sp_get_whiteboard_user_permission(%s::UUID, %s::UUID, %s::UUID, %s::TEXT) AS perm;",
                        (whiteboard_id, school_id, user["id"], user["role"]),
                    )
                    live_perm = live_perm_rows[0]["perm"] if live_perm_rows else {"can_edit": False}
                    if not live_perm.get("can_edit"):
                        continue
                    await self.broadcast_event(
                        whiteboard_id=whiteboard_id,
                        institution_id=school_id,
                        session_id=session_id,
                        user_id=user["id"],
                        page_id=msg.get("page_id"),
                        event_type=mtype,
                        payload=msg.get("payload") or msg,
                        exclude_conn_id=conn_id,
                    )
                    continue

                # Page navigation broadcast (follow teacher mode)
                if mtype == "page.changed":
                    await self.broadcast_event(
                        whiteboard_id=whiteboard_id,
                        institution_id=school_id,
                        session_id=session_id,
                        user_id=user["id"],
                        page_id=msg.get("page_id"),
                        event_type="page.changed",
                        payload={
                            "page_id": msg.get("page_id"),
                            "page_order": msg.get("page_order"),
                            "triggered_by": user["id"],
                            "triggered_by_role": user["role"],
                        },
                        exclude_conn_id=conn_id,
                    )
                    continue

                # Durable operations
                if mtype in ("operation", "object.created", "object.updated", "object.deleted", "stroke.completed", "page.clear"):
                    # Rate limit durable operations: max 60/sec per socket
                    if now_mono - op_window_start > 1.0:
                        op_window_start = now_mono
                        op_window_count = 0
                    op_window_count += 1
                    if op_window_count > 60:
                        await websocket.send_json({
                            "event_type": "whiteboard.sync_failed",
                            "payload": {"reason": "Rate limit exceeded"},
                        })
                        continue

                    live_perm_rows = await _exec_sp(
                        "SELECT public.sp_get_whiteboard_user_permission(%s::UUID, %s::UUID, %s::UUID, %s::TEXT) AS perm;",
                        (whiteboard_id, school_id, user["id"], user["role"]),
                    )
                    live_perm = live_perm_rows[0]["perm"] if live_perm_rows else {"can_edit": False}
                    if not live_perm.get("can_edit"):
                        await websocket.send_json({
                            "event_type": "whiteboard.sync_failed",
                            "operation_id": msg.get("operation_id"),
                            "payload": {"reason": "Edit permission denied"},
                        })
                        continue

                    page_id = msg.get("page_id")
                    op_id = msg.get("operation_id") or str(uuid.uuid4())
                    op_type = msg.get("operation_type")
                    if not op_type:
                        op_type = {
                            "object.created": "object.create",
                            "stroke.completed": "object.create",
                            "object.updated": "object.update",
                            "object.deleted": "object.delete",
                            "page.clear": "page.clear",
                        }.get(mtype, "object.create")

                    payload_data = msg.get("payload") or msg.get("operation_data") or {}
                    object_id = msg.get("object_id") or payload_data.get("id")
                    object_type = msg.get("object_type") or payload_data.get("type") or "stroke"

                    res_rows = await _exec_sp(
                        "SELECT public.sp_apply_whiteboard_operation(%s::UUID, %s::UUID, %s::UUID, %s::UUID, %s::UUID, %s::TEXT, %s::TEXT, %s::TEXT, %s::JSONB) AS res;",
                        (
                            whiteboard_id,
                            page_id,
                            school_id,
                            user["id"],
                            op_id,
                            op_type,
                            object_id,
                            object_type,
                            json.dumps(payload_data),
                        ),
                    )
                    res = res_rows[0]["res"] if res_rows else {"success": False}
                    if not res.get("success"):
                        await websocket.send_json({
                            "event_type": "whiteboard.sync_failed",
                            "operation_id": op_id,
                            "payload": {"reason": res.get("message", "Operation failed")},
                        })
                        continue

                    rev = res.get("revision")
                    # Acknowledge persistence to sender
                    await websocket.send_json({
                        "event_id": str(uuid.uuid4()),
                        "whiteboard_id": whiteboard_id,
                        "page_id": page_id,
                        "event_type": "whiteboard.saved",
                        "operation_id": op_id,
                        "revision": rev,
                        "occurred_at": _now_iso(),
                        "payload": {"duplicate": res.get("duplicate", False)},
                    })

                    if not res.get("duplicate"):
                        out_event_type = {
                            "object.create": "object.created",
                            "object.update": "object.updated",
                            "object.delete": "object.deleted",
                            "page.clear": "page.updated",
                            "objects.batch_create": "object.created",
                        }.get(op_type, "object.updated")
                        await self.broadcast_event(
                            whiteboard_id=whiteboard_id,
                            institution_id=school_id,
                            session_id=session_id,
                            user_id=user["id"],
                            page_id=page_id,
                            operation_id=op_id,
                            revision=rev,
                            event_type=out_event_type,
                            payload={
                                "operation_type": op_type,
                                "object_id": object_id,
                                "object_type": object_type,
                                "operation_data": payload_data,
                            },
                            exclude_conn_id=conn_id,
                        )

        except WebSocketDisconnect:
            pass
        except Exception as e:
            logger.warning(f"[WhiteboardWS] Error on {whiteboard_id}: {e}")
        finally:
            if whiteboard_id in self._rooms:
                self._rooms[whiteboard_id].pop(conn_id, None)
                collaborators = self.get_collaborators(whiteboard_id)
                await self.broadcast_event(
                    whiteboard_id=whiteboard_id,
                    institution_id=school_id,
                    session_id=session_id,
                    user_id=user["id"],
                    event_type="collaborator.left",
                    payload={
                        "user_id": user["id"],
                        "name": user["full_name"],
                        "collaborators": collaborators,
                    },
                )
                if not self._rooms[whiteboard_id]:
                    self._rooms.pop(whiteboard_id, None)


whiteboard_ws_manager = WhiteboardWSManager()
