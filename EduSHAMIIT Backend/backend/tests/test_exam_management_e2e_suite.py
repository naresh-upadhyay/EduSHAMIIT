"""
Production-Grade Comprehensive E2E Test Suite for Exam Management
Validates all features and edge cases implemented:
1. Dynamic Dashboard Overview (Real DB stats, Dynamic past 8-months performance chart, Dynamic top performers)
2. Date Range Filtering on Examinations Table (start_date, end_date)
3. Bulk Status Updates (POST /api/exams/bulk/status) with error handling & DB verification
4. Bulk Publish Examination Results (POST /api/exams/bulk/publish)
5. Bulk Exam Schedule Export to CSV (POST /api/exams/bulk/export-schedules)
6. Dual UUID Resolution in Proctoring / Invigilator Actions (rpc_execute_invigilator_action)
7. Question Bank Export Template (CSV format and headers)
"""
import pytest
import uuid
import json
import csv
import io
import psycopg2
from datetime import datetime
from fastapi.testclient import TestClient
from jose import jwt

from app.main import app
from app.config import settings

client = TestClient(app)

SCHOOL_ID = "11111111-1111-1111-1111-111111111111"
USER_ID = "10000000-0000-0000-0000-000000000002"

def make_token(school_id: str = SCHOOL_ID, user_id: str = USER_ID, role: str = "super_admin"):
    payload = {
        "sub": user_id,
        "school_id": school_id,
        "role": role,
        "email": "superadmin@edushamiit.com",
        "exp": 9999999999
    }
    return jwt.encode(payload, settings.JWT_SECRET, algorithm="HS256")

HEADERS_ADMIN = {
    "X-School-ID": SCHOOL_ID,
    "Authorization": f"Bearer {make_token()}"
}


def get_db_connection():
    conn = psycopg2.connect(settings.DATABASE_URL)
    conn.autocommit = True
    return conn


# ============================================================================
# 1. DYNAMIC DASHBOARD OVERVIEW TESTS
# ============================================================================

def test_dynamic_dashboard_overview():
    """Verify overview returns dynamic DB KPIs, past 8 months chart, and dynamic top performers."""
    resp = client.get("/api/exams/dashboard/overview", headers=HEADERS_ADMIN)
    assert resp.status_code == 200, f"Expected 200, got {resp.status_code}: {resp.text}"
    body = resp.json()
    data = body.get("data", body)

    # Verify structure
    assert "kpis" in data, "Overview response must contain 'kpis'"
    assert "tab_counts" in data, "Overview response must contain 'tab_counts'"
    assert "performance_chart" in data, "Overview response must contain 'performance_chart'"
    assert "top_performers" in data, "Overview response must contain 'top_performers'"

    # Verify KPIs fields
    kpis = data["kpis"]
    assert "total_exams" in kpis
    assert "total_students_appeared" in kpis
    assert "average_score" in kpis
    assert "pass_percentage" in kpis

    # Verify dynamic past 8-months chart length and fields
    chart = data["performance_chart"]
    assert isinstance(chart, list)
    assert len(chart) == 8, f"Expected 8 monthly data points, got {len(chart)}"
    for item in chart:
        assert "month" in item
        assert "pass_pct" in item
        assert "fail_pct" in item

    # Verify tab counts
    tab_counts = data["tab_counts"]
    for tab in ["all", "upcoming", "ongoing", "completed"]:
        assert tab in tab_counts
        assert isinstance(tab_counts[tab], int)


# ============================================================================
# 2. DATE RANGE FILTERING ON EXAMS TABLE
# ============================================================================

def test_exams_date_range_filtering():
    """Verify start_date and end_date query parameters properly filter exams."""
    all_resp = client.get("/api/exams?status_tab=all&page=1&page_size=20", headers=HEADERS_ADMIN)
    assert all_resp.status_code == 200
    all_data = all_resp.json()
    exams = all_data.get("exams", [])

    if exams:
        first_exam_date = exams[0].get("exam_date")
        if first_exam_date:
            date_str = str(first_exam_date).split("T")[0]
            filtered_resp = client.get(
                f"/api/exams?status_tab=all&start_date={date_str}&end_date={date_str}&page=1&page_size=20",
                headers=HEADERS_ADMIN
            )
            assert filtered_resp.status_code == 200
            filtered_data = filtered_resp.json()
            filtered_exams = filtered_data.get("exams", [])
            for e in filtered_exams:
                e_date = str(e.get("exam_date", "")).split("T")[0]
                assert e_date == date_str, f"Exam date {e_date} is outside requested range {date_str}"


# ============================================================================
# 3. BULK STATUS UPDATES
# ============================================================================

def test_bulk_status_update_and_edge_cases():
    """Verify POST /api/exams/bulk/status for batch status updates and validation."""
    conn = get_db_connection()
    exam_id_1 = str(uuid.uuid4())
    exam_id_2 = str(uuid.uuid4())
    today = datetime.utcnow().strftime("%Y-%m-%d")

    try:
        # Create 2 test exams with JSONB target_classes
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO exams (id, school_id, title, target_classes, exam_date, total_marks, status, created_at)
                VALUES
                (%s, %s, 'Bulk Test Exam 1', %s::jsonb, %s, 100, 'Scheduled', NOW()),
                (%s, %s, 'Bulk Test Exam 2', %s::jsonb, %s, 100, 'Scheduled', NOW());
            """, (exam_id_1, SCHOOL_ID, json.dumps(["Class 10"]), today, exam_id_2, SCHOOL_ID, json.dumps(["Class 10"]), today))

        # Edge case: Empty exam_ids list should return 400
        empty_resp = client.post("/api/exams/bulk/status", json={"exam_ids": [], "status": "Ongoing"}, headers=HEADERS_ADMIN)
        assert empty_resp.status_code == 400

        # Edge case: Invalid status value should return 400
        invalid_resp = client.post("/api/exams/bulk/status", json={"exam_ids": [exam_id_1], "status": "InvalidStatus"}, headers=HEADERS_ADMIN)
        assert invalid_resp.status_code == 400

        # Valid bulk update to 'Ongoing'
        bulk_resp = client.post(
            "/api/exams/bulk/status",
            json={"exam_ids": [exam_id_1, exam_id_2], "status": "Ongoing"},
            headers=HEADERS_ADMIN
        )
        assert bulk_resp.status_code == 200
        result = bulk_resp.json()
        assert result.get("success") is True
        assert result.get("affected_count", result.get("updated_count")) == 2

        # Verify in DB
        with conn.cursor() as cur:
            cur.execute("SELECT status FROM exams WHERE id IN (%s, %s);", (exam_id_1, exam_id_2))
            rows = cur.fetchall()
            assert len(rows) == 2
            assert all(r[0].lower() == "ongoing" for r in rows)

        # Revert back to 'Scheduled'
        revert_resp = client.post(
            "/api/exams/bulk/status",
            json={"exam_ids": [exam_id_1, exam_id_2], "status": "Scheduled"},
            headers=HEADERS_ADMIN
        )
        assert revert_resp.status_code == 200
        assert revert_resp.json().get("affected_count", revert_resp.json().get("updated_count")) == 2

    finally:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM exams WHERE id IN (%s, %s);", (exam_id_1, exam_id_2))
        conn.close()


# ============================================================================
# 4. BULK PUBLISH EXAMS
# ============================================================================

def test_bulk_publish_exams():
    """Verify POST /api/exams/bulk/publish sets is_published and status to completed."""
    conn = get_db_connection()
    exam_id = str(uuid.uuid4())
    today = datetime.utcnow().strftime("%Y-%m-%d")

    try:
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO exams (id, school_id, title, target_classes, exam_date, total_marks, status, is_published, created_at)
                VALUES (%s, %s, 'Publish Test Exam', %s::jsonb, %s, 100, 'Scheduled', FALSE, NOW());
            """, (exam_id, SCHOOL_ID, json.dumps(["Class 10"]), today))

        resp = client.post(
            "/api/exams/bulk/publish",
            json={"exam_ids": [exam_id]},
            headers=HEADERS_ADMIN
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data.get("success") is True
        assert data.get("affected_count", data.get("updated_count")) == 1

        # Check DB
        with conn.cursor() as cur:
            cur.execute("SELECT status, is_published FROM exams WHERE id = %s;", (exam_id,))
            row = cur.fetchone()
            assert row is not None
            assert row[0].lower() == "completed"
            assert row[1] is True

    finally:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM exams WHERE id = %s;", (exam_id,))
        conn.close()


# ============================================================================
# 5. BULK EXPORT SCHEDULES
# ============================================================================

def test_bulk_export_schedules():
    """Verify POST /api/exams/bulk/export-schedules produces structured CSV."""
    conn = get_db_connection()
    exam_id = str(uuid.uuid4())
    today = datetime.utcnow().strftime("%Y-%m-%d")

    try:
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO exams (id, school_id, title, target_classes, exam_date, total_marks, status, created_at)
                VALUES (%s, %s, 'CSV Schedule Exam', %s::jsonb, %s, 100, 'Scheduled', NOW());
            """, (exam_id, SCHOOL_ID, json.dumps(["Class 12"]), today))

        resp = client.post(
            "/api/exams/bulk/export-schedules",
            json={"exam_ids": [exam_id]},
            headers=HEADERS_ADMIN
        )
        assert resp.status_code == 200
        assert "text/csv" in resp.headers.get("content-type", "")

        csv_reader = csv.reader(io.StringIO(resp.text))
        rows = list(csv_reader)
        assert len(rows) >= 2, "CSV should contain headers and at least 1 data row"

        headers = rows[0]
        assert "Exam Title" in headers
        assert "Exam Date" in headers
        assert "Total Marks" in headers

        # Data row
        data_row = rows[1]
        assert data_row[1] == "CSV Schedule Exam"

    finally:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM exams WHERE id = %s;", (exam_id,))
        conn.close()


# ============================================================================
# 6. DUAL UUID RESOLUTION IN PROCTORING ACTIONS (MIGRATION 506)
# ============================================================================

def test_dual_uuid_resolution_in_proctoring_action():
    """
    Directly tests rpc_execute_invigilator_action stored procedure.
    Validates that when candidate_id is profile.id (instead of profile.user_id),
    the RPC resolves through profiles and increments warnings on exam_sessions.
    """
    conn = get_db_connection()
    exam_id = str(uuid.uuid4())
    auth_user_id = str(uuid.uuid4())
    profile_id = str(uuid.uuid4())
    today = datetime.utcnow().strftime("%Y-%m-%d")

    try:
        with conn.cursor() as cur:
            # 1. Create a dummy profile with distinct id vs user_id (status must be 'Active')
            cur.execute("""
                INSERT INTO profiles (id, user_id, school_id, full_name, role, status, created_at)
                VALUES (%s, %s, %s, 'Dual UUID Test Student', 'student', 'Active', NOW())
                ON CONFLICT (id) DO NOTHING;
            """, (profile_id, auth_user_id, SCHOOL_ID))

            # 2. Create exam
            cur.execute("""
                INSERT INTO exams (id, school_id, title, target_classes, exam_date, total_marks, status, created_at)
                VALUES (%s, %s, 'Proctor RPC Test Exam', %s::jsonb, %s, 100, 'Ongoing', NOW());
            """, (exam_id, SCHOOL_ID, json.dumps(["Class 10"]), today))

            # 3. Create exam session referencing student_id = profile_id (the profiles.id foreign key)
            cur.execute("""
                INSERT INTO exam_sessions (exam_id, student_id, school_id, status, warnings_count, camera_active, mic_active, updated_at)
                VALUES (%s, %s, %s, 'in_progress', 0, TRUE, TRUE, NOW());
            """, (exam_id, profile_id, SCHOOL_ID))

            # 4. Execute RPC with p_candidate_id = auth_user_id (THE AUTH USER_ID, which is different from profile_id!)
            # This verifies the dual-UUID resolution in Migration 506 where student_id in profiles.user_id = v_cid
            cur.execute("""
                SELECT rpc_execute_invigilator_action(
                    %s::UUID,
                    %s::UUID,
                    %s::UUID,
                    'Test Invigilator',
                    'teacher',
                    'warn',
                    %s::JSONB,
                    %s::JSONB
                );
            """, (
                SCHOOL_ID,
                exam_id,
                USER_ID,
                json.dumps([auth_user_id]),
                json.dumps({"reason": "Stay focused on the exam screen!"})
            ))
            rpc_res = cur.fetchone()[0]

            assert rpc_res.get("success") is True, f"RPC execution failed: {rpc_res}"
            results = rpc_res.get("results", [])
            assert len(results) > 0, f"Expected results array, got: {rpc_res}"
            first_res = results[0]
            assert first_res.get("warnings_count") == 1
            # Verify dual UUID matching succeeded
            assert str(first_res.get("candidate_id")) == auth_user_id
            assert str(first_res.get("student_id")) == auth_user_id

            # 5. Verify exam_incidents table has logged the warning
            cur.execute("""
                SELECT violation_type, description
                FROM exam_incidents
                WHERE exam_id = %s
                ORDER BY created_at DESC LIMIT 1;
            """, (exam_id,))
            incident = cur.fetchone()
            assert incident is not None, "Incident record must be created"
            assert incident[0] == "proctor_warning"
            assert "Stay focused" in incident[1]

            # 6. Test media toggle: force_disable_cam
            cur.execute("""
                SELECT rpc_execute_invigilator_action(
                    %s::UUID,
                    %s::UUID,
                    %s::UUID,
                    'Test Invigilator',
                    'teacher',
                    'force_disable_cam',
                    %s::JSONB,
                    %s::JSONB
                );
            """, (
                SCHOOL_ID,
                exam_id,
                USER_ID,
                json.dumps([profile_id]),
                json.dumps({"reason": "Camera check"})
            ))
            cam_res = cur.fetchone()[0]
            assert cam_res.get("success") is True
            cam_results = cam_res.get("results", [])
            assert len(cam_results) > 0
            assert cam_results[0].get("camera_active") is False

            # 7. Test media toggle: force_mute_mic
            cur.execute("""
                SELECT rpc_execute_invigilator_action(
                    %s::UUID,
                    %s::UUID,
                    %s::UUID,
                    'Test Invigilator',
                    'teacher',
                    'force_mute_mic',
                    %s::JSONB,
                    %s::JSONB
                );
            """, (
                SCHOOL_ID,
                exam_id,
                USER_ID,
                json.dumps([profile_id]),
                json.dumps({"reason": "Mute microphone"})
            ))
            mic_res = cur.fetchone()[0]
            assert mic_res.get("success") is True
            mic_results = mic_res.get("results", [])
            assert len(mic_results) > 0
            assert mic_results[0].get("mic_active") is False

    finally:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM exam_incidents WHERE exam_id = %s;", (exam_id,))
            cur.execute("DELETE FROM exam_sessions WHERE exam_id = %s;", (exam_id,))
            cur.execute("DELETE FROM exams WHERE id = %s;", (exam_id,))
            cur.execute("DELETE FROM profiles WHERE id = %s;", (profile_id,))
        conn.close()


# ============================================================================
# 7. QUESTION BANK TEMPLATE EXPORT
# ============================================================================

def test_question_bank_export_template():
    """Verify GET /api/exams/question-bank/export-template returns downloadable CSV with correct schema."""
    resp = client.get("/api/exams/question-bank/export-template?type=all&subject=Physics", headers=HEADERS_ADMIN)
    assert resp.status_code == 200
    assert "text/csv" in resp.headers.get("content-type", "")

    csv_reader = csv.reader(io.StringIO(resp.text))
    rows = list(csv_reader)
    assert len(rows) >= 2, "Export should have header and sample questions"

    headers = rows[0]
    expected_cols = ["subject", "question_text", "question_type", "options", "correct_answer", "difficulty", "marks", "chapter"]
    for col in expected_cols:
        assert col in headers, f"Missing column {col} in CSV export"


if __name__ == "__main__":
    pytest.main(["-v", __file__])
