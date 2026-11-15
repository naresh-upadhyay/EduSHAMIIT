"""
End-to-End Automated Test Suite for Enterprise Live Examination Monitoring & Invigilation.
Tests PostgreSQL RPCs, multi-tenant & role RBAC, LiveKit room/claim isolation,
bidirectional Redis-backed WebSockets, pause/freeze timers, re-entry approvals,
idempotency, conflict locking, announcements, audit logs, and CSV export.
"""
import asyncio
import json
import os
import time
import uuid
from datetime import datetime, timedelta, timezone

import asyncpg
import httpx
import pytest
import websockets
from jose import jwt

BASE_HTTP = os.environ.get("TEST_API_BASE_URL", "http://127.0.0.1:8082/api")
BASE_WS = os.environ.get("TEST_WS_BASE_URL", "ws://127.0.0.1:8082/api/ws")
DB_DSN = os.environ.get(
    "TEST_DATABASE_URL",
    "postgresql://postgres:eduSHAMIIT2026_pg@127.0.0.1:54322/postgres",
)
JWT_SECRET = os.environ.get(
    "SUPABASE_JWT_SECRET",
    "super-secret-jwt-token-with-at-least-32-characters-long",
)
LIVEKIT_SECRET = os.environ.get(
    "LIVEKIT_API_SECRET",
    "secretkey_edushamiit_livekit_2026_secure",
)

SCHOOL_A = "11111111-1111-1111-1111-111111111111"
SCHOOL_B = "8c3d220f-c4d9-4739-8ef8-2a2313809d84"

TEACHER_ID = "e1141a33-2d9d-4a52-a27b-9ddeeefd41b9"
ADMIN_OTHER_SCHOOL = "a819f432-4756-49ea-a4af-23087fe41685"
STUDENT_1 = "073cf4b4-7678-4a9d-bca8-a186d4e3bf5e"  # class 10A
STUDENT_2 = "10000000-0000-0000-0000-000000000002"
TEACHER_EXAMINEE_ID = "20000000-0000-0000-0000-000000000001"


def make_jwt(user_id: str, school_id: str, role: str, name: str = "Test User", class_name: str = "10A") -> str:
    now = int(time.time())
    payload = {
        "sub": user_id,
        "school_id": school_id,
        "role": role,
        "full_name": name,
        "class": class_name,
        "email": f"{user_id[:8]}@test.edushamiit.local",
        "iat": now,
        "exp": now + 3600,
    }
    return jwt.encode(payload, JWT_SECRET, algorithm="HS256")


def auth_headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}


async def recv_ws_event(ws, expected_events: set, timeout: float = 8.0) -> dict:
    deadline = time.monotonic() + timeout
    while True:
        remaining = max(0.1, deadline - time.monotonic())
        raw = await asyncio.wait_for(ws.recv(), timeout=remaining)
        msg = json.loads(raw)
        if msg.get("event") in expected_events:
            return msg


async def _create_test_exam(conn: asyncpg.Connection, client: httpx.AsyncClient, teacher_hdrs: dict, title: str, purpose: str = "academic", target_students=None):
    now = datetime.now(timezone.utc)
    start_dt = now - timedelta(minutes=5)
    end_dt = now + timedelta(minutes=85)
    targets = target_students or [STUDENT_1, STUDENT_2]
    payload = {
        "title": title,
        "subject": "Mathematics",
        "target_classes": ["10A"],
        "target_students": targets,
        "exam_date": now.strftime("%Y-%m-%d"),
        "start_time": start_dt.isoformat().replace("+00:00", "Z"),
        "end_time": end_dt.isoformat().replace("+00:00", "Z"),
        "duration": "90",
        "total_marks": 10,
        "passing_marks": 4,
        "exam_type": "online",
        "exam_mode": "online",
        "exam_purpose": purpose,
        "status": "published",
        "instructions": "E2E automated test examination",
    }
    res = await client.post(f"{BASE_HTTP}/exams/create", headers=teacher_hdrs, json=payload)
    assert res.status_code == 200, f"Create exam failed: {res.status_code} {res.text}"
    exam_data = res.json()["data"]
    exam_id = exam_data.get("id") or exam_data.get("exam_id")
    assert exam_id, f"Missing exam_id in response: {res.json()}"

    await conn.execute(
        """
        UPDATE public.exams
        SET target_students = $2::jsonb,
            exam_mode = 'online',
            exam_type = 'online',
            exam_purpose = $3,
            start_time = $4,
            end_time = $5
        WHERE id = $1::uuid
        """,
        exam_id,
        json.dumps(targets),
        purpose,
        start_dt,
        end_dt,
    )

    q_res = await client.post(
        f"{BASE_HTTP}/exams/{exam_id}/questions",
        headers=teacher_hdrs,
        json={
            "question_text": "What is 6 + 4?",
            "question_type": "mcq",
            "options": [
                {"label": "A", "text": "8", "value": "8"},
                {"label": "B", "text": "9", "value": "9"},
                {"label": "C", "text": "10", "value": "10"},
                {"label": "D", "text": "11", "value": "11"},
            ],
            "correct_answer": "10",
            "marks": 10,
            "order_number": 1,
        },
    )
    assert q_res.status_code == 200, f"Add question failed: {q_res.status_code} {q_res.text}"
    q_data = q_res.json().get("data") or q_res.json()
    q_id = q_data.get("id") if isinstance(q_data, dict) else None
    assert q_id, f"Missing question id in response: {q_res.json()}"
    return exam_id, q_id


async def _cleanup_exam_db(conn: asyncpg.Connection, exam_id: str) -> None:
    if not exam_id:
        return
    tables = [
        "exam_announcement_recipients",
        "exam_announcements",
        "invigilator_actions",
        "candidate_reentry_requests",
        "candidate_time_adjustments",
        "exam_incidents",
        "exam_monitoring_sessions",
        "exam_submissions",
        "exam_sessions",
        "exam_activity_logs",
        "exam_prestart_sessions",
        "exam_questions",
    ]
    for tbl in tables:
        try:
            await conn.execute(f"DELETE FROM public.{tbl} WHERE exam_id = $1::uuid", exam_id)
        except Exception:
            pass
    await conn.execute("DELETE FROM public.notifications WHERE reference_id = $1", exam_id)
    await conn.execute("DELETE FROM public.exams WHERE id = $1::uuid", exam_id)


@pytest.mark.asyncio
async def test_live_exam_monitoring_end_to_end():
    conn = await asyncpg.connect(DB_DSN)
    exam_id = None
    onboarding_exam_id = None

    teacher_tok = make_jwt(TEACHER_ID, SCHOOL_A, "teacher", name="Rohan Deshmukh")
    student1_tok = make_jwt(STUDENT_1, SCHOOL_A, "student", name="Naresh Upadhyay")
    student2_tok = make_jwt(STUDENT_2, SCHOOL_A, "student", name="Vihaan Verma")
    other_admin_tok = make_jwt(ADMIN_OTHER_SCHOOL, SCHOOL_B, "super_admin", name="Admin Greenfield")
    examinee_teacher_tok = make_jwt(TEACHER_EXAMINEE_ID, SCHOOL_A, "teacher", name="Dr. Ramesh Gupta")

    teacher_hdrs = auth_headers(teacher_tok)
    s1_hdrs = auth_headers(student1_tok)
    s2_hdrs = auth_headers(student2_tok)
    other_admin_hdrs = auth_headers(other_admin_tok)
    examinee_teacher_hdrs = auth_headers(examinee_teacher_tok)

    try:
        async with httpx.AsyncClient(timeout=20.0) as client:
            exam_id, q_id = await _create_test_exam(
                conn,
                client,
                teacher_hdrs,
                title=f"=CMD('calc') E2E Live Monitor {uuid.uuid4().hex[:6]}",
                target_students=[STUDENT_1, STUDENT_2],
            )
            onboarding_exam_id, _ = await _create_test_exam(
                conn,
                client,
                teacher_hdrs,
                title=f"Teacher Onboarding Exam {uuid.uuid4().hex[:6]}",
                purpose="onboarding",
                target_students=[TEACHER_EXAMINEE_ID],
            )

            # -----------------------------------------------------------------
            # 1. AUTHENTICATION, RBAC, MULTI-TENANCY & LIVEKIT SCOPING
            # -----------------------------------------------------------------
            unauth_res = await client.get(f"{BASE_HTTP}/exams/{exam_id}/monitoring/overview")
            assert unauth_res.status_code in (401, 403), unauth_res.text

            for ep in [
                ("GET", f"/exams/{exam_id}/monitoring/overview"),
                ("GET", f"/exams/{exam_id}/monitoring/candidates"),
                ("POST", f"/exams/{exam_id}/monitoring/actions"),
                ("GET", f"/exams/{exam_id}/monitoring/incidents"),
                ("GET", f"/exams/{exam_id}/monitoring/audit-logs"),
                ("GET", f"/exams/{exam_id}/monitoring/report?format=csv"),
            ]:
                r = await client.request(ep[0], f"{BASE_HTTP}{ep[1]}", headers=s1_hdrs, json={})
                assert r.status_code == 403, f"Expected 403 for student on {ep}: got {r.status_code} {r.text}"

            cross_res = await client.get(f"{BASE_HTTP}/exams/{exam_id}/monitoring/overview", headers=other_admin_hdrs)
            assert cross_res.status_code == 403, cross_res.text

            # Onboarding examinee (teacher role, but listed as target/onboarding examinee) must NOT monitor
            onboard_res = await client.get(
                f"{BASE_HTTP}/exams/{onboarding_exam_id}/monitoring/overview",
                headers=examinee_teacher_hdrs,
            )
            assert onboard_res.status_code == 403, onboard_res.text

            # LiveKit token RBAC & URL checks
            s1_force_inv = await client.get(
                f"{BASE_HTTP}/exams/{exam_id}/monitoring/livekit-token?mode=invigilator",
                headers=s1_hdrs,
            )
            assert s1_force_inv.status_code == 403

            s1_lk = await client.get(
                f"{BASE_HTTP}/exams/{exam_id}/monitoring/livekit-token?mode=candidate",
                headers=s1_hdrs,
            )
            assert s1_lk.status_code == 200, s1_lk.text
            s1_lk_json = s1_lk.json()
            assert s1_lk_json["can_subscribe"] is False
            assert s1_lk_json["livekit_url"].startswith("ws://127.0.0.1:8082"), s1_lk_json["livekit_url"]
            decoded_s1 = jwt.decode(s1_lk_json["token"], LIVEKIT_SECRET, algorithms=["HS256"], options={"verify_aud": False})
            assert decoded_s1["video"]["canSubscribe"] is False
            assert decoded_s1["video"]["roomAdmin"] is False
            assert decoded_s1["video"]["canPublishSources"] == ["camera", "microphone", "screen_share"]

            t_lk = await client.get(
                f"{BASE_HTTP}/exams/{exam_id}/monitoring/livekit-token?mode=invigilator",
                headers=teacher_hdrs,
            )
            assert t_lk.status_code == 200, t_lk.text
            t_lk_json = t_lk.json()
            assert t_lk_json["can_subscribe"] is True
            decoded_t = jwt.decode(t_lk_json["token"], LIVEKIT_SECRET, algorithms=["HS256"], options={"verify_aud": False})
            assert decoded_t["video"]["canSubscribe"] is True
            assert decoded_t["video"]["roomAdmin"] is True

            # Unauthenticated & student monitoring WS rejection
            with pytest.raises(Exception):
                async with websockets.connect(f"{BASE_WS}/exams/{exam_id}/monitoring"):
                    pass

            try:
                async with websockets.connect(f"{BASE_WS}/exams/{exam_id}/monitoring?token={student1_tok}") as bad_ws:
                    with pytest.raises(websockets.exceptions.ConnectionClosed) as exc_info:
                        await asyncio.wait_for(bad_ws.recv(), timeout=5.0)
                    assert exc_info.value.code == 4403
            except websockets.exceptions.InvalidStatusCode:
                pass
            except websockets.exceptions.ConnectionClosed as closed:
                assert closed.code == 4403

            # -----------------------------------------------------------------
            # 2. START SESSION, AUTOSAVE ANSWER, TELEMETRY HEARTBEAT & OVERVIEW
            # -----------------------------------------------------------------
            st1 = await client.post(f"{BASE_HTTP}/exams/{exam_id}/session/start", headers=s1_hdrs)
            assert st1.status_code == 200, st1.text
            s1_session_id = st1.json()["session_id"]

            st2 = await client.post(f"{BASE_HTTP}/exams/{exam_id}/session/start", headers=s2_hdrs)
            assert st2.status_code == 200, st2.text

            save_res = await client.post(
                f"{BASE_HTTP}/exams/{exam_id}/session/save-answer",
                headers=s1_hdrs,
                json={"question_id": q_id, "answer": "10", "time_spent_seconds": 12},
            )
            assert save_res.status_code == 200, save_res.text
            assert save_res.json()["answered_count"] == 1

            hb1 = await client.post(
                f"{BASE_HTTP}/exams/{exam_id}/monitoring/heartbeat",
                headers=s1_hdrs,
                json={
                    "camera_permission": "granted",
                    "camera_active": True,
                    "mic_permission": "granted",
                    "mic_active": False,
                    "screen_share_state": "shared",
                    "screen_share_active": True,
                    "network_status": "GOOD",
                    "latency_ms": 34,
                    "browser_info": "Pytest Chrome 145",
                },
            )
            assert hb1.status_code == 200 and hb1.json()["success"] is True, hb1.text

            ov = await client.get(f"{BASE_HTTP}/exams/{exam_id}/monitoring/overview", headers=teacher_hdrs)
            assert ov.status_code == 200, ov.text
            ov_data = ov.json()
            assert ov_data["kpis"]["total_students"] >= 2
            breakdown_sum = sum(int(item["count"]) for item in ov_data["status_breakdown"])
            assert breakdown_sum == int(ov_data["kpis"]["total_students"]), (breakdown_sum, ov_data["kpis"])

            cands_res = await client.get(f"{BASE_HTTP}/exams/{exam_id}/monitoring/candidates", headers=teacher_hdrs)
            assert cands_res.status_code == 200, cands_res.text
            cands_by_id = {c["candidate_id"]: c for c in cands_res.json()["candidates"]}
            assert STUDENT_1 in cands_by_id
            assert cands_by_id[STUDENT_1]["camera_active"] is True
            assert cands_by_id[STUDENT_1]["mic_active"] is False
            assert cands_by_id[STUDENT_1]["answered_count"] == 1

            # -----------------------------------------------------------------
            # 3. TAB SWITCH AUTO-FLAG THRESHOLD & INCIDENT RESOLUTION
            # -----------------------------------------------------------------
            for idx in range(3):
                ev_res = await client.post(
                    f"{BASE_HTTP}/exams/{exam_id}/monitoring/heartbeat",
                    headers=s1_hdrs,
                    json={
                        "event_type": "tab_switch",
                        "severity": "medium",
                        "title": "Switched Browser Tab",
                        "description": f"Tab switch #{idx + 1}",
                        "duration_seconds": 4,
                        "detection_source": "browser",
                    },
                )
                assert ev_res.status_code == 200, ev_res.text
            ev_last = ev_res.json()
            assert ev_last["warnings_count"] >= 3
            assert ev_last["monitoring_status"] == "VIOLATION", ev_last

            inc_res = await client.get(f"{BASE_HTTP}/exams/{exam_id}/monitoring/incidents", headers=teacher_hdrs)
            assert inc_res.status_code == 200, inc_res.text
            incidents = inc_res.json()["incidents"]
            assert len(incidents) >= 3
            first_inc_id = incidents[0]["id"]

            res_inc = await client.post(
                f"{BASE_HTTP}/exams/{exam_id}/monitoring/incidents/{first_inc_id}/resolve",
                headers=teacher_hdrs,
                json={"status": "resolved", "resolution_note": "Verified false alarm with candidate"},
            )
            assert res_inc.status_code == 200 and res_inc.json()["status"] == "resolved", res_inc.text

            # -----------------------------------------------------------------
            # 4. STALE SWEEP -> DISCONNECTED -> RE-ENTRY LIMIT -> APPROVE REJOIN
            # -----------------------------------------------------------------
            await conn.execute(
                """
                UPDATE public.exam_sessions
                SET last_ping = NOW() - INTERVAL '90 seconds',
                    reentry_count = 2,
                    max_reentry_attempts = 2
                WHERE id = $1::uuid
                """,
                s1_session_id,
            )

            ov_after_sweep = await client.get(f"{BASE_HTTP}/exams/{exam_id}/monitoring/overview", headers=teacher_hdrs)
            assert ov_after_sweep.status_code == 200
            detail_s1 = await client.get(f"{BASE_HTTP}/exams/{exam_id}/monitoring/candidates/{STUDENT_1}", headers=teacher_hdrs)
            assert detail_s1.status_code == 200, detail_s1.text
            assert detail_s1.json()["candidate"]["monitoring_status"] == "DISCONNECTED"

            # Attempting restart over max_reentry_attempts must gate on approval and preserve answers
            gated = await client.post(f"{BASE_HTTP}/exams/{exam_id}/session/start", headers=s1_hdrs)
            assert gated.status_code == 200, gated.text
            gated_json = gated.json()
            assert gated_json.get("requires_reentry_approval") is True
            assert gated_json.get("saved_answers", {}).get(q_id) == "10"

            req_re = await client.post(
                f"{BASE_HTTP}/exams/{exam_id}/monitoring/reentry-request",
                headers=s1_hdrs,
                json={"reason": "Home router rebooted"},
            )
            assert req_re.status_code == 200 and req_re.json()["success"] is True, req_re.text

            app_re = await client.post(
                f"{BASE_HTTP}/exams/{exam_id}/monitoring/actions",
                headers=teacher_hdrs,
                json={
                    "action_type": "approve_reentry",
                    "candidate_ids": [STUDENT_1],
                    "reason": "Verified genuine ISP drop",
                },
            )
            assert app_re.status_code == 200 and app_re.json()["affected_count"] == 1, app_re.text

            resumed = await client.post(f"{BASE_HTTP}/exams/{exam_id}/session/start", headers=s1_hdrs)
            assert resumed.status_code == 200, resumed.text
            assert resumed.json()["session_id"] == s1_session_id  # no duplicate session row
            assert resumed.json()["saved_answers"].get(q_id) == "10"

            # Verify no duplicate rows exist in exam_sessions for candidate
            sess_count = await conn.fetchval(
                "SELECT COUNT(*) FROM public.exam_sessions WHERE exam_id = $1::uuid AND student_id = $2::uuid",
                exam_id,
                STUDENT_1,
            )
            assert sess_count == 1

            # -----------------------------------------------------------------
            # 5. PAUSE/FREEZE, EXTRA TIME, IDEMPOTENCY, TERMINATION LOCK & CONFLICTS
            # -----------------------------------------------------------------
            p_res = await client.post(
                f"{BASE_HTTP}/exams/{exam_id}/monitoring/actions",
                headers=teacher_hdrs,
                json={"action_type": "pause", "candidate_ids": [STUDENT_1], "reason": "ID re-verification"},
            )
            assert p_res.status_code == 200 and p_res.json()["results"][0]["is_paused"] is True
            await asyncio.sleep(1.2)
            r_res = await client.post(
                f"{BASE_HTTP}/exams/{exam_id}/monitoring/actions",
                headers=teacher_hdrs,
                json={"action_type": "resume", "candidate_ids": [STUDENT_1], "reason": "ID verified"},
            )
            assert r_res.status_code == 200 and r_res.json()["results"][0]["is_paused"] is False
            paused_sec = await conn.fetchval("SELECT paused_total_seconds FROM public.exam_sessions WHERE id = $1::uuid", s1_session_id)
            assert int(paused_sec or 0) >= 1

            ext_res = await client.post(
                f"{BASE_HTTP}/exams/{exam_id}/monitoring/actions",
                headers=teacher_hdrs,
                json={"action_type": "extend_time", "candidate_ids": [STUDENT_1], "minutes": 10, "reason": "Tech recovery"},
            )
            assert ext_res.status_code == 200 and ext_res.json()["results"][0]["extra_minutes"] == 10

            over_ext = await client.post(
                f"{BASE_HTTP}/exams/{exam_id}/monitoring/actions",
                headers=teacher_hdrs,
                json={"action_type": "extend_time", "candidate_ids": [STUDENT_1], "minutes": 180, "reason": "Too huge"},
            )
            assert over_ext.status_code in (400, 409) or len(over_ext.json().get("errors", [])) > 0

            # Idempotency check on warning count
            pre_warn = await conn.fetchval("SELECT warnings_count FROM public.exam_sessions WHERE id = $1::uuid", s1_session_id)
            idem_key = f"warn-idem-{uuid.uuid4().hex[:8]}"
            w1 = await client.post(
                f"{BASE_HTTP}/exams/{exam_id}/monitoring/actions",
                headers=teacher_hdrs,
                json={"action_type": "warn", "candidate_ids": [STUDENT_1], "reason": "Look forward", "idempotency_key": idem_key},
            )
            w2 = await client.post(
                f"{BASE_HTTP}/exams/{exam_id}/monitoring/actions",
                headers=teacher_hdrs,
                json={"action_type": "warn", "candidate_ids": [STUDENT_1], "reason": "Look forward", "idempotency_key": idem_key},
            )
            assert w1.status_code == 200 and w2.status_code == 200
            post_warn = await conn.fetchval("SELECT warnings_count FROM public.exam_sessions WHERE id = $1::uuid", s1_session_id)
            assert post_warn == pre_warn + 1

            # Terminate student 1 -> blocks saves/restarts AND conflicts subsequent warn/pause
            term_res = await client.post(
                f"{BASE_HTTP}/exams/{exam_id}/monitoring/actions",
                headers=teacher_hdrs,
                json={"action_type": "terminate", "candidate_ids": [STUDENT_1], "reason": "Confirmed unfair practice"},
            )
            assert term_res.status_code == 200 and term_res.json()["results"][0]["monitoring_status"] == "TERMINATED"

            blocked_save = await client.post(
                f"{BASE_HTTP}/exams/{exam_id}/session/save-answer",
                headers=s1_hdrs,
                json={"question_id": q_id, "answer": "8"},
            )
            assert blocked_save.status_code == 403

            blocked_start = await client.post(f"{BASE_HTTP}/exams/{exam_id}/session/start", headers=s1_hdrs)
            assert blocked_start.status_code == 200 and blocked_start.json().get("is_terminated") is True

            conflict_act = await client.post(
                f"{BASE_HTTP}/exams/{exam_id}/monitoring/actions",
                headers=teacher_hdrs,
                json={"action_type": "pause", "candidate_ids": [STUDENT_1], "reason": "Should fail"},
            )
            assert conflict_act.status_code == 409, f"Expected 409 Conflict, got {conflict_act.status_code} {conflict_act.text}"

            # -----------------------------------------------------------------
            # 6. LIVE REDIS WEBSOCKET FANOUT, ANNOUNCEMENTS, EXAM CONTROLS & CSV
            # -----------------------------------------------------------------
            async with websockets.connect(f"{BASE_WS}/exams/{exam_id}/monitoring?token={teacher_tok}") as inv_ws, \
                       websockets.connect(f"{BASE_WS}/exams/{exam_id}/candidate?token={student2_tok}") as s2_ws:

                conn_inv = json.loads(await asyncio.wait_for(inv_ws.recv(), timeout=5.0))
                conn_s2 = json.loads(await asyncio.wait_for(s2_ws.recv(), timeout=5.0))
                assert conn_inv["event"] == "monitoring_connected"
                assert conn_s2["event"] == "candidate_connected"

                # Candidate sends heartbeat over WS -> invigilator receives real-time update via Redis Pub/Sub
                await s2_ws.send(json.dumps({
                    "type": "heartbeat",
                    "payload": {
                        "camera_permission": "granted",
                        "camera_active": True,
                        "mic_permission": "granted",
                        "mic_active": True,
                        "network_status": "GOOD",
                        "latency_ms": 22,
                    },
                }))
                s2_ack = await recv_ws_event(s2_ws, {"heartbeat_ack"})
                assert s2_ack["data"]["success"] is True

                inv_ev = await recv_ws_event(inv_ws, {"candidate_heartbeat"})
                assert inv_ev["data"]["candidate_id"] == STUDENT_2

                # Invigilator broadcasts live announcement -> candidate 2 WS receives it & acknowledges
                ann_res = await client.post(
                    f"{BASE_HTTP}/exams/{exam_id}/monitoring/announcements",
                    headers=teacher_hdrs,
                    json={
                        "title": "Question 1 Clarification",
                        "message": "Read Q1 carefully before answering.",
                        "priority": "urgent",
                        "target_scope": "all",
                        "requires_acknowledgement": True,
                    },
                )
                assert ann_res.status_code == 200 and ann_res.json()["success"] is True, ann_res.text
                ann_id = ann_res.json()["announcement_id"]

                s2_ann = await recv_ws_event(s2_ws, {"exam_announcement"})
                assert s2_ann["data"]["id"] == ann_id

                ack_res = await client.post(
                    f"{BASE_HTTP}/exams/{exam_id}/monitoring/announcements/{ann_id}/ack",
                    headers=s2_hdrs,
                )
                assert ack_res.status_code == 200
                inv_ack = await recv_ws_event(inv_ws, {"announcement_acknowledged"})
                assert inv_ack["data"]["announcement_id"] == ann_id

                # Exam-wide control: pause_exam + emergency_submit_all
                ex_pause = await client.post(
                    f"{BASE_HTTP}/exams/{exam_id}/monitoring/controls",
                    headers=teacher_hdrs,
                    json={"control_action": "pause_exam", "reason": "Brief hall announcement"},
                )
                assert ex_pause.status_code == 200 and ex_pause.json()["status"] == "PAUSED"
                s2_ctrl = await recv_ws_event(s2_ws, {"exam_control_updated"})
                assert s2_ctrl["data"]["control_action"] == "pause_exam"

                ex_em = await client.post(
                    f"{BASE_HTTP}/exams/{exam_id}/monitoring/controls",
                    headers=teacher_hdrs,
                    json={"control_action": "emergency_submit_all", "reason": "End of examination"},
                )
                assert ex_em.status_code == 200 and ex_em.json()["status"] == "EMERGENCY_STOPPED"
                s2_em = await recv_ws_event(s2_ws, {"exam_control_updated"})
                assert s2_em["data"]["control_action"] == "emergency_submit_all"

            # Verify audit logs and CSV export with formula neutralization
            logs_res = await client.get(f"{BASE_HTTP}/exams/{exam_id}/monitoring/audit-logs", headers=teacher_hdrs)
            assert logs_res.status_code == 200 and len(logs_res.json()["logs"]) >= 5

            csv_res = await client.get(f"{BASE_HTTP}/exams/{exam_id}/monitoring/report?format=csv", headers=teacher_hdrs)
            assert csv_res.status_code == 200
            assert "text/csv" in csv_res.headers.get("content-type", "")
            csv_text = csv_res.text
            assert "'=CMD('calc')" in csv_text, "Expected formula neutralization prefix in CSV export"
            assert "Incident Log" in csv_text

    finally:
        await _cleanup_exam_db(conn, exam_id)
        await _cleanup_exam_db(conn, onboarding_exam_id)
        await conn.close()
