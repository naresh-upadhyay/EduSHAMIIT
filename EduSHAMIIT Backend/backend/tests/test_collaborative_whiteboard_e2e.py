import io
import os
import sys
import uuid

os.environ.setdefault("TESTING", "1")
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import pytest
from fastapi.testclient import TestClient
from jose import jwt
from PIL import Image

from app.main import app
from app.config import settings
from app.middleware.auth import get_current_user, require_school_id

SCHOOL_A = "11111111-1111-1111-1111-111111111111"
SCHOOL_B = "22222222-2222-2222-2222-222222222222"
TEACHER_ID = "e1141a33-2d9d-4a52-a27b-9ddeeefd41b9"
STUDENT_ID = "10000000-0000-0000-0000-000000000002"


def _make_token(user_id: str, role: str, school_id: str = SCHOOL_A, full_name: str = "Test User") -> str:
    secret = settings.SUPABASE_JWT_SECRET or settings.JWT_SECRET
    return jwt.encode(
        {
            "sub": user_id,
            "role": role,
            "school_id": school_id,
            "full_name": full_name,
        },
        secret,
        algorithm="HS256",
    )


@pytest.fixture(autouse=True)
def clean_overrides():
    saved = dict(app.dependency_overrides)
    yield
    app.dependency_overrides.clear()
    app.dependency_overrides.update(saved)


def _client_as(user_id: str, role: str, school_id: str = SCHOOL_A, name: str = "User"):
    app.dependency_overrides[get_current_user] = lambda: {
        "id": user_id,
        "school_id": school_id,
        "role": role,
        "full_name": name,
    }
    app.dependency_overrides[require_school_id] = lambda: school_id
    return TestClient(app)


def test_whiteboard_templates_and_seeded_board():
    client = _client_as(TEACHER_ID, "teacher", SCHOOL_A, "R. Kumar")
    res_tpl = client.get("/api/whiteboards/templates")
    assert res_tpl.status_code == 200
    tpls = res_tpl.json()["data"]
    assert len(tpls) >= 10
    assert any(t["id"] == "mathematics" for t in tpls)

    res_list = client.get("/api/whiteboards")
    assert res_list.status_code == 200
    assert isinstance(res_list.json()["data"], list)


def test_full_whiteboard_lifecycle_pages_ops_versions_export():
    client = _client_as(TEACHER_ID, "teacher", SCHOOL_A, "R. Kumar")

    # 1. Create board
    c_res = client.post("/api/whiteboards", json={
        "title": "E2E Physics Lecture Board",
        "template_type": "physics",
        "collaboration_enabled": False,
    })
    assert c_res.status_code == 200
    wb = c_res.json()["data"]
    wb_id = wb["id"]
    p1_id = wb["pages"][0]["id"]

    # 2. Multi-page operations: create, update, duplicate, reorder, delete
    p2_res = client.post(f"/api/whiteboards/{wb_id}/pages", json={
        "title": "2. Kinematics Graphs",
        "background_type": "graph",
    })
    assert p2_res.status_code == 200
    p2_id = p2_res.json()["data"]["id"]

    upd_p2 = client.patch(f"/api/whiteboards/{wb_id}/pages/{p2_id}", json={
        "title": "2. Velocity Graphs",
        "is_locked": True,
    })
    assert upd_p2.status_code == 200
    assert upd_p2.json()["data"]["is_locked"] is True

    dup_res = client.post(f"/api/whiteboards/{wb_id}/pages/{p2_id}/duplicate")
    assert dup_res.status_code == 200
    p3_id = dup_res.json()["data"]["id"]

    reord = client.post(f"/api/whiteboards/{wb_id}/pages/reorder", json={"page_ids": [p1_id, p3_id, p2_id]})
    assert reord.status_code == 200

    del_p3 = client.delete(f"/api/whiteboards/{wb_id}/pages/{p3_id}")
    assert del_p3.status_code == 200

    # 3. Idempotent Operations (stroke, equation, sticky_note, text)
    op_id_1 = str(uuid.uuid4())
    op_res = client.post(f"/api/whiteboards/{wb_id}/operations", json={
        "page_id": p1_id,
        "operation_id": op_id_1,
        "operation_type": "object.create",
        "object_id": "eq_kinematics_1",
        "object_type": "equation",
        "operation_data": {
            "id": "eq_kinematics_1",
            "type": "equation",
            "data": {"x": 120, "y": 100, "width": 280, "height": 64, "latex": "v = u + at", "display": "v = u + at"},
        },
    })
    assert op_res.status_code == 200
    rev_after_eq = op_res.json()["data"]["revision"]
    assert op_res.json()["data"]["duplicate"] is False

    # Replay exact same operation_id -> idempotent duplicate!
    op_dup = client.post(f"/api/whiteboards/{wb_id}/operations", json={
        "page_id": p1_id,
        "operation_id": op_id_1,
        "operation_type": "object.create",
        "object_id": "eq_kinematics_1",
        "object_type": "equation",
        "operation_data": {"id": "eq_kinematics_1", "type": "equation", "data": {}},
    })
    assert op_dup.status_code == 200
    assert op_dup.json()["data"]["duplicate"] is True
    assert op_dup.json()["data"]["revision"] == rev_after_eq

    # 4. Version Checkpoint & Restore
    ver_res = client.post(f"/api/whiteboards/{wb_id}/versions", json={"version_name": "Kinematics Checkpoint"})
    assert ver_res.status_code == 200
    ver_id = ver_res.json()["data"]["id"]

    # Add a stroke after checkpoint, then restore checkpoint
    client.post(f"/api/whiteboards/{wb_id}/operations", json={
        "page_id": p1_id,
        "operation_id": str(uuid.uuid4()),
        "operation_type": "object.create",
        "object_id": "tmp_stroke",
        "object_type": "stroke",
        "operation_data": {"id": "tmp_stroke", "type": "stroke", "data": {"points": [[10, 10], [80, 80]]}},
    })
    rest_res = client.post(f"/api/whiteboards/{wb_id}/versions/{ver_id}/restore")
    assert rest_res.status_code == 200
    restored_p1_objs = [o["id"] for o in rest_res.json()["data"]["pages"][0]["objects"]]
    assert "eq_kinematics_1" in restored_p1_objs
    assert "tmp_stroke" not in restored_p1_objs

    # 5. Image Asset Upload & Retrieval
    img = Image.new("RGB", (120, 80), color=(37, 99, 235))
    img_buf = io.BytesIO()
    img.save(img_buf, format="PNG")
    img_buf.seek(0)
    up_res = client.post(
        f"/api/whiteboards/{wb_id}/assets",
        data={"page_id": p1_id},
        files={"file": ("diagram.png", img_buf.getvalue(), "image/png")},
    )
    assert up_res.status_code == 200
    asset_id = up_res.json()["data"]["id"]
    dl_asset = client.get(f"/api/whiteboards/{wb_id}/assets/{asset_id}/content")
    assert dl_asset.status_code == 200
    assert dl_asset.content.startswith(b"\x89PNG")

    # Reject invalid mime type
    bad_up = client.post(
        f"/api/whiteboards/{wb_id}/assets",
        files={"file": ("malware.exe", b"MZ...", "application/x-msdownload")},
    )
    assert bad_up.status_code == 400

    # 6. Export Multi-page PDF & PNG
    exp_pdf = client.post(f"/api/whiteboards/{wb_id}/export", json={"format": "PDF", "scope": "all_pages"})
    assert exp_pdf.status_code == 200
    pdf_dl = client.get(exp_pdf.json()["data"]["download_url"])
    assert pdf_dl.status_code == 200
    assert pdf_dl.content.startswith(b"%PDF-")

    exp_png = client.post(f"/api/whiteboards/{wb_id}/export", json={"format": "PNG", "scope": "current_page", "page_id": p1_id})
    assert exp_png.status_code == 200
    png_dl = client.get(exp_png.json()["data"]["download_url"])
    assert png_dl.status_code == 200
    assert png_dl.content.startswith(b"\x89PNG")

    # 7. Audit Log & Share
    sh_res = client.post(f"/api/whiteboards/{wb_id}/share", json={"share_type": "class", "target_label": "Class 11 - A", "access_level": "VIEW"})
    assert sh_res.status_code == 200
    aud_res = client.get(f"/api/whiteboards/{wb_id}/audit-logs")
    assert aud_res.status_code == 200
    assert len(aud_res.json()["data"]) >= 4


def test_rbac_permissions_and_institution_isolation():
    teacher_client = _client_as(TEACHER_ID, "teacher", SCHOOL_A, "R. Kumar")
    wb = teacher_client.post("/api/whiteboards", json={"title": "RBAC Board", "collaboration_enabled": False}).json()["data"]
    wb_id = wb["id"]
    p1_id = wb["pages"][0]["id"]

    # Student cannot create whiteboard
    student_client = _client_as(STUDENT_ID, "student", SCHOOL_A, "Aarav Sharma")
    s_create = student_client.post("/api/whiteboards", json={"title": "Rogue Board"})
    assert s_create.status_code == 403

    # Student cannot draw when teacher_only / collaboration disabled
    s_op = student_client.post(f"/api/whiteboards/{wb_id}/operations", json={
        "page_id": p1_id,
        "operation_id": str(uuid.uuid4()),
        "operation_type": "object.create",
        "object_id": "stu_stroke_1",
        "object_type": "stroke",
        "operation_data": {"points": [[0, 0], [20, 20]]},
    })
    assert s_op.status_code == 403

    # Teacher grants student EDIT permission
    teacher_client = _client_as(TEACHER_ID, "teacher", SCHOOL_A, "R. Kumar")
    grant = teacher_client.patch(f"/api/whiteboards/{wb_id}/permissions", json={
        "target_user_id": STUDENT_ID,
        "permission_type": "EDIT",
    })
    assert grant.status_code == 200

    # Student CAN now edit
    student_client = _client_as(STUDENT_ID, "student", SCHOOL_A, "Aarav Sharma")
    s_op_ok = student_client.post(f"/api/whiteboards/{wb_id}/operations", json={
        "page_id": p1_id,
        "operation_id": str(uuid.uuid4()),
        "operation_type": "object.create",
        "object_id": "stu_stroke_2",
        "object_type": "stroke",
        "operation_data": {"id": "stu_stroke_2", "type": "stroke", "data": {"points": [[15, 15], [50, 50]]}},
    })
    assert s_op_ok.status_code == 200

    # Teacher revokes student EDIT permission
    teacher_client = _client_as(TEACHER_ID, "teacher", SCHOOL_A, "R. Kumar")
    revoke = teacher_client.patch(f"/api/whiteboards/{wb_id}/permissions", json={
        "target_user_id": STUDENT_ID,
        "permission_type": "VIEW",
    })
    assert revoke.status_code == 200

    # Student can NO LONGER edit
    student_client = _client_as(STUDENT_ID, "student", SCHOOL_A, "Aarav Sharma")
    s_op_blocked = student_client.post(f"/api/whiteboards/{wb_id}/operations", json={
        "page_id": p1_id,
        "operation_id": str(uuid.uuid4()),
        "operation_type": "object.create",
        "object_id": "stu_stroke_3",
        "object_type": "stroke",
        "operation_data": {"points": [[5, 5], [10, 10]]},
    })
    assert s_op_blocked.status_code == 403

    # Cross-institution tenant isolation check
    other_school_client = _client_as(TEACHER_ID, "teacher", SCHOOL_B, "Outsider")
    cross_get = other_school_client.get(f"/api/whiteboards/{wb_id}")
    assert cross_get.status_code in (403, 404)


def test_realtime_websocket_collaboration_and_reconnect_sync():
    teacher_client = _client_as(TEACHER_ID, "teacher", SCHOOL_A, "R. Kumar")
    wb = teacher_client.post("/api/whiteboards", json={"title": "Realtime Collab Board", "collaboration_enabled": True}).json()["data"]
    wb_id = wb["id"]
    p1_id = wb["pages"][0]["id"]
    # Initially grant student VIEW only so we test live denial & grant
    teacher_client.patch(f"/api/whiteboards/{wb_id}/permissions", json={"target_user_id": STUDENT_ID, "permission_type": "VIEW"})

    app.dependency_overrides.clear()
    raw_client = TestClient(app)
    teacher_tok = _make_token(TEACHER_ID, "teacher", SCHOOL_A, "R. Kumar")
    student_tok = _make_token(STUDENT_ID, "student", SCHOOL_A, "Aarav Sharma")

    with raw_client.websocket_connect(f"/ws/whiteboards/{wb_id}?token={teacher_tok}") as ws_teacher:
        open_msg = ws_teacher.receive_json()
        assert open_msg["event_type"] == "whiteboard.opened"

        with raw_client.websocket_connect(f"/ws/whiteboards/{wb_id}?token={student_tok}") as ws_student:
            s_open = ws_student.receive_json()
            assert s_open["event_type"] == "whiteboard.opened"
            # Teacher receives collaborator.joined
            joined_ev = ws_teacher.receive_json()
            assert joined_ev["event_type"] == "collaborator.joined"

            # 1. Teacher draws line -> student receives object.created + teacher gets ACK
            ws_teacher.send_json({
                "event_type": "operation",
                "page_id": p1_id,
                "operation_id": str(uuid.uuid4()),
                "operation_type": "object.create",
                "object_id": "ws_line_1",
                "object_type": "line",
                "payload": {"id": "ws_line_1", "type": "line", "data": {"x1": 10, "y1": 20, "x2": 200, "y2": 20}},
            })
            t_ack = ws_teacher.receive_json()
            assert t_ack["event_type"] == "whiteboard.saved"
            s_recv = ws_student.receive_json()
            assert s_recv["event_type"] == "object.created"
            assert s_recv["payload"]["object_id"] == "ws_line_1"
            last_rev_seen_by_student = s_recv["revision"]

            # 2. Unauthorized student tries drawing -> receives sync_failed
            ws_student.send_json({
                "event_type": "operation",
                "page_id": p1_id,
                "operation_id": str(uuid.uuid4()),
                "operation_type": "object.create",
                "object_id": "stu_bad_1",
                "object_type": "stroke",
                "payload": {"points": [[0, 0], [10, 10]]},
            })
            err_ev = ws_student.receive_json()
            assert err_ev["event_type"] == "whiteboard.sync_failed"

        # 3. Student has disconnected; Teacher continues drawing while student is offline
        _ = ws_teacher.receive_json()  # collaborator.left
        ws_teacher.send_json({
            "event_type": "operation",
            "page_id": p1_id,
            "operation_id": str(uuid.uuid4()),
            "operation_type": "object.create",
            "object_id": "ws_line_missed",
            "object_type": "line",
            "payload": {"id": "ws_line_missed", "type": "line", "data": {"x1": 50, "y1": 50, "x2": 150, "y2": 150}},
        })
        missed_ack = ws_teacher.receive_json()
        assert missed_ack["event_type"] == "whiteboard.saved"

    # 4. Student reconnects and recovers missed operations since last revision
    student_client = _client_as(STUDENT_ID, "student", SCHOOL_A, "Aarav Sharma")
    sync_res = student_client.get(f"/api/whiteboards/{wb_id}/sync?since_revision={last_rev_seen_by_student}")
    assert sync_res.status_code == 200
    ops = sync_res.json()["data"]["operations"]
    assert any(o["object_id"] == "ws_line_missed" for o in ops)
