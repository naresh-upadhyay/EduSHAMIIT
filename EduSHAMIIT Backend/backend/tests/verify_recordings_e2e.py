"""
Comprehensive End-to-End Verification Script for Live Class Recordings Module.
Tests every scenario against the live EduSHAMIIT FastAPI app & PostgreSQL DB:
1. Recordings Dashboard KPIs, Storage Breakdown, Settings & 30-day Analytics
2. Real Multipart Video Upload + DB/Disk persistence
3. Video Range Streaming (HTTP 200 & 206 Partial Content) + ?token= auth
4. Download Endpoint + downloads_count & KPI analytics tracking
5. View Tracking + views_count & event log update
6. Edit Recording Metadata (title, class, section, subject, visibility, duration)
7. Granular Sharing (Class/Multi-Section + Individual) & Revoke
8. Settings Persistence & Student Download Policy Enforcement
9. Live Class Recording Sync with Real Class Title (never "Live Class Recording")
10. Single Delete, Bulk Delete & Complete Test Data Cleanup
"""
import os
import sys
import json
import uuid

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
if "/app" not in sys.path and os.path.isdir("/app/app"):
    sys.path.insert(0, "/app")

try:
    import pytest
except ImportError:
    class _DummyMark:
        @staticmethod
        def asyncio(fn):
            return fn
    class _DummyPytest:
        mark = _DummyMark()
    pytest = _DummyPytest()

from jose import jwt
from fastapi.testclient import TestClient

from app.main import app
from app.config import settings
from app.api.live_classes import exec_sql

SCHOOL_ID = "11111111-1111-1111-1111-111111111111"
ADMIN_ID = "11111111-1111-1111-1111-111111111111"

# Tiny valid MP4 header + payload bytes for real streaming & range-request testing
SAMPLE_MP4_BYTES = (
    b"\x00\x00\x00\x18ftypmp42\x00\x00\x00\x00mp42isom"
    + b"\x00\x00\x00\x08free"
    + (b"EDUSHAMIIT_VIDEO_FRAME_DATA_" * 128)
)

client = TestClient(app)


async def _find_real_actors_and_academics():
    users = await exec_sql(
        "SELECT id::TEXT AS id, school_id::TEXT AS school_id, full_name, role, email FROM public.profiles WHERE school_id = %s::UUID LIMIT 25;",
        (SCHOOL_ID,),
    )
    host = next((u for u in users if str(u.get("role", "")).lower() in ("super_admin", "admin", "teacher")), None)
    student = next((u for u in users if str(u.get("role", "")).lower() == "student"), None)

    cls_rows = await exec_sql(
        """
        SELECT ac.id::TEXT AS class_id, ac.name AS class_name,
               sec.id::TEXT AS section_id, sec.name AS section_name
        FROM public.academic_classes ac
        LEFT JOIN public.academic_sections sec ON sec.class_id = ac.id
        WHERE ac.school_id = %s::UUID
        ORDER BY ac.name LIMIT 1;
        """,
        (SCHOOL_ID,),
    )
    sub_rows = await exec_sql(
        "SELECT id::TEXT AS subject_id, name AS subject_name FROM public.subjects WHERE school_id = %s::UUID LIMIT 1;",
        (SCHOOL_ID,),
    )
    return {
        "host": host or {"id": ADMIN_ID, "school_id": SCHOOL_ID, "full_name": "King Doe", "role": "super_admin"},
        "student": student,
        "class_id": cls_rows[0]["class_id"] if cls_rows else None,
        "section_id": cls_rows[0]["section_id"] if cls_rows else None,
        "class_name": cls_rows[0]["class_name"] if cls_rows else "Class 10",
        "section_name": cls_rows[0]["section_name"] if cls_rows else "10-A",
        "subject_id": sub_rows[0]["subject_id"] if sub_rows else None,
        "subject_name": sub_rows[0]["subject_name"] if sub_rows else "Mathematics",
    }


def _make_jwt(user: dict) -> str:
    payload = {
        "sub": user["id"],
        "user_id": user["id"],
        "school_id": user.get("school_id") or SCHOOL_ID,
        "role": user.get("role") or "super_admin",
        "full_name": user.get("full_name") or "King Doe",
        "email": user.get("email") or "admin@edushamiit.edu",
    }
    return jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)


@pytest.mark.asyncio
async def test_all_recordings_scenarios_end_to_end():
    ctx = await _find_real_actors_and_academics()
    host = ctx["host"]
    host_token = _make_jwt(host)
    host_headers = {"Authorization": f"Bearer {host_token}"}

    created_recording_ids = []
    created_session_ids = []

    try:
        # 1. Baseline Dashboard & KPIs
        dash_before = client.get("/api/live-classes/dashboard/recordings", headers=host_headers)
        assert dash_before.status_code == 200, dash_before.text
        d_before = dash_before.json()["data"]
        base_total = d_before["kpis"]["total_recordings"]
        base_downloads = d_before["kpis"]["total_downloads"]
        assert isinstance(d_before["analytics_30_days"], list) and len(d_before["analytics_30_days"]) > 0
        assert "recordings_gb" in d_before["storage_breakdown"]

        # 2. Scenario A: Upload real local video via multipart endpoint
        upload_title = f"E2E Physics Wave Optics {uuid.uuid4().hex[:6]}"
        upload_resp = client.post(
            "/api/live-classes/recordings/upload",
            headers=host_headers,
            data={
                "title": upload_title,
                "description": "Uploaded full HD classroom experiment.",
                "class_id": ctx["class_id"] or "",
                "section_id": ctx["section_id"] or "",
                "subject_id": ctx["subject_id"] or "",
                "teacher_name": host.get("full_name", "King Doe"),
                "duration_minutes": "12",
                "visibility": "CLASS",
                "recording_type": "Uploaded Recording",
            },
            files={"file": ("Wave_Optics_Demo.mp4", SAMPLE_MP4_BYTES, "video/mp4")},
        )
        assert upload_resp.status_code == 200, upload_resp.text
        up_data = upload_resp.json()["data"]
        rec_id = up_data["id"]
        created_recording_ids.append(rec_id)
        assert up_data["title"] == upload_title
        assert "/stream" in up_data["recording_url"]

        # Verify uploaded recording appears in list API & KPI incremented
        list_resp = client.get(f"/api/live-classes/recordings?search={upload_title}", headers=host_headers)
        assert list_resp.status_code == 200
        assert any(i["id"] == rec_id for i in list_resp.json()["data"]["items"])

        dash_after_up = client.get("/api/live-classes/dashboard/recordings", headers=host_headers).json()["data"]
        assert dash_after_up["kpis"]["total_recordings"] == base_total + 1

        # 3. Scenario B: Stream Video (HTTP 200 Full & HTTP 206 Range + ?token= query auth)
        stream_full = client.get(f"/api/live-classes/recordings/{rec_id}/stream?token={host_token}")
        assert stream_full.status_code == 200
        assert stream_full.content == SAMPLE_MP4_BYTES
        assert stream_full.headers.get("accept-ranges") == "bytes"

        stream_partial = client.get(
            f"/api/live-classes/recordings/{rec_id}/stream?token={host_token}",
            headers={"Range": "bytes=0-63"},
        )
        assert stream_partial.status_code == 206, stream_partial.text
        assert len(stream_partial.content) == 64
        assert stream_partial.content == SAMPLE_MP4_BYTES[:64]
        assert stream_partial.headers["content-range"] == f"bytes 0-63/{len(SAMPLE_MP4_BYTES)}"

        # 4. Scenario C: View Tracking & Analytics Increment
        view_resp = client.post(f"/api/live-classes/recordings/{rec_id}/view", headers=host_headers)
        assert view_resp.status_code == 200
        assert view_resp.json()["views"] == 1

        # 5. Scenario D: Download Endpoint + downloads_count & KPI Update
        dl_resp = client.get(f"/api/live-classes/recordings/{rec_id}/download?token={host_token}")
        assert dl_resp.status_code == 200, dl_resp.text
        assert dl_resp.content == SAMPLE_MP4_BYTES
        assert "attachment" in dl_resp.headers.get("content-disposition", "").lower()

        dash_after_dl = client.get("/api/live-classes/dashboard/recordings", headers=host_headers).json()["data"]
        assert dash_after_dl["kpis"]["total_downloads"] == base_downloads + 1

        # 6. Scenario E: Edit Recording (Title, Visibility, Duration, Notes)
        edited_title = f"{upload_title} (Edited)"
        edit_resp = client.patch(
            f"/api/live-classes/recordings/{rec_id}",
            headers=host_headers,
            json={
                "title": edited_title,
                "description": "Updated curriculum notes after edit.",
                "visibility": "SCHOOL",
                "duration_minutes": 18,
            },
        )
        assert edit_resp.status_code == 200, edit_resp.text
        assert edit_resp.json()["data"]["title"] == edited_title
        assert edit_resp.json()["data"]["visibility"] == "SCHOOL"
        assert edit_resp.json()["data"]["duration"] == 1080

        # 7. Scenario F: Share Recording (Class/Sections + Individual Search) & Revoke
        if ctx["class_id"]:
            share_cls_resp = client.post(
                f"/api/live-classes/recordings/{rec_id}/share/batch",
                headers=host_headers,
                json={
                    "mode": "class_sections",
                    "class_id": ctx["class_id"],
                    "class_name": ctx["class_name"],
                    "sections": [{"id": ctx["section_id"], "name": ctx["section_name"]}] if ctx["section_id"] else [],
                    "include_students": True,
                    "include_teachers": True,
                    "access_level": "DOWNLOAD",
                },
            )
            assert share_cls_resp.status_code == 200, share_cls_resp.text
            assert share_cls_resp.json()["data"]["shared_count"] >= 1

        share_ind_resp = client.post(
            f"/api/live-classes/recordings/{rec_id}/share/batch",
            headers=host_headers,
            json={
                "mode": "individual",
                "access_level": "VIEW",
                "users": [
                    {
                        "id": (ctx["student"]["id"] if ctx["student"] else host["id"]),
                        "full_name": (ctx["student"]["full_name"] if ctx["student"] else host["full_name"]),
                        "role": (ctx["student"]["role"] if ctx["student"] else "teacher"),
                    }
                ],
            },
        )
        assert share_ind_resp.status_code == 200, share_ind_resp.text

        shares_list = client.get(f"/api/live-classes/recordings/{rec_id}/shares", headers=host_headers)
        assert shares_list.status_code == 200
        shares = shares_list.json()["data"]
        assert len(shares) >= 1

        revoke_resp = client.delete(
            f"/api/live-classes/recordings/{rec_id}/shares/{shares[0]['id']}",
            headers=host_headers,
        )
        assert revoke_resp.status_code == 200

        # 8. Scenario G: Settings Persistence & Student Download Policy
        orig_cfg = client.get("/api/live-classes/recordings/settings", headers=host_headers).json()["data"]
        save_cfg = client.post(
            "/api/live-classes/recordings/settings",
            headers=host_headers,
            json={
                "auto_recording": True,
                "cloud_storage": True,
                "default_retention_days": 365,
                "recording_quality": "Full HD (1080p)",
                "allow_student_download": False,
            },
        )
        assert save_cfg.status_code == 200
        assert save_cfg.json()["data"]["recording_quality"] == "Full HD (1080p)"

        if ctx["student"]:
            stu_token = _make_jwt(ctx["student"])
            stu_dl = client.get(f"/api/live-classes/recordings/{rec_id}/download?token={stu_token}")
            assert stu_dl.status_code == 403

        # Restore original settings
        client.post("/api/live-classes/recordings/settings", headers=host_headers, json=orig_cfg)

        # 9. Scenario H: Live Class Recording Title Sync (NEVER "Live Class Recording")
        session_topic = f"Thermodynamics Heat Transfer {uuid.uuid4().hex[:5]}"
        inst_resp = client.post(
            "/api/live-classes/sessions/instant",
            headers=host_headers,
            json={
                "title": session_topic,
                "class_id": ctx["class_id"],
                "section_id": ctx["section_id"],
                "subject_id": ctx["subject_id"],
                "duration_minutes": 45,
                "recording_enabled": True,
            },
        )
        assert inst_resp.status_code == 200, inst_resp.text
        sess_data = inst_resp.json()["data"]
        sess_id = sess_data.get("session_id") or sess_data.get("id")
        created_session_ids.append(sess_id)

        assert client.post(f"/api/live-classes/{sess_id}/start", headers=host_headers).status_code == 200
        assert client.post(f"/api/live-classes/sessions/{sess_id}/recordings/toggle", headers=host_headers).status_code == 200

        # Simulate browser MediaRecorder uploading real captured bytes linked to the live class session
        live_class_title = f"{session_topic} ({ctx['class_name']} - {ctx['section_name']})"
        live_upload_resp = client.post(
            "/api/live-classes/recordings/upload",
            headers=host_headers,
            data={
                "title": live_class_title,
                "description": "Recorded live class lecture with whiteboard & video.",
                "class_id": ctx["class_id"] or "",
                "section_id": ctx["section_id"] or "",
                "subject_id": ctx["subject_id"] or "",
                "live_class_id": sess_id,
                "recording_type": "Live Class",
                "duration_seconds": "125",
                "visibility": "CLASS",
            },
            files={"file": ("live_class_capture.webm", SAMPLE_MP4_BYTES, "video/webm")},
        )
        assert live_upload_resp.status_code == 200, live_upload_resp.text

        # Stop recording & End live class -> must preserve real uploaded recording without overwriting or creating 0 B duplicate
        toggle_off = client.post(f"/api/live-classes/sessions/{sess_id}/recordings/toggle", headers=host_headers)
        assert toggle_off.status_code == 200
        assert client.post(f"/api/live-classes/{sess_id}/end", headers=host_headers).status_code == 200

        live_rec_rows = await exec_sql(
            "SELECT id::TEXT AS id, title, file_size, recording_url FROM public.live_class_recordings WHERE live_class_id = %s::UUID AND deleted_at IS NULL;",
            (sess_id,),
        )
        assert len(live_rec_rows) == 1, f"Expected exactly 1 recording, got {live_rec_rows}"
        live_rec_id = live_rec_rows[0]["id"]
        created_recording_ids.append(live_rec_id)
        assert int(live_rec_rows[0]["file_size"] or 0) == len(SAMPLE_MP4_BYTES)
        assert "/stream" in (live_rec_rows[0]["recording_url"] or "")
        assert live_rec_rows[0]["title"].lower() != "live class recording"
        assert session_topic in live_rec_rows[0]["title"]

        # 10. Scenario I: Single Delete & Bulk Delete + Verify KPIs Restored
        del_resp = client.delete(f"/api/live-classes/recordings/{rec_id}", headers=host_headers)
        assert del_resp.status_code == 200
        created_recording_ids.remove(rec_id)

        bulk_del_resp = client.post(
            "/api/live-classes/recordings/bulk-delete",
            headers=host_headers,
            json={"recording_ids": [live_rec_id]},
        )
        assert bulk_del_resp.status_code == 200
        created_recording_ids.remove(live_rec_id)

        dash_final = client.get("/api/live-classes/dashboard/recordings", headers=host_headers).json()["data"]
        assert dash_final["kpis"]["total_recordings"] == base_total

        print(json.dumps({
            "status": "ALL_10_RECORDING_E2E_SCENARIOS_PASSED",
            "uploaded_title_verified": edited_title,
            "live_class_recording_title_verified": live_rec_rows[0]["title"],
            "stream_206_range_verified": True,
            "download_and_kpi_increment_verified": True,
            "share_and_revoke_verified": True,
            "settings_and_policy_verified": True,
        }))
    finally:
        # Ensure clean database state even on assertion failure
        for rid in created_recording_ids:
            try:
                await exec_sql("DELETE FROM public.live_class_recordings WHERE id = %s::UUID;", (rid,), fetch=False)
            except Exception:
                pass
        for sid in created_session_ids:
            try:
                await exec_sql("DELETE FROM public.live_classes WHERE id = %s::UUID;", (sid,), fetch=False)
            except Exception:
                pass


if __name__ == "__main__":
    import asyncio
    asyncio.run(test_all_recordings_scenarios_end_to_end())
    print("E2E Recordings verification script completed with 0 failures!")
