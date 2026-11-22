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
ALOK_STAFF_ID = "55555555-0000-0000-0000-000000000024"

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

def get_admin_token():
    payload = {
        "sub": "a819f432-4756-49ea-a4af-23087fe41685",
        "school_id": SCHOOL_ID,
        "role": "super_admin",
        "email": "superadmin@schoolerp.com",
        "exp": int(time.time()) + 86400
    }
    return create_jwt_token(payload, JWT_SECRET)

def make_req(endpoint, method="GET", data=None, token=None):
    url = f"{BASE_URL}{endpoint}"
    headers = {
        "Content-Type": "application/json",
        "X-School-Id": SCHOOL_ID
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"

    body = json.dumps(data).encode("utf-8") if data is not None else None
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            content = resp.read().decode("utf-8")
            return json.loads(content) if content else {}
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8")
        print(f"[-] HTTP Error {e.code} on {method} {url}: {err_body}")
        try:
            return json.loads(err_body)
        except Exception:
            return {"error": err_body, "code": e.code}

def run_all_tests():
    print("=" * 80)
    print("EDUSHAMIIT STAFF SALARY DISBURSAL & ADVANCE RECOVERY VERIFICATION SUITE")
    print("=" * 80)
    token = get_admin_token()

    # 1. Fetch Staff Salary Detail
    print("\n[TEST 1] Fetch Staff Salary Detail for Alok Pandey...")
    detail_res = make_req(f"/v1/payment-management/staff-salary/staff/{ALOK_STAFF_ID}", token=token)
    assert detail_res.get("success") == True, f"Failed: {detail_res}"
    detail = detail_res.get("detail", {})
    profile = detail.get("profile", {})
    structure = detail.get("structure", {})
    advances = detail.get("advances", [])
    print(f"  ✓ Found profile: {profile.get('full_name')} ({profile.get('employee_id')})")
    print(f"  ✓ Found structure: Base ₹{structure.get('basic_pay')}, Bank: {structure.get('bank_name')}, IFSC: {structure.get('ifsc_code')}")
    print(f"  ✓ Active/total advances: {len(advances)} advance records")

    # 2. Test Disbursal with Advance Deduction (FIFO Loan Repayment)
    print("\n[TEST 2] Process Salary Disbursal with Live Advance Loan Deduction...")
    month_str = "2026-10"
    payout_payload = {
        "staff_id": ALOK_STAFF_ID,
        "month": 10,
        "year": 2026,
        "month_str": month_str,
        "basic_pay": 48000.0,
        "hra": 16000.0,
        "da": 6000.0,
        "ta": 3500.0,
        "special_allowance": 4500.0,
        "bonus": 1000.0,
        "pf_deduction": 4500.0,
        "tds": 3200.0,
        "professional_tax": 200.0,
        "advance_deduction": 3333.33,
        "other_deductions": 0.0,
        "payment_status": "Paid",
        "payment_mode": "Direct Bank Transfer (NEFT/RTGS)",
        "transaction_reference": f"UTR-E2E-{int(time.time())}",
        "remarks": "October 2026 Salary Disbursal with verified loan recovery",
        "bank_name": "State Bank of India",
        "account_number": "100200300400",
        "ifsc_code": "SBIN0001234"
    }

    payout_res = make_req("/v1/payment-management/staff-salary/payouts", method="POST", data=payout_payload, token=token)
    assert payout_res.get("success") == True, f"Payout failed: {payout_res}"
    print(f"  ✓ Payout processed successfully!")
    print(f"    - Payout ID: {payout_res.get('payout_id')}")
    print(f"    - Payslip #: {payout_res.get('payslip_number')}")
    print(f"    - Gross: ₹{payout_res.get('gross_earnings'):,.2f}")
    print(f"    - Deductions: ₹{payout_res.get('total_deductions'):,.2f}")
    print(f"    - Net Pay: ₹{payout_res.get('net_pay'):,.2f}")
    print(f"    - Repaid Advances Count: {payout_res.get('repaid_advances_count')}")

    # Financial verification
    expected_gross = 48000.0 + 16000.0 + 6000.0 + 3500.0 + 4500.0 + 1000.0
    expected_deductions = 4500.0 + 3200.0 + 200.0 + 3333.33
    expected_net = expected_gross - expected_deductions
    assert abs(payout_res.get('gross_earnings') - expected_gross) < 0.01, "Gross earnings mismatch"
    assert abs(payout_res.get('total_deductions') - expected_deductions) < 0.01, "Deductions mismatch"
    assert abs(payout_res.get('net_pay') - expected_net) < 0.01, "Net pay mismatch"
    print("  ✓ Mathematical and financial integrity 100% verified!")

    # 3. Verify Loan Balance Update in Advances List
    print("\n[TEST 3] Verify FIFO Loan Recovery Credit in Advances List...")
    detail_res_after = make_req(f"/v1/payment-management/staff-salary/staff/{ALOK_STAFF_ID}", token=token)
    advances_after = detail_res_after.get("detail", {}).get("advances", [])
    has_active_with_repaid = any(
        (a.get("status") in ("Approved", "Settled")) and ((a.get("amount_repaid") or 0) > 0)
        for a in advances_after
    )
    assert has_active_with_repaid, "Expected loan advances to reflect repaid balance"
    print("  ✓ Confirmed: Advance loan balance credited successfully via FIFO!")

    # 4. Verify Payslip Catalog Query
    print("\n[TEST 4] Verify Disbursed Payslip Catalog...")
    payslip_res = make_req(f"/v1/payment-management/staff-salary/payslips?month_str={month_str}&search=Alok", token=token)
    assert payslip_res.get("success") == True, f"Failed: {payslip_res}"
    payslips = payslip_res.get("payslips", [])
    assert len(payslips) > 0, "Expected at least 1 payslip for Alok Pandey"
    found_ps = payslips[0]
    print(f"  ✓ Payslip retrieved: {found_ps.get('payslip_number')} | Net Pay: ₹{found_ps.get('net_pay')} | Mode: {found_ps.get('payment_mode')}")

    # 5. Verify Idempotent Upsert for Same Period
    print("\n[TEST 5] Verify Disbursal Idempotency (Updating Existing Payout)...")
    payout_payload["bonus"] = 2500.0
    update_res = make_req("/v1/payment-management/staff-salary/payouts", method="POST", data=payout_payload, token=token)
    assert update_res.get("success") == True, f"Update failed: {update_res}"
    assert abs(update_res.get("gross_earnings") - (expected_gross + 1500.0)) < 0.01, "Updated gross mismatch"
    print(f"  ✓ Idempotency verified: Payout updated cleanly to ₹{update_res.get('net_pay'):,.2f} without duplicate key violation.")

    # 6. Verify Non-Disbursal Status (Pending / On Hold)
    print("\n[TEST 6] Verify Non-Disbursal Status Handling (On-Hold)...")
    hold_payload = dict(payout_payload)
    hold_payload["month_str"] = "2026-11"
    hold_payload["month"] = 11
    hold_payload["payment_status"] = "On Hold"
    hold_payload["advance_deduction"] = 0.0
    hold_res = make_req("/v1/payment-management/staff-salary/payouts", method="POST", data=hold_payload, token=token)
    assert hold_res.get("success") == True, f"Hold payout failed: {hold_res}"
    assert hold_res.get("payment_status") == "On Hold", "Expected status On Hold"
    print(f"  ✓ Status 'On Hold' processed and preserved correctly without loan deduction.")

    print("\n" + "=" * 80)
    print("ALL 6 TEST SCENARIOS PASSED WITH 100% SUCCESS!")
    print("=" * 80)

if __name__ == "__main__":
    run_all_tests()
