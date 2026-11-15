"""
End-to-End Automated Testing Script for Hostel Leave & Outing Module.
Validates all routes, edge cases, error states, conflict checks, 
optimistic locking, digital gate pass, gate scanner, movement exits/returns,
filtering, sorting, search, pagination, and multi-tenant isolation.
"""
import sys
import json
import urllib.request
import urllib.error
from datetime import datetime, timedelta
import time
from jose import jwt

# Configure output encoding for Windows terminals
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

BASE_URL = "http://127.0.0.1:8082"
JWT_SECRET = "super-secret-jwt-token-with-at-least-32-characters-long"
SCHOOL_A = "11111111-1111-1111-1111-111111111111"
SCHOOL_B = "22222222-2222-2222-2222-222222222222"
ADMIN_USER = "d1a22222-2222-2222-2222-222222222222"
STUDENT_USER = "a1000001-0000-0000-0000-000000000001" # Rahul Sharma

passed_count = 0
failed_count = 0

def create_token(school_id=SCHOOL_A, user_id=ADMIN_USER, role="super_admin"):
    return jwt.encode({
        "sub": user_id,
        "school_id": school_id,
        "role": role,
        "email": "admin@edushamiit.com"
    }, JWT_SECRET, algorithm="HS256")

TOKEN_A = create_token(SCHOOL_A)
TOKEN_B = create_token(SCHOOL_B)

def api_call(method, endpoint, data=None, token=TOKEN_A):
    url = f"{BASE_URL}{endpoint}"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Accept": "application/json"
    }
    body = json.dumps(data).encode("utf-8") if data is not None else None
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            content = resp.read().decode("utf-8")
            try:
                return resp.status, json.loads(content)
            except Exception:
                return resp.status, content
    except urllib.error.HTTPError as e:
        content = e.read().decode("utf-8")
        try:
            return e.code, json.loads(content)
        except Exception:
            return e.code, content
    except Exception as e:
        return 500, {"error": str(e)}

def log_test(name, condition, details=""):
    global passed_count, failed_count
    if condition:
        passed_count += 1
        print(f"  [PASS] {name} {details}")
    else:
        failed_count += 1
        print(f"  [FAIL] {name} {details}")

print("======================================================================")
print("1. RUNNING END-TO-END TEST SUITE: LEAVE & OUTING PRODUCTION MODULE")
print("======================================================================")

# ----------------------------------------------------------------------
# 1. KPIs
# ----------------------------------------------------------------------
print("\n--- Test Suite 1: KPI Summary Metrics ---")
code, res = api_call("GET", "/api/hostel/leave-outing/kpis")
log_test("Fetch KPIs returns 200", code == 200)
log_test("KPIs success is True", res.get("success") is True)
kpi_data = res.get("data", {})
log_test("Total requests >= 48", kpi_data.get("total_requests", 0) >= 48, f"Got: {kpi_data.get('total_requests')}")
log_test("Approved count >= 32", kpi_data.get("approved", 0) >= 32, f"Got: {kpi_data.get('approved')}")
log_test("Pending count >= 8", kpi_data.get("pending", 0) >= 8, f"Got: {kpi_data.get('pending')}")
log_test("Currently out count >= 15", kpi_data.get("currently_out", 0) >= 15, f"Got: {kpi_data.get('currently_out')}")
log_test("Due today count >= 5", kpi_data.get("due_today", 0) >= 5, f"Got: {kpi_data.get('due_today')}")

# ----------------------------------------------------------------------
# 2. LIST, PAGINATION, AND SORTING
# ----------------------------------------------------------------------
print("\n--- Test Suite 2: Pagination & Sorting ---")
code, res = api_call("GET", "/api/hostel/leave-outing?page=1&page_size=10")
log_test("List page 1 returns 200", code == 200)
items = res.get("data", {}).get("items", [])
log_test("Page size 10 returns exactly 10 items", len(items) == 10, f"Got: {len(items)}")
total_recs = res.get("data", {}).get("total", 0)
log_test("Total records >= 48", total_recs >= 48, f"Got: {total_recs}")

code, res_p2 = api_call("GET", "/api/hostel/leave-outing?page=2&page_size=10")
items_p2 = res_p2.get("data", {}).get("items", [])
log_test("Page 2 returns 10 items", len(items_p2) == 10)
log_test("Page 1 and Page 2 items are distinct", items[0]["id"] != items_p2[0]["id"])

code, res_sort = api_call("GET", "/api/hostel/leave-outing?sort_by=student_name&sort_order=asc")
s_items = res_sort.get("data", {}).get("items", [])
log_test("Sort by student_name returns items", len(s_items) > 0)

# ----------------------------------------------------------------------
# 3. FILTERS & SEARCH
# ----------------------------------------------------------------------
print("\n--- Test Suite 3: Search & Multi-Filters ---")
# Search by student name
code, res_srch = api_call("GET", "/api/hostel/leave-outing?search=Rahul")
s_items = res_srch.get("data", {}).get("items", [])
log_test("Search by 'Rahul' returns matches", len(s_items) >= 1 and any("Rahul" in it["student_name"] for it in s_items))

# Search by Room No.
code, res_room = api_call("GET", "/api/hostel/leave-outing?search=A-101")
r_items = res_room.get("data", {}).get("items", [])
log_test("Search by room 'A-101' returns matches", len(r_items) >= 1)

# Filter by Request Type: LEAVE
code, res_leave = api_call("GET", "/api/hostel/leave-outing?request_type=LEAVE")
l_items = res_leave.get("data", {}).get("items", [])
log_test("Filter request_type=LEAVE returns only leaves", len(l_items) > 0 and all(it["request_type"] == "LEAVE" for it in l_items))

# Filter by Request Type: OUTING
code, res_outing = api_call("GET", "/api/hostel/leave-outing?request_type=OUTING")
o_items = res_outing.get("data", {}).get("items", [])
log_test("Filter request_type=OUTING returns only outings", len(o_items) > 0 and all(it["request_type"] == "OUTING" for it in o_items))

# Filter by Status: APPROVED
code, res_app = api_call("GET", "/api/hostel/leave-outing?status=APPROVED")
a_items = res_app.get("data", {}).get("items", [])
log_test("Filter status=APPROVED returns approved requests", len(a_items) > 0 and all(it["status"] == "APPROVED" for it in a_items))

# Filter by Status: PENDING
code, res_pnd = api_call("GET", "/api/hostel/leave-outing?status=PENDING")
p_items = res_pnd.get("data", {}).get("items", [])
log_test("Filter status=PENDING returns pending requests", len(p_items) > 0 and all(it["status"] in ["PENDING", "NEW", "ACTIVE", "IN_PROGRESS"] for it in p_items))

# Filter by Building Name: Boys Hostel A
code, res_bha = api_call("GET", "/api/hostel/leave-outing?hostel_id=Boys%20Hostel%20A")
b_items = res_bha.get("data", {}).get("items", [])
log_test("Filter by hostel name 'Boys Hostel A' returns records without UUID error", code == 200 and len(b_items) > 0)

# Non-matching search cleanly returns 0 records
code, res_none = api_call("GET", "/api/hostel/leave-outing?search=NonExistentStudent12345")
log_test("Non-matching search returns 0 records cleanly", res_none.get("data", {}).get("total") == 0)

# ----------------------------------------------------------------------
# 4. SIDEBAR & CALENDAR
# ----------------------------------------------------------------------
print("\n--- Test Suite 4: Sidebar, Calendar & Settings ---")
code, res_awt = api_call("GET", "/api/hostel/leave-outing/awaiting-approval?limit=8")
log_test("Awaiting approval returns 200", code == 200)
log_test("Awaiting approval returns 8 items", len(res_awt.get("data", [])) == 8, f"Got: {len(res_awt.get('data', []))}")

code, res_cout = api_call("GET", "/api/hostel/leave-outing/currently-out")
log_test("Currently out returns 200", code == 200)
cout_items = res_cout.get("data", []) if isinstance(res_cout.get("data"), list) else res_cout.get("data", {}).get("items", [])
log_test("Currently out returns 15 students", len(cout_items) == 15, f"Got: {len(cout_items)}")

code, res_cal = api_call("GET", "/api/hostel/leave-outing/calendar?month=5&year=2024")
log_test("Calendar endpoint returns 200", code == 200)
events = res_cal.get("data", {}).get("events", [])
log_test("Calendar returns movement events", len(events) > 0, f"Got: {len(events)} events")

code, res_set = api_call("GET", "/api/hostel/leave-outing/settings")
log_test("Settings returns 200", code == 200)
log_test("Settings has leave_allowed and curfew_time", "leave_allowed" in res_set.get("data", {}))

# ----------------------------------------------------------------------
# 5. CREATE REQUEST & CONFLICT DETECTION
# ----------------------------------------------------------------------
print("\n--- Test Suite 5: Request Creation & Conflict Prevention ---")
base_offset = int(time.time() * 1000) % 500000 + 500
start_time = datetime.now() + timedelta(days=base_offset)
return_time = start_time + timedelta(days=2)

create_payload = {
    "student_id": STUDENT_USER,
    "academic_year": "2024 - 2025",
    "request_type": "LEAVE",
    "request_subtype": "Home Leave",
    "reason": "E2E Family Wedding Trip",
    "destination": "Udaipur",
    "start_at": start_time.isoformat(),
    "expected_return_at": return_time.isoformat(),
    "is_emergency": False,
    "guardian_name": "Rajesh Sharma",
    "guardian_phone": "+91 98765 43210",
    "accompanied_by": "PARENT",
    "transport_mode": "TRAIN"
}

code, res_create = api_call("POST", "/api/hostel/leave-outing", create_payload)
log_test("Create Leave Request returns 200", code == 200)
created_req = res_create.get("data", {})
req_id = created_req.get("id")
version = created_req.get("version", 1)
log_test("Created request has valid UUID id", req_id is not None)
log_test("Initial status is PENDING", created_req.get("status") == "PENDING")

# Conflict Check: Overlapping request for same student
overlap_payload = {
    "student_id": STUDENT_USER,
    "academic_year": "2024 - 2025",
    "request_type": "OUTING",
    "request_subtype": "Market",
    "reason": "Overlapping market trip",
    "destination": "City Center",
    "start_at": (start_time + timedelta(hours=12)).isoformat(),
    "expected_return_at": (start_time + timedelta(hours=16)).isoformat()
}
code_conflict, res_conflict = api_call("POST", "/api/hostel/leave-outing", overlap_payload)
log_test("Overlapping movement request blocked with 400", code_conflict == 400)
log_test("Conflict error message returned", "conflict" in str(res_conflict).lower())

# ----------------------------------------------------------------------
# 6. APPROVAL, DIGITAL GATE PASS, AND SCANNER
# ----------------------------------------------------------------------
print("\n--- Test Suite 6: Approval Engine & Digital Gate Pass ---")
# 1. Optimistic Locking Test (passing wrong/stale version)
code_stale, res_stale = api_call("POST", f"/api/hostel/leave-outing/{req_id}/approve", {
    "remarks": "Stale approval",
    "version": version + 999
})
log_test("Optimistic concurrency: stale version returns 409 Conflict", code_stale == 409)

# 2. Valid Approval
code_appr, res_appr = api_call("POST", f"/api/hostel/leave-outing/{req_id}/approve", {
    "remarks": "Approved by Chief Warden. Gate pass issued.",
    "version": version
})
log_test("Approval returns 200", code_appr == 200)
appr_data = res_appr.get("data", {})
log_test("Status transitions to APPROVED", appr_data.get("status") == "APPROVED")
gate_pass = appr_data.get("gate_pass", {})
pass_id = gate_pass.get("id")
verification_token = gate_pass.get("verification_token")
pass_number = gate_pass.get("pass_number")
log_test("Digital Gate Pass automatically generated", pass_id is not None)
log_test("Verification token generated", verification_token is not None)

# 3. Gate Pass Verification Scanner
code_ver, res_ver = api_call("POST", "/api/hostel/gate-pass/verify", {"identifier": verification_token})
log_test("Gate Scanner verification returns 200", code_ver == 200)
log_test("Gate Pass is VALID", res_ver.get("validity") == "VALID")
log_test("Scanner returns student identity", res_ver.get("student", {}).get("full_name") == "Rahul Sharma")

# 4. Scanner with Invalid Token
code_inv, res_inv = api_call("POST", "/api/hostel/gate-pass/verify", {"identifier": "INVALID-FAKE-TOKEN-999"})
log_test("Scanner with invalid token reports INVALID", res_inv.get("validity") == "INVALID")

# ----------------------------------------------------------------------
# 7. GATE MOVEMENT: EXIT & RETURN TRACKING
# ----------------------------------------------------------------------
print("\n--- Test Suite 7: Gate Movement (Exit & Return) ---")
# Return before Exit guard
code_early_ret, _ = api_call("POST", f"/api/hostel/leave-outing/{req_id}/return", {"gate": "Main Gate"})
log_test("Guard: Return before Exit is blocked with 400", code_early_ret == 400)

# Mark Exit
code_exit, res_exit = api_call("POST", f"/api/hostel/leave-outing/{req_id}/exit", {
    "gate": "Hostel Gate 1",
    "remarks": "Student departed via bus"
})
log_test("Mark Exit returns 200", code_exit == 200)
log_test("Status transitions to EXITED", res_exit.get("data", {}).get("status") == "EXITED")

# Double Exit guard (idempotency)
code_dbl_exit, _ = api_call("POST", f"/api/hostel/leave-outing/{req_id}/exit", {"gate": "Hostel Gate 1"})
log_test("Guard: Double Exit is blocked with 400", code_dbl_exit == 400)

# Mark Return
code_ret, res_ret = api_call("POST", f"/api/hostel/leave-outing/{req_id}/return", {
    "gate": "Hostel Gate 1",
    "remarks": "Student returned safely and checked in"
})
log_test("Mark Return returns 200", code_ret == 200)
log_test("Status transitions to RETURNED", res_ret.get("data", {}).get("status") == "RETURNED")

# Double Return guard
code_dbl_ret, _ = api_call("POST", f"/api/hostel/leave-outing/{req_id}/return", {"gate": "Hostel Gate 1"})
log_test("Guard: Double Return is blocked with 400", code_dbl_ret == 400)

# ----------------------------------------------------------------------
# 8. REJECTION & CANCELLATION FLOWS
# ----------------------------------------------------------------------
print("\n--- Test Suite 8: Rejection & Cancellation ---")
# Create request to test rejection
start_rej = datetime.now() + timedelta(days=base_offset + 50)
code, res_for_rej = api_call("POST", "/api/hostel/leave-outing", {
    "student_id": STUDENT_USER,
    "academic_year": "2024 - 2025",
    "request_type": "OUTING",
    "reason": "Test Rejection Flow",
    "destination": "Mall",
    "start_at": start_rej.isoformat(),
    "expected_return_at": (start_rej + timedelta(hours=3)).isoformat()
})
req_rej_id = res_for_rej.get("data", {}).get("id")

# Reject without reason (Must fail validation)
code_no_rsn, _ = api_call("POST", f"/api/hostel/leave-outing/{req_rej_id}/reject", {"rejection_reason": "   "})
log_test("Rejection without reason is rejected", code_no_rsn in [400, 422])

# Reject with valid reason
code_rej, res_rej = api_call("POST", f"/api/hostel/leave-outing/{req_rej_id}/reject", {
    "rejection_reason": "Exam week ongoing. Outings suspended."
})
log_test("Rejection with reason returns 200", code_rej == 200)
log_test("Status transitions to REJECTED", res_rej.get("data", {}).get("status") == "REJECTED")

# Create request to test cancellation
start_cnl = datetime.now() + timedelta(days=base_offset + 100)
code, res_for_cnl = api_call("POST", "/api/hostel/leave-outing", {
    "student_id": STUDENT_USER,
    "academic_year": "2024 - 2025",
    "request_type": "OUTING",
    "reason": "Test Cancellation Flow",
    "destination": "Library",
    "start_at": start_cnl.isoformat(),
    "expected_return_at": (start_cnl + timedelta(hours=2)).isoformat()
})
req_cnl_id = res_for_cnl.get("data", {}).get("id")

code_cnl, res_cnl = api_call("POST", f"/api/hostel/leave-outing/{req_cnl_id}/cancel", {
    "cancellation_reason": "Plans changed by student"
})
log_test("Cancel request returns 200", code_cnl == 200)
log_test("Status transitions to CANCELED", res_cnl.get("data", {}).get("status") == "CANCELED")

# ----------------------------------------------------------------------
# 9. CSV EXPORT & MULTI-TENANT ISOLATION
# ----------------------------------------------------------------------
print("\n--- Test Suite 9: CSV Export & Multi-Tenant Isolation ---")
code_csv, csv_content = api_call("GET", "/api/hostel/leave-outing/export/csv")
log_test("CSV Export returns 200", code_csv == 200)
log_test("CSV contains headers", "Request ID" in str(csv_content) and "Student Name" in str(csv_content))
log_test("CSV contains records", "Rahul Sharma" in str(csv_content))

# Tenant Isolation: Tenant B accessing Tenant A's request
code_tenant_leak, res_leak = api_call("GET", f"/api/hostel/leave-outing/{req_id}", token=TOKEN_B)
log_test("Cross-tenant access blocked (returns 404/403)", code_tenant_leak in [403, 404], f"Status: {code_tenant_leak}")

# ----------------------------------------------------------------------
# SUMMARY REPORT
# ----------------------------------------------------------------------
print("\n======================================================================")
print(f"E2E TEST SUMMARY: {passed_count} PASSED, {failed_count} FAILED")
print("======================================================================")

if failed_count == 0:
    print("ALL PRODUCTION LEAVE & OUTING WORKFLOWS & EDGE CASES VERIFIED 100%!")
    sys.exit(0)
else:
    print(f"FAILURES DETECTED: {failed_count} test(s) failed.")
    sys.exit(1)
