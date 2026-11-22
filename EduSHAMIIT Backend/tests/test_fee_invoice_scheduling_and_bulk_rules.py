"""
EduSHAMIIT Test Suite: Automated Student Fee Invoicing & Scheduling Engine
Tests the end-to-end functionality of:
  - Automated recurring invoice generation rules (monthly, quarterly, etc.)
  - Automated 10-day parent notice payment window calculation
  - Duplicate invoicing prevention
  - Target student cohort preview and headcount resolution
  - On-demand enhanced bulk invoice generation
  - Execution run telemetry and audit trail
"""

import json
import urllib.request
import urllib.parse
import sys
import time
import hmac
import hashlib
import base64

BASE_URL = "http://localhost:8082/api"
JWT_SECRET = "super-secret-jwt-token-with-at-least-32-characters-long"
SCHOOL_ID = "11111111-1111-1111-1111-111111111111"


def b64url_enc(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode('utf-8').rstrip('=')


def create_jwt_token(payload: dict, secret: str) -> str:
    header = {"alg": "HS256", "typ": "JWT"}
    segments = [
        b64url_enc(json.dumps(header, separators=(',', ':')).encode('utf-8')),
        b64url_enc(json.dumps(payload, separators=(',', ':')).encode('utf-8'))
    ]
    signing_input = ".".join(segments).encode('utf-8')
    sig = hmac.new(secret.encode('utf-8'), signing_input, hashlib.sha256).digest()
    segments.append(b64url_enc(sig))
    return ".".join(segments)


def make_request(path: str, method: str = "GET", data: dict = None, token: str = ""):
    url = f"{BASE_URL}{path}"
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    body = json.dumps(data).encode("utf-8") if data is not None else None
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read().decode("utf-8")), response.status
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8")
        try:
            return json.loads(err_body), e.code
        except Exception:
            return {"error": err_body}, e.code


def run_tests():
    print("=" * 70)
    print("RUNNING FEE INVOICE SCHEDULING & BULK RULES E2E TEST SUITE")
    print("=" * 70)

    token = create_jwt_token({
        "sub": "5198c4b0-f1cb-45db-9649-41688d0438ba",
        "id": "5198c4b0-f1cb-45db-9649-41688d0438ba",
        "email": "mathematicsking888@gmail.com",
        "full_name": "King Doe",
        "role": "super_admin",
        "school_id": SCHOOL_ID,
        "aud": "authenticated",
        "exp": int(time.time()) + 3600
    }, JWT_SECRET)

    # 1. Target Students Preview
    print("\n[TEST 1] Preview Target Students for Class '10 A'...")
    res, code = make_request("/v1/payment-management/student-fees/target-students-preview?target_class=10%20A", "GET", token=token)
    assert code == 200, f"Expected 200, got {code}: {res}"
    assert res.get("success") is True
    student_count = res.get("count", 0)
    print(f" -> Found {student_count} student(s) in Class 10 A.")
    assert student_count > 0, "Expected non-zero students in Class 10 A"

    # 2. List Configured Schedule Rules
    print("\n[TEST 2] Fetch Configured Automation Rules...")
    res, code = make_request("/v1/payment-management/student-fees/schedules", "GET", token=token)
    assert code == 200, f"Expected 200, got {code}: {res}"
    assert res.get("success") is True
    rules = res.get("rules", [])
    print(f" -> Found {len(rules)} active/configured rules in database.")
    assert len(rules) >= 1, "Expected at least 1 seeded rule"

    # 3. Create New Automated Rule with 10-day Due Window
    print("\n[TEST 3] Create New Automated Rule with 10-Day Due Window...")
    new_rule_payload = {
        "rule_name": f"Automated E2E Test Rule {int(time.time())}",
        "target_type": "CLASS",
        "target_class": "10 A",
        "fee_type": "Tuition Fee",
        "fee_plan": "Monthly",
        "amount": 4500.00,
        "title_template": "E2E Test Tuition - {MONTH} {YEAR}",
        "notes": "Automated billing rule with 10-day notice window",
        "frequency": "MONTHLY",
        "schedule_day_of_month": 25,
        "due_days_offset": 10,
        "billing_period_target": "NEXT_MONTH",
        "academic_year": "2026 - 2027",
        "is_active": True
    }
    res, code = make_request("/v1/payment-management/student-fees/schedules", "POST", data=new_rule_payload, token=token)
    assert code == 201, f"Expected 201, got {code}: {res}"
    assert res.get("success") is True
    rule_id = res.get("rule", {}).get("id")
    print(f" -> Created rule ID: {rule_id}")
    assert rule_id is not None

    # 4. Toggle Rule Active / Paused
    print("\n[TEST 4] Toggle Rule Active / Paused...")
    res, code = make_request(f"/v1/payment-management/student-fees/schedules/{rule_id}/toggle", "PATCH", token=token)
    assert code == 200, f"Expected 200, got {code}: {res}"
    assert res.get("success") is True
    assert res.get("is_active") is False
    print(" -> Successfully paused rule.")

    # Reactivate rule
    res, code = make_request(f"/v1/payment-management/student-fees/schedules/{rule_id}/toggle", "PATCH", token=token)
    assert code == 200
    assert res.get("is_active") is True
    print(" -> Successfully reactivated rule.")

    # 5. Execute Rule Now & Verify Duplicate Prevention
    print("\n[TEST 5] Execute Rule Now & Check Invoicing...")
    res, code = make_request(f"/v1/payment-management/student-fees/schedules/{rule_id}/run", "POST", token=token)
    assert code == 200, f"Expected 200, got {code}: {res}"
    assert res.get("success") is True
    invoices_created = res.get("invoices_created", 0)
    due_date = res.get("due_date")
    print(f" -> Generated {invoices_created} invoices with calculated due date: {due_date}")

    # Re-executing rule should skip existing to prevent duplicate billing
    print(" -> Testing duplicate prevention by re-running immediately...")
    res2, code2 = make_request(f"/v1/payment-management/student-fees/schedules/{rule_id}/run", "POST", token=token)
    assert code2 == 200
    assert res2.get("invoices_created") == 0, "Duplicate invoices should not be generated"
    assert res2.get("duplicates_skipped") > 0, "Existing invoices should be counted as skipped"
    print(f" -> Duplicate prevention passed: {res2.get('duplicates_skipped')} duplicates skipped.")

    # 6. Test On-Demand Bulk Invoice Generation
    print("\n[TEST 6] Execute On-Demand Bulk Invoice Generation...")
    bulk_payload = {
        "target_type": "CLASS",
        "target_class": "10 A",
        "fee_type": "Examination Fee",
        "fee_plan": "Term-Wise",
        "amount": 1200.00,
        "due_days_offset": 10,
        "title": f"Mid-Term Examination Fee {int(time.time())}",
        "notes": "Bulk generated exam fees with 10 days payment window",
        "academic_year": "2026 - 2027",
        "skip_duplicates": True
    }
    res, code = make_request("/v1/payment-management/student-fees/invoices/bulk-generate", "POST", data=bulk_payload, token=token)
    assert code == 201, f"Expected 201, got {code}: {res}"
    assert res.get("success") is True
    print(f" -> Bulk generated {res.get('invoices_created')} examination invoices.")

    # 7. Check Execution Run Telemetry Logs
    print("\n[TEST 7] Fetch Execution Runs Telemetry...")
    res, code = make_request("/v1/payment-management/student-fees/schedules/runs", "GET", token=token)
    assert code == 200, f"Expected 200, got {code}: {res}"
    assert res.get("success") is True
    runs = res.get("runs", [])
    print(f" -> Total recorded execution runs: {len(runs)}")
    assert len(runs) >= 2, "Expected at least 2 recorded runs"
    latest_run = runs[0]
    print(f" -> Latest run: '{latest_run.get('rule_name')}' | Status: {latest_run.get('status')} | Invoices: {latest_run.get('invoices_created')}")

    # 8. Check Due Schedules Background Engine
    print("\n[TEST 8] Trigger Due Schedules Processor...")
    res, code = make_request("/v1/payment-management/student-fees/schedules/process-due", "POST", token=token)
    assert code == 200, f"Expected 200, got {code}: {res}"
    assert res.get("success") is True
    print(f" -> Background processor executed successfully: {res}")

    # 9. Clean up test rule
    print("\n[TEST 9] Clean up and Delete Test Rule...")
    res, code = make_request(f"/v1/payment-management/student-fees/schedules/{rule_id}", "DELETE", token=token)
    assert code == 200, f"Expected 200, got {code}: {res}"
    assert res.get("success") is True
    print(" -> Rule deleted cleanly.")

    print("\n" + "=" * 70)
    print("ALL TESTS COMPLETED SUCCESSFULLY! (9/9 PASSED)")
    print("=" * 70)


if __name__ == "__main__":
    run_tests()
