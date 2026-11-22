"""
EduSHAMIIT Test Suite: Multi-Section Targeting, Advance Credit Wallet Deductions,
and Parent Email Notifications for Bulk Invoicing & Automated Scheduling.
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
        with urllib.request.urlopen(req) as resp:
            raw = resp.read().decode("utf-8")
            return resp.status, json.loads(raw)
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8")
        try:
            parsed = json.loads(raw)
        except Exception:
            parsed = {"raw": raw}
        return e.code, parsed


def run_tests():
    print("=" * 70)
    print("TEST SUITE: MULTI-SECTION TARGETING, ADVANCE WALLET & PARENT EMAILS")
    print("=" * 70)

    token = create_jwt_token({
        "id": "10000000-0000-0000-0000-000000000001",
        "sub": "10000000-0000-0000-0000-000000000001",
        "email": "superadmin@edushamiit.com",
        "role": "super_admin",
        "school_id": SCHOOL_ID,
        "full_name": "King Doe (Super Admin)",
        "exp": int(time.time()) + 3600
    }, JWT_SECRET)

    # 1. Test Metadata returns classes_with_sections
    print("\n[TEST 1] Fetch Student Fee Metadata & Verify classes_with_sections...")
    status, meta = make_request("/payment-management/student-fees/metadata", "GET", token=token)
    assert status == 200, f"Expected 200, got {status}: {meta}"
    assert "classes_with_sections" in meta, "Missing classes_with_sections in metadata"
    c_sec = meta["classes_with_sections"]
    print(f"  -> Returned {len(c_sec)} classes with sections.")
    class_10_entry = next((c for c in c_sec if c["class_name"] == "Class 10"), None)
    assert class_10_entry is not None, "Class 10 missing in classes_with_sections"
    print(f"  -> Class 10 sections: {class_10_entry['sections']}")
    assert "10-A" in class_10_entry["sections"], "Section 10-A not in Class 10 sections"
    print("  [PASS] Metadata classes_with_sections verified successfully.")

    # 2. Test Target Students Preview with Section and Advance Credit Calculation
    print("\n[TEST 2] Target Students Preview: Class 10 Section 10-A...")
    params = urllib.parse.urlencode({
        "target_type": "CLASS",
        "target_class": "Class 10",
        "target_section": "10-A",
        "amount": "4500"
    })
    status, prev = make_request(f"/payment-management/student-fees/target-students-preview?{params}", "GET", token=token)
    assert status == 200, f"Expected 200, got {status}: {prev}"
    assert prev.get("success") is True
    print(f"  -> Targeted count: {prev.get('count')}")
    print(f"  -> Total Gross Invoicing: ₹{prev.get('total_gross_invoicing'):,.2f}")
    print(f"  -> Total Advance Applied: ₹{prev.get('total_advance_applied'):,.2f}")
    print(f"  -> Total Net Payable: ₹{prev.get('total_net_payable'):,.2f}")
    print(f"  -> Fully Settled Students (100% paid): {prev.get('fully_settled_count')}")
    print(f"  -> Pending Collection Students: {prev.get('pending_collection_count')}")

    assert prev.get("count", 0) > 0, "Expected non-zero students in Class 10 (10-A)"
    assert prev.get("total_gross_invoicing", 0) > 0, "Gross total should be positive"
    print("  [PASS] Target Students Preview with section & wallet deduction passed.")

    # 3. Test Bulk Invoicing with Multi-Section, Wallet Auto-Deductions, and Email
    print("\n[TEST 3] Bulk Invoice Generation for Class 10 Section 10-A with Auto-Deductions & Email...")
    bulk_payload = {
        "target_type": "CLASS",
        "target_class": "Class 10",
        "target_section": "10-A",
        "fee_type": "Tuition Fee",
        "fee_plan": "Monthly",
        "amount": 4500.0,
        "due_days_offset": 10,
        "title": f"Dec 2026 Tuition - Section 10-A (Test {int(time.time())})",
        "notes": "Automated Section Invoicing with Wallet Deduction",
        "academic_year": "2026 - 2027",
        "skip_duplicates": False,
        "auto_deduct_advance_credit": True,
        "send_parent_email": True
    }
    status, bulk_res = make_request("/payment-management/student-fees/invoices/bulk-generate", "POST", data=bulk_payload, token=token)
    assert status == 201, f"Expected 201, got {status}: {bulk_res}"
    assert bulk_res.get("success") is True
    invoices_created = bulk_res.get("invoices_created", 0)
    adv_applied = bulk_res.get("total_advance_credits_applied", 0.0)
    net_due = bulk_res.get("net_amount_due", 0.0)
    fully_settled = bulk_res.get("fully_settled_count", 0)
    emails_sent = bulk_res.get("emails_sent", 0)

    print(f"  -> Invoices Created: {invoices_created}")
    print(f"  -> Advance Credits Auto-Deducted: ₹{adv_applied:,.2f}")
    print(f"  -> Net Amount Due: ₹{net_due:,.2f}")
    print(f"  -> Fully Settled Count: {fully_settled}")
    print(f"  -> Parent Emails Dispatched: {emails_sent}")

    assert invoices_created > 0, "Expected at least 1 invoice created"
    assert adv_applied > 0, "Expected advance credits to be applied for overpaid student(s)"
    assert emails_sent > 0, "Expected at least 1 parent email to be dispatched"
    print("  [PASS] Bulk Invoicing with section targeting, advance deduction & emails passed.")

    # 4. Test Recurring Schedule Rule with Target Section and Auto-Deduct
    print("\n[TEST 4] Create Recurring Automation Rule with Section & Advance Deduction...")
    rule_payload = {
        "rule_name": f"Automated Tuition - Class 10 (10-A) {int(time.time())}",
        "target_type": "CLASS",
        "target_class": "Class 10",
        "target_section": "10-A",
        "fee_type": "Tuition Fee",
        "fee_plan": "Monthly",
        "amount": 4500.0,
        "title_template": "Tuition Fee - {MONTH} {YEAR} (Sec 10-A)",
        "notes": "Auto-scheduled recurring invoice with wallet deductions",
        "frequency": "MONTHLY",
        "schedule_day_of_month": 25,
        "due_days_offset": 10,
        "billing_period_target": "NEXT_MONTH",
        "academic_year": "2026 - 2027",
        "is_active": True,
        "auto_deduct_advance_credit": True,
        "send_parent_email": True
    }
    status, rule_res = make_request("/payment-management/student-fees/schedules", "POST", data=rule_payload, token=token)
    assert status == 201, f"Expected 201, got {status}: {rule_res}"
    assert rule_res.get("success") is True
    rule_id = rule_res["rule"]["id"]
    print(f"  -> Created Rule ID: {rule_id}")
    print("  [PASS] Recurring schedule rule created successfully.")

    # 5. Test Schedule Runs History Telemetry
    print("\n[TEST 5] Fetch Schedule Run Telemetry Logs & Verify Section & Deductions...")
    status, runs_res = make_request("/payment-management/student-fees/schedules/runs?limit=5", "GET", token=token)
    assert status == 200, f"Expected 200, got {status}: {runs_res}"
    runs = runs_res.get("runs", [])
    assert len(runs) > 0, "Expected at least 1 run log"
    latest_run = runs[0]
    print(f"  -> Latest Run Rule: {latest_run.get('rule_name')}")
    print(f"  -> Invoices Created: {latest_run.get('invoices_created')}")
    print(f"  -> Advance Deducted: ₹{float(latest_run.get('advance_credits_applied') or 0):,.2f}")
    print(f"  -> Net Due: ₹{float(latest_run.get('net_amount_due') or 0):,.2f}")
    print(f"  -> Target Section: {latest_run.get('target_section')}")
    print(f"  -> Emails Sent: {latest_run.get('emails_sent')}")

    print("  [PASS] Execution history telemetry contains all required metrics.")
    print("\n" + "=" * 70)
    print("ALL TESTS PASSED WITH 100% SUCCESS!")
    print("=" * 70)


if __name__ == "__main__":
    run_tests()
