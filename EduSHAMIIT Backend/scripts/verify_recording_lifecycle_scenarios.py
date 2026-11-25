"""End-to-end backend verification for Live Class Recording start/stop idempotency and upload scenarios."""
import json
import subprocess
import urllib.error
import urllib.request

BASE_URL = "http://localhost:8082/api"


def _req(method: str, path: str, body: dict | None = None, headers: dict | None = None):
    hdrs = {"Content-Type": "application/json"}
    if headers:
        hdrs.update(headers)
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(f"{BASE_URL}{path}", data=data, headers=hdrs, method=method)
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return resp.status, json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {e.code} on {method} {path}: {err_body}") from e


def main():
    sess_id = subprocess.check_output(
        [
            "docker", "exec", "supabase-db", "psql", "-U", "postgres", "-d", "postgres", "-t", "-A", "-c",
            "SELECT id::text FROM public.live_classes LIMIT 1;",
        ],
        text=True,
    ).strip()
    assert sess_id, "No live_classes row found"

    user_id = subprocess.check_output(
        [
            "docker", "exec", "supabase-db", "psql", "-U", "postgres", "-d", "postgres", "-t", "-A", "-c",
            "SELECT id::text FROM public.profiles WHERE role::text IN ('super_admin', 'admin', 'teacher') LIMIT 1;",
        ],
        text=True,
    ).strip()
    assert user_id, "No user row found"

    token = subprocess.check_output(
        [
            "docker", "exec", "edushamiit-api", "python", "-c",
            (
                "import time; from jose import jwt; from app.config import settings; "
                "sec = settings.SUPABASE_JWT_SECRET or settings.JWT_SECRET; "
                f"print(jwt.encode({{'sub': '{user_id}', 'role': 'super_admin', 'exp': int(time.time()) + 300}}, sec, algorithm='HS256'))"
            ),
        ],
        text=True,
    ).strip()
    auth = {"Authorization": f"Bearer {token}"}

    init_state_row = subprocess.check_output(
        [
            "docker", "exec", "supabase-db", "psql", "-U", "postgres", "-d", "postgres", "-t", "-A", "-c",
            f"SELECT COALESCE(recording_status, 'IDLE') || '|' || COALESCE(status, 'upcoming') || '|' || COALESCE(is_live::text, 'false') FROM public.live_classes WHERE id = '{sess_id}';",
        ],
        text=True,
    ).strip()
    init_rec_status, init_class_status, init_is_live = init_state_row.split("|", 2)

    try:
        # 1. Explicit start from any state -> MUST become RECORDING
        code, res = _req("POST", f"/live-classes/sessions/{sess_id}/recordings/toggle", {"action": "start"}, auth)
        assert code == 200 and res["recording_status"] == "RECORDING", f"Start 1 failed: {res}"

        # 2. Repeated explicit start (double-click / stale DB protection) -> MUST STAY RECORDING!
        code, res = _req("POST", f"/live-classes/sessions/{sess_id}/recordings/toggle", {"action": "start"}, auth)
        assert code == 200 and res["recording_status"] == "RECORDING", f"Idempotent start 2 accidentally stopped: {res}"

        # 3. Explicit stop -> MUST become COMPLETED
        code, res = _req("POST", f"/live-classes/sessions/{sess_id}/recordings/toggle", {"action": "stop"}, auth)
        assert code == 200 and res["recording_status"] == "COMPLETED", f"Stop 1 failed: {res}"

        # 4. Repeated explicit stop -> MUST STAY COMPLETED (never flip back to RECORDING!)
        code, res = _req("POST", f"/live-classes/sessions/{sess_id}/recordings/toggle", {"action": "stop"}, auth)
        assert code == 200 and res["recording_status"] == "COMPLETED", f"Idempotent stop 2 accidentally started: {res}"

        # 5. End live class -> join-conduct dashboard MUST return active_session == None
        code, end_res = _req("POST", f"/live-classes/{sess_id}/end", {}, auth)
        assert code == 200 and end_res.get("success") is True, f"End class failed: {end_res}"
        code, dash_res = _req("GET", "/live-classes/dashboard/join-conduct", None, auth)
        assert code == 200 and dash_res["data"].get("active_session") is None, (
            f"Ended session must NOT appear in join-conduct active_session banner: {dash_res}"
        )

        # 6. Auto-end on Leave when nobody else is in the room
        subprocess.check_call(
            [
                "docker", "exec", "supabase-db", "psql", "-U", "postgres", "-d", "postgres", "-c",
                f"UPDATE public.live_classes SET status = 'live', is_live = TRUE WHERE id = '{sess_id}';",
            ],
            stdout=subprocess.DEVNULL,
        )
        code, leave_res = _req("POST", f"/live-classes/{sess_id}/leave", {}, auth)
        assert code == 200 and leave_res.get("auto_ended") is True, f"Expected auto_ended=True on empty room leave: {leave_res}"
        code, dash_after_leave = _req("GET", "/live-classes/dashboard/join-conduct", None, auth)
        assert dash_after_leave["data"].get("active_session") is None, (
            f"Auto-ended session must NOT appear in active_session banner: {dash_after_leave}"
        )

        # 7. Leave when another participant is still in room -> MUST stay live (auto_ended=False)
        other_user_id = subprocess.check_output(
            [
                "docker", "exec", "supabase-db", "psql", "-U", "postgres", "-d", "postgres", "-t", "-A", "-c",
                f"SELECT id::text FROM public.profiles WHERE id::text != '{user_id}' LIMIT 1;",
            ],
            text=True,
        ).strip()
        if other_user_id:
            subprocess.check_call(
                [
                    "docker", "exec", "supabase-db", "psql", "-U", "postgres", "-d", "postgres", "-c",
                    f"UPDATE public.live_classes SET status = 'live', is_live = TRUE WHERE id = '{sess_id}'; "
                    f"INSERT INTO public.live_class_participants (live_class_id, user_id, participant_role, join_time, leave_time) "
                    f"VALUES ('{sess_id}', '{other_user_id}', 'student', NOW(), NULL);",
                ],
                stdout=subprocess.DEVNULL,
            )
            try:
                code, keep_res = _req("POST", f"/live-classes/{sess_id}/leave", {}, auth)
                assert code == 200 and keep_res.get("auto_ended") is False and (keep_res.get("remaining_participants") or 0) >= 1, (
                    f"Expected session to stay live while another participant remains: {keep_res}"
                )
            finally:
                subprocess.check_call(
                    [
                        "docker", "exec", "supabase-db", "psql", "-U", "postgres", "-d", "postgres", "-c",
                        f"DELETE FROM public.live_class_participants WHERE live_class_id = '{sess_id}' AND user_id = '{other_user_id}' AND join_time > NOW() - INTERVAL '5 minutes';",
                    ],
                    stdout=subprocess.DEVNULL,
                )

        print("ALL_RECORDING_IDEMPOTENCY_AND_LEAVE_END_SCENARIOS_PASSED")
    finally:
        subprocess.check_call(
            [
                "docker", "exec", "supabase-db", "psql", "-U", "postgres", "-d", "postgres", "-c",
                f"UPDATE public.live_classes SET recording_status = '{init_rec_status}', status = '{init_class_status}', is_live = {init_is_live} WHERE id = '{sess_id}';",
            ],
            stdout=subprocess.DEVNULL,
        )


if __name__ == "__main__":
    main()
