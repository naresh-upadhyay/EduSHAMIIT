"""
==============================================================================
Universal Enterprise Visitors Management Automated Test Suite
Testing: CRUD, Registration, Reuse, Check-In, Check-Out, Overstay, Extension,
         Gate Passes, Restrictions / Blacklist, Appointments & Approvals,
         Multi-tenancy Scoping, and CSV Export.
==============================================================================
"""
import pytest
import asyncio
import uuid
import httpx
from jose import jwt
import os

BASE_URL = os.environ.get("BASE_URL", "http://127.0.0.1:8082")
JWT_SECRET = "super-secret-jwt-token-with-at-least-32-characters-long"

def create_test_token(school_id: str, role: str = "super_admin", user_id: str = None) -> str:
    user_id = user_id or "10000000-0000-0000-0000-000000000001"
    payload = {
        "sub": user_id,
        "id": user_id,
        "school_id": school_id,
        "role": role,
        "exp": 9999999999
    }
    return jwt.encode(payload, JWT_SECRET, algorithm="HS256")


@pytest.mark.asyncio
async def test_visitors_kpis_and_analytics():
    school_id = "11111111-1111-1111-1111-111111111111"
    token = create_test_token(school_id)
    headers = {"Authorization": f"Bearer {token}"}

    async with httpx.AsyncClient(base_url=BASE_URL, headers=headers, timeout=20.0) as client:
        # Test KPIs
        res = await client.get("/api/visitors/kpis")
        assert res.status_code == 200, res.text
        data = res.json()["data"]
        assert "total_visitors" in data
        assert "currently_inside" in data
        assert "overstay" in data
        assert "scheduled_today" in data
        assert data["total_visitors"] >= 10
        print(f"[OK] KPIs verified: {data['total_visitors']} total, {data['currently_inside']} inside, {data['overstay']} overstay.")

        # Test Analytics
        res_an = await client.get("/api/visitors/analytics")
        assert res_an.status_code == 200
        an_data = res_an.json()["data"]
        assert "categories" in an_data
        assert "locations" in an_data
        assert "recent_visitors" in an_data
        print("[OK] Analytics returned categories and location breakdowns.")


@pytest.mark.asyncio
async def test_visitors_list_filters_and_pagination():
    school_id = "11111111-1111-1111-1111-111111111111"
    token = create_test_token(school_id)
    headers = {"Authorization": f"Bearer {token}"}

    async with httpx.AsyncClient(base_url=BASE_URL, headers=headers, timeout=20.0) as client:
        # Paginated fetch
        res = await client.get("/api/visitors/visits?page=1&page_size=5")
        assert res.status_code == 200
        payload = res.json()
        assert len(payload["data"]) <= 5
        assert payload["pagination"]["total_records"] >= 10

        # Filter by Status Inside
        res_inside = await client.get("/api/visitors/visits?status=Inside")
        assert res_inside.status_code == 200
        for rec in res_inside.json()["data"]:
            assert rec["status"] in ["Inside", "Overstay"]

        # Search by visitor name (matching seeded visit Mrs. Anita Sharma)
        res_search = await client.get("/api/visitors/visits?search=Sharma")
        assert res_search.status_code == 200
        records = res_search.json()["data"]
        assert any("Sharma" in r["visitor_name"] for r in records)
        print("[OK] Search, filtering and pagination verified.")


@pytest.mark.asyncio
async def test_visitor_registration_and_existing_reuse():
    school_id = "11111111-1111-1111-1111-111111111111"
    token = create_test_token(school_id)
    headers = {"Authorization": f"Bearer {token}"}
    test_phone = f"+91 9999{uuid.uuid4().hex[:6]}"

    async with httpx.AsyncClient(base_url=BASE_URL, headers=headers, timeout=20.0) as client:
        # 1. Register first time
        reg_payload = {
            "full_name": "Test Father",
            "phone": test_phone,
            "email": "test.father@example.com",
            "visitor_type": "Parent",
            "id_type": "Aadhaar Card",
            "id_number_masked": "XXXX-XXXX-9999",
            "purpose": "Meet Class Teacher",
            "destination": "Main Gate",
            "host_name": "Class Teacher 10B",
            "auto_check_in": True
        }
        res1 = await client.post("/api/visitors/register", json=reg_payload)
        assert res1.status_code == 200, res1.text
        r1_data = res1.json()["data"]
        visitor_id_1 = r1_data["visitor_id"]
        visit_id_1 = r1_data["visit_id"]
        assert r1_data["status"] == "Inside"

        # 2. Register second time with SAME phone (Returning visitor)
        reg_payload_2 = {
            "full_name": "Test Father (Updated)",
            "phone": test_phone,
            "visitor_type": "Parent",
            "purpose": "Second Visit for Library",
            "destination": "Library",
            "host_name": "Librarian",
            "auto_check_in": False
        }
        res2 = await client.post("/api/visitors/register", json=reg_payload_2)
        assert res2.status_code == 200
        r2_data = res2.json()["data"]
        # Must REUSE existing visitor_id, avoiding duplicate identity!
        assert r2_data["visitor_id"] == visitor_id_1
        assert r2_data["visit_id"] != visit_id_1
        assert r2_data["status"] == "Scheduled"
        print("[OK] Returning visitor profile reuse verified: same profile ID reused.")


@pytest.mark.asyncio
async def test_checkin_checkout_extension_lifecycle():
    school_id = "11111111-1111-1111-1111-111111111111"
    token = create_test_token(school_id)
    headers = {"Authorization": f"Bearer {token}"}
    test_phone = f"+91 9888{uuid.uuid4().hex[:6]}"

    async with httpx.AsyncClient(base_url=BASE_URL, headers=headers, timeout=20.0) as client:
        # Create scheduled visit (not checked in)
        reg = await client.post("/api/visitors/register", json={
            "full_name": "Lifecycle Visitor",
            "phone": test_phone,
            "purpose": "Official Audit",
            "destination": "Admin Office",
            "host_name": "Finance Head",
            "auto_check_in": False
        })
        assert reg.status_code == 200
        visit_id = reg.json()["data"]["visit_id"]

        # 1. Perform Check In
        chk_in = await client.post(f"/api/visitors/visits/{visit_id}/check-in", json={
            "entry_location": "Main Gate",
            "operator_name": "Guard Ram"
        })
        assert chk_in.status_code == 200
        assert chk_in.json()["data"]["status"] == "Inside"

        # Duplicate check-in safeguard
        chk_in_dup = await client.post(f"/api/visitors/visits/{visit_id}/check-in", json={})
        assert chk_in_dup.status_code == 400

        # 2. Extend Visit
        ext = await client.post(f"/api/visitors/visits/{visit_id}/extend", json={
            "extension_minutes": 90,
            "reason": "Meeting prolonged"
        })
        assert ext.status_code == 200
        assert ext.json()["data"]["status"] == "Inside"

        # 3. Check Out
        chk_out = await client.post(f"/api/visitors/visits/{visit_id}/check-out", json={
            "exit_location": "Main Gate",
            "remarks": "Meeting concluded safely."
        })
        assert chk_out.status_code == 200
        assert chk_out.json()["data"]["status"] == "Checked Out"

        # Double checkout safeguard
        chk_out_dup = await client.post(f"/api/visitors/visits/{visit_id}/check-out", json={})
        assert chk_out_dup.status_code == 400
        print("[OK] Complete check-in, extension, and checkout lifecycle verified with idempotency.")


@pytest.mark.asyncio
async def test_scheduled_appointments_workflow():
    school_id = "11111111-1111-1111-1111-111111111111"
    token = create_test_token(school_id)
    headers = {"Authorization": f"Bearer {token}"}
    apt_phone = f"+91 9777{uuid.uuid4().hex[:6]}"

    async with httpx.AsyncClient(base_url=BASE_URL, headers=headers, timeout=20.0) as client:
        # Schedule
        sch = await client.post("/api/visitors/appointments", json={
            "full_name": "Prospective Parent",
            "phone": apt_phone,
            "host_name": "Admission Officer",
            "purpose": "New Admission Inquiry",
            "destination": "Reception Desk"
        })
        assert sch.status_code == 200
        apt_id = sch.json()["data"]["appointment_id"]
        assert sch.json()["data"]["status"] == "AWAITING_APPROVAL"

        # Approve
        appr = await client.post(f"/api/visitors/appointments/{apt_id}/approve", json={
            "decided_by_name": "Host Admission Officer"
        })
        assert appr.status_code == 200
        assert appr.json()["status"] == "APPROVED"
        print("[OK] Appointment scheduling and approval flow verified.")


@pytest.mark.asyncio
async def test_blacklisted_visitors_and_restriction_safeguard():
    school_id = "11111111-1111-1111-1111-111111111111"
    token = create_test_token(school_id)
    headers = {"Authorization": f"Bearer {token}"}
    blocked_phone = f"+91 9666{uuid.uuid4().hex[:6]}"

    async with httpx.AsyncClient(base_url=BASE_URL, headers=headers, timeout=20.0) as client:
        # 1. Create restriction
        rst = await client.post("/api/visitors/restrictions", json={
            "full_name": "Flagged Person",
            "phone": blocked_phone,
            "scope_type": "INSTITUTION",
            "reason_category": "Prior access violation",
            "confidential_notes": "Attempted trespassing in server room.",
            "requested_by_name": "Chief Security Officer"
        })
        assert rst.status_code == 200
        restriction_id = rst.json()["data"]["restriction_id"]

        # 2. Attempt check-in with blacklisted visitor (Must be blocked with 403 Forbidden!)
        bad_checkin = await client.post("/api/visitors/register", json={
            "full_name": "Flagged Person",
            "phone": blocked_phone,
            "purpose": "Visit Library",
            "destination": "Library",
            "auto_check_in": True
        })
        assert bad_checkin.status_code == 403
        assert "active access restriction" in bad_checkin.json()["detail"].lower()
        print("[OK] Blacklisted visitor check-in blocked by security guard.")

        # 3. Lift restriction
        lift = await client.post(f"/api/visitors/restrictions/{restriction_id}/lift", json={
            "lifted_by_name": "Principal",
            "reason": "Administrative clearance granted after inquiry."
        })
        assert lift.status_code == 200
        assert lift.json()["status"] == "LIFTED"
        print("[OK] Blacklist restriction successfully lifted.")


@pytest.mark.asyncio
async def test_gate_pass_qr_verification():
    school_id = "11111111-1111-1111-1111-111111111111"
    token = create_test_token(school_id)
    headers = {"Authorization": f"Bearer {token}"}

    async with httpx.AsyncClient(base_url=BASE_URL, headers=headers, timeout=20.0) as client:
        # Verify valid pass GP-2024-001 (seeded for Visit 1)
        res = await client.post("/api/visitors/gate-passes/verify", json={"token_or_ref": "GP-2024-001"})
        assert res.status_code == 200
        assert res.json()["is_valid"] is True
        assert res.json()["data"]["pass_number"] == "GP-2024-001"

        # Verify invalid pass
        res_inv = await client.post("/api/visitors/gate-passes/verify", json={"token_or_ref": "GP-FAKE-999"})
        assert res_inv.status_code == 200
        assert res_inv.json()["is_valid"] is False
        print("[OK] QR Gate pass verification tested with valid and invalid tokens.")


@pytest.mark.asyncio
async def test_csv_export_endpoint():
    school_id = "11111111-1111-1111-1111-111111111111"
    token = create_test_token(school_id)
    headers = {"Authorization": f"Bearer {token}"}

    async with httpx.AsyncClient(base_url=BASE_URL, headers=headers, timeout=20.0) as client:
        res = await client.get("/api/visitors/reports/export")
        assert res.status_code == 200
        assert "text/csv" in res.headers.get("content-type", "")
        lines = res.text.strip().split("\n")
        assert len(lines) >= 2 # Header + at least one record
        assert "Visit Number" in lines[0]
        assert "Visitor Name" in lines[0]
        print(f"[OK] CSV export returned {len(lines)} lines with headers.")


@pytest.mark.asyncio
async def test_multi_tenant_isolation():
    # Institution A
    school_a = "11111111-1111-1111-1111-111111111111"
    # Institution B
    school_b = "22222222-2222-2222-2222-222222222222"
    token_b = create_test_token(school_b)
    headers_b = {"Authorization": f"Bearer {token_b}"}

    async with httpx.AsyncClient(base_url=BASE_URL, headers=headers_b, timeout=20.0) as client:
        res_b = await client.get("/api/visitors/visits")
        assert res_b.status_code == 200
        # Institution B must NOT see Institution A visits!
        b_records = res_b.json()["data"]
        for r in b_records:
            assert r["visitor_name"] != "Mr. Rajesh Kumar"
        print("[OK] Multi-tenant isolation verified: Institution B cannot read Institution A records.")


@pytest.mark.asyncio
async def test_scheduled_visitors_kpis_and_drawer_360():
    school_id = "11111111-1111-1111-1111-111111111111"
    token = create_test_token(school_id)
    headers = {"Authorization": f"Bearer {token}"}

    async with httpx.AsyncClient(base_url=BASE_URL, headers=headers, timeout=20.0) as client:
        # 1. Test 5 KPI cards matching Screenshot 1
        res = await client.get("/api/visitors/appointments/kpis")
        assert res.status_code == 200, res.text
        kpis = res.json()["data"]
        assert kpis["total_scheduled"] >= 12
        assert kpis["today"] >= 0
        assert kpis["this_week"] >= 0
        assert kpis["expected_visitors"] >= 1
        assert kpis["pending_approval"] >= 1
        print(f"[OK] Scheduled KPIs verified matching Screenshot 1: Total={kpis['total_scheduled']}, Today={kpis['today']}, ThisWeek={kpis['this_week']}, Expected={kpis['expected_visitors']}, Pending={kpis['pending_approval']}.")

        # 2. Test List Appointments matching Screenshot 1
        res_list = await client.get("/api/visitors/appointments?page_size=50")
        assert res_list.status_code == 200
        appts = res_list.json()["data"]
        assert len(appts) >= 10
        first = next(a for a in appts if "Rajesh" in a["visitor_name"])
        assert "Rajesh" in first["visitor_name"]
        assert first["purpose"] == "PTM Meeting"
        assert "Rahul Sharma" in first["host_name"]
        assert first["status"] == "Confirmed"
        print(f"[OK] Scheduled appointments list verified: {len(appts)} appointments, matched {first['visitor_name']}.")

        # 3. Test 360 Details for Rajesh Kumar (APT-001)
        res_det = await client.get(f"/api/visitors/appointments/{first['id']}/details")
        assert res_det.status_code == 200
        detail = res_det.json()["data"]
        appt_info = detail.get("appointment", {})
        assert (appt_info.get("expected_visitors_text") == "2 (Self + Spouse)" or appt_info.get("expected_visitors") == "2 (Self + Spouse)")
        assert appt_info.get("vehicle_number") == "UP16 AB 1234"
        assert len(detail.get("related_appointments", [])) >= 3
        print(f"[OK] Scheduled appointment 360 details verified with related appointments list.")


@pytest.mark.asyncio
async def test_scheduled_visitor_reschedule_and_cancel_lifecycle():
    school_id = "11111111-1111-1111-1111-111111111111"
    token = create_test_token(school_id)
    headers = {"Authorization": f"Bearer {token}"}
    phone = f"+91 9777{uuid.uuid4().hex[:6]}"

    async with httpx.AsyncClient(base_url=BASE_URL, headers=headers, timeout=20.0) as client:
        # Schedule appointment
        create_res = await client.post("/api/visitors/appointments", json={
            "full_name": "Test Reschedule Candidate",
            "phone": phone,
            "host_name": "Principal",
            "purpose": "Academic Inquiry",
            "destination": "Main Gate"
        })
        assert create_res.status_code == 200
        appt_id = create_res.json()["data"]["appointment_id"]

        # Reschedule appointment
        resched_res = await client.post(f"/api/visitors/appointments/{appt_id}/reschedule", json={
            "new_date": "22 May 2024",
            "new_start_time": "02:00 PM",
            "new_end_time": "03:00 PM",
            "reason": "Requested alternate meeting slot by host."
        })
        assert resched_res.status_code == 200
        assert resched_res.json()["data"]["status"] == "RESCHEDULED"
        print("[OK] Appointment successfully rescheduled with revision history.")

        # Cancel appointment
        cancel_res = await client.post(f"/api/visitors/appointments/{appt_id}/cancel", json={
            "reason": "Visitor unable to attend."
        })
        assert cancel_res.status_code == 200
        assert cancel_res.json()["data"]["status"] == "CANCELLED"
        print("[OK] Appointment successfully cancelled.")


@pytest.mark.asyncio
async def test_blacklisted_visitors_kpis_and_drawer_360():
    school_id = "11111111-1111-1111-1111-111111111111"
    token = create_test_token(school_id)
    headers = {"Authorization": f"Bearer {token}"}

    async with httpx.AsyncClient(base_url=BASE_URL, headers=headers, timeout=20.0) as client:
        # 1. Test 4 KPI cards matching Screenshot 2
        res = await client.get("/api/visitors/restrictions/kpis")
        assert res.status_code == 200, res.text
        kpis = res.json()["data"]
        assert kpis["total_blacklisted"] >= 18
        assert kpis["active_blocks"] >= 15
        assert kpis["expired_blocks"] >= 3
        assert kpis["attempted_entries"] >= 5
        print(f"[OK] Blacklisted KPIs verified matching Screenshot 2: Total={kpis['total_blacklisted']}, Active={kpis['active_blocks']}, Expired={kpis['expired_blocks']}, Attempts={kpis['attempted_entries']}.")

        # 2. Test List Restrictions matching Screenshot 2
        res_list = await client.get("/api/visitors/restrictions?page_size=50")
        assert res_list.status_code == 200
        rests = res_list.json()["data"]
        assert len(rests) >= 10
        rohit = next(r for r in rests if r["visitor_name"] == "Rohit Malhotra")
        assert rohit["visitor_name"] == "Rohit Malhotra"
        assert rohit["reason_category"] == "Theft"
        assert rohit["scope_name"] == "Main Gate"
        assert rohit["status"].upper() == "ACTIVE"
        assert rohit["valid_till"] == "Permanent"
        print(f"[OK] Blacklist records list verified: {len(rests)} records, 1st is {rohit['visitor_name']}.")

        # 3. Test 360 Details for Rohit Malhotra
        res_det = await client.get(f"/api/visitors/restrictions/{rohit['id']}/details")
        assert res_det.status_code == 200
        detail = res_det.json()["data"]
        assert detail["restriction"]["blocked_by"] == "Rahul Sharma (Security)"
        assert len(detail["attempted_entries"]) >= 3
        print(f"[OK] Blacklist 360 details verified with {len(detail['attempted_entries'])} attempted entry records.")

        # 4. Update details
        upd = await client.patch(f"/api/visitors/restrictions/{rohit['id']}", json={
            "reason_category": "Theft",
            "scope_name": "Main Gate",
            "is_permanent": True,
            "remarks": "Updated incident notes from CCTV analysis."
        })
        assert upd.status_code == 200
        assert upd.json()["data"]["success"] is True
        print("[OK] Blacklist details updated via PATCH endpoint.")


@pytest.mark.asyncio
async def test_access_eligibility_enforcement():
    school_id = "11111111-1111-1111-1111-111111111111"
    token = create_test_token(school_id)
    headers = {"Authorization": f"Bearer {token}"}

    async with httpx.AsyncClient(base_url=BASE_URL, headers=headers, timeout=20.0) as client:
        # 1. Check Rohit Malhotra (+91 98765 43210) for Main Gate (Restricted -> should NOT be allowed)
        res_denied = await client.post("/api/visitors/restrictions/check-eligibility", json={
            "phone": "+91 98765 43210",
            "location": "Main Gate"
        })
        assert res_denied.status_code == 200
        data_denied = res_denied.json()["data"]
        assert data_denied["is_allowed"] is False
        assert data_denied["restriction_found"] is True
        assert data_denied["reason"] == "Theft"
        print(f"[OK] Access eligibility check blocked Rohit Malhotra at Main Gate (reason: {data_denied['reason']}).")

        # 2. Check clean visitor (+91 99999 11111) for Main Gate (No restriction -> should be allowed)
        res_allowed = await client.post("/api/visitors/restrictions/check-eligibility", json={
            "phone": "+91 99999 11111",
            "location": "Main Gate"
        })
        assert res_allowed.status_code == 200
        data_allowed = res_allowed.json()["data"]
        assert data_allowed["is_allowed"] is True
        assert data_allowed["restriction_found"] is False
        print("[OK] Access eligibility check allowed clean visitor.")


@pytest.mark.asyncio
async def test_appointment_arrival_check_in():
    school_id = "11111111-1111-1111-1111-111111111111"
    token = create_test_token(school_id)
    headers = {"Authorization": f"Bearer {token}"}
    test_phone = f"+91 9111{uuid.uuid4().hex[:6]}"

    async with httpx.AsyncClient(base_url=BASE_URL, headers=headers, timeout=20.0) as client:
        # 1. Schedule an appointment
        sch_res = await client.post("/api/visitors/appointments", json={
            "full_name": "Scheduled Visitor Alpha",
            "phone": test_phone,
            "visitor_type": "Vendor",
            "host_name": "Dr. Ramesh Patel",
            "host_department": "Physics",
            "purpose": "Campus WiFi Survey",
            "destination": "Admin Office"
        })
        assert sch_res.status_code == 200
        appt_id = sch_res.json()["data"]["appointment_id"]

        # 2. Approve appointment
        appr_res = await client.post(f"/api/visitors/appointments/{appt_id}/approve")
        assert appr_res.status_code == 200

        # 3. 1-Click Arrival Check-In
        chk_res = await client.post(f"/api/visitors/appointments/{appt_id}/check-in", json={
            "entry_location": "Main Gate",
            "remarks": "Arrived on time with gear"
        })
        assert chk_res.status_code == 200, chk_res.text
        data = chk_res.json()
        assert data["success"] is True
        assert "checked in successfully" in data["message"]

        # 4. Verify in active visits
        visit_res = await client.get("/api/visitors/visits?status=Inside")
        assert visit_res.status_code == 200
        active_visits = visit_res.json()["data"]
        matching = [v for v in active_visits if v["phone"] == test_phone]
        assert len(matching) > 0
        assert matching[0]["purpose"] == "Campus WiFi Survey"
        print("[OK] 1-Click Scheduled appointment arrival check-in verified end-to-end.")


@pytest.mark.asyncio
async def test_smart_host_search_and_instant_blacklist():
    school_id = "11111111-1111-1111-1111-111111111111"
    token = create_test_token(school_id)
    headers = {"Authorization": f"Bearer {token}"}

    async with httpx.AsyncClient(base_url=BASE_URL, headers=headers, timeout=20.0) as client:
        # 1. Test Smart Host Search
        host_res = await client.get("/api/visitors/hosts/search?query=a")
        assert host_res.status_code == 200, host_res.text
        hosts = host_res.json()["data"]
        assert len(hosts) > 0
        first_host = hosts[0]
        assert "name" in first_host
        assert "host_type" in first_host
        assert "department" in first_host
        print(f"[OK] Smart host search returned {len(hosts)} results. Example: {first_host['name']} ({first_host['host_type']}).")

        # 2. Test Instant Blacklist Check on Restricted Phone
        blk_res = await client.get("/api/visitors/restrictions/check-instant?phone=%2B91%2098765%2043210")
        assert blk_res.status_code == 200
        blk_data = blk_res.json()
        assert blk_data["is_restricted"] is True
        assert blk_data["restriction"]["reason_category"] == "Theft"
        print(f"[OK] Instant restriction debouncer identified blacklisted phone: {blk_data['restriction']['visitor_name']}.")

        # 3. Test Instant Blacklist Check on Clean Phone
        clean_res = await client.get("/api/visitors/restrictions/check-instant?phone=%2B91%2099999%2000000")
        assert clean_res.status_code == 200
        clean_data = clean_res.json()
        assert clean_data["is_restricted"] is False
        print("[OK] Instant restriction check returned clean for non-restricted visitor.")

        # 4. Test Executive Summary Report Endpoint
        rep_res = await client.get("/api/visitors/reports/executive-summary")
        assert rep_res.status_code == 200
        rep_data = rep_res.json()["data"]
        assert "institution" in rep_data
        assert "kpis" in rep_data
        assert "security_kpis" in rep_data
        assert "analytics" in rep_data
        print("[OK] Executive management summary report endpoint verified.")


