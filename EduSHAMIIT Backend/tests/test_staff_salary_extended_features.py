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
    
    body = json.dumps(data).encode("utf-8") if data else None
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            content_type = resp.headers.get("Content-Type", "")
            if "text/csv" in content_type:
                return resp.status, resp.read().decode("utf-8")
            raw = resp.read().decode("utf-8")
            return resp.status, json.loads(raw)
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8")
        try:
            return e.code, json.loads(raw)
        except:
            return e.code, raw
    except Exception as e:
        return 500, str(e)

def run_tests():
    print("=================================================================")
    print("      EDUSHAMIIT STAFF SALARY EXTENDED FEATURES VERIFICATION     ")
    print("=================================================================")

    token = get_admin_token()
    print("[PASS] Generated valid JWT Token with superadmin privileges.\n")

    # 1. Test Roster & Net Pay calculation
    print("--- 1. Testing Staff Salary Roster & Dynamic Net Pay ---")
    status, res = make_req("/v1/payment-management/staff-salary/staff?month_str=2026-10&page=1&page_size=10", token=token)
    assert status == 200, f"Expected 200, got {status}: {res}"
    staff = res.get("staff", [])
    assert len(staff) > 0, "Expected non-empty staff list"
    
    net_pays = [s["actual_net_pay"] for s in staff]
    print(f"Sample Net Pay values: {net_pays[:5]}")
    # Verify values are distinct (NOT all 55,100)
    distinct_nets = set(net_pays)
    assert len(distinct_nets) > 1, f"Net pays are still uniform! Values: {distinct_nets}"
    for s in staff:
        assert s["actual_net_pay"] > 0, f"Net pay should be positive: {s['actual_net_pay']}"
        assert "actual_net_pay" in s, "actual_net_pay key missing"
    print(f"[PASS] Staff salary roster returns dynamic Net Pay across {len(staff)} staff members.")

    # 2. Test Salary Structures Catalog (Tab 4)
    print("\n--- 2. Testing Salary Structures Catalog (Tab 4) ---")
    status, res = make_req("/v1/payment-management/staff-salary/structures?page=1&page_size=5&sort_by=name&sort_order=ASC", token=token)
    assert status == 200, f"Expected 200, got {status}: {res}"
    structures = res.get("structures", [])
    total_structures = res.get("total_items", 0)
    print(f"Structures found: {len(structures)} (Total in DB: {total_structures})")
    assert len(structures) > 0, "Expected structures catalog items"
    first_struct = structures[0]
    assert "basic_pay" in first_struct and "gross_salary" in first_struct and "net_salary" in first_struct
    print(f"[PASS] Salary Structures Catalog returns paginated data (First: {first_struct['staff_name']} - Net: ₹{first_struct['net_salary']}).")

    # 3. Test Create / Update Salary Structure (Tab 4)
    print("\n--- 3. Testing Create / Assign Salary Structure ---")
    test_staff = staff[0]
    payload = {
        "staff_id": test_staff["staff_id"],
        "basic_pay": 48000.0,
        "hra": 16000.0,
        "da": 6000.0,
        "ta": 3500.0,
        "special_allowance": 4500.0,
        "medical_allowance": 2000.0,
        "pf_deduction": 4500.0,
        "tds": 3200.0,
        "professional_tax": 200.0,
        "insurance_deduction": 800.0,
        "bank_name": "State Bank of India",
        "account_number": "100200300400",
        "ifsc_code": "SBIN0001234",
        "pan_number": "ABCDE1234F",
        "payment_mode": "Direct Bank Transfer (NEFT/RTGS)"
    }
    status, res = make_req("/v1/payment-management/staff-salary/structures", "POST", payload, token=token)
    assert status in (200, 201), f"Expected 200/201, got {status}: {res}"
    assert res.get("success") == True, f"Operation failed: {res}"
    print(f"[PASS] Salary structure updated successfully for staff: {test_staff['staff_name']}.")

    # 4. Test Monthly Payslips Master (Tab 5)
    print("\n--- 4. Testing Monthly Payslips Master (Tab 5) ---")
    status, res = make_req("/v1/payment-management/staff-salary/payslips?month_str=2026-10&page=1&page_size=5", token=token)
    assert status == 200, f"Expected 200, got {status}: {res}"
    payslips = res.get("payslips", [])
    total_payslips = res.get("total_items", 0)
    print(f"Payslips retrieved: {len(payslips)} (Total: {total_payslips})")
    assert len(payslips) > 0, "Expected payslips records"
    first_ps = payslips[0]
    assert "payslip_number" in first_ps and "net_pay" in first_ps
    print(f"[PASS] Monthly Payslips Registry returns paginated records (First: {first_ps['payslip_number']} for {first_ps['staff_name']}).")

    # 5. Test Bank Disbursal File Export
    print("\n--- 5. Testing Corporate Bank Disbursal CSV Streaming ---")
    status, csv_data = make_req("/v1/payment-management/staff-salary/export/bank-file?month_str=2026-10", token=token)
    assert status == 200, f"Expected 200, got {status}"
    lines = csv_data.strip().split("\n")
    assert len(lines) > 1, f"Expected header + data lines, got {len(lines)}"
    assert "Beneficiary Name" in lines[0] and "Account Number" in lines[0] and "Disbursal Amount" in lines[0]
    print(f"[PASS] Bank NEFT/NACH disbursal file generated ({len(lines)-1} beneficiary records).")

    # 6. Test Salary Advances Master (Tab 6)
    print("\n--- 6. Testing Salary Advances Master (Tab 6) ---")
    status, res = make_req("/v1/payment-management/staff-salary/advances?page=1&page_size=5", token=token)
    assert status == 200, f"Expected 200, got {status}: {res}"
    advances = res.get("advances", [])
    total_advances = res.get("total_items", 0)
    print(f"Advances retrieved: {len(advances)} (Total: {total_advances})")
    assert len(advances) > 0, "Expected advances records"
    first_adv = advances[0]
    assert "outstanding_balance" in first_adv and "progress_pct" in first_adv
    print(f"[PASS] Advances Ledger returns ledger with balance & recovery progress (First: ₹{first_adv['amount']} with ₹{first_adv['outstanding_balance']} outstanding).")

    # 7. Test Early Settlement of Salary Advance
    print("\n--- 7. Testing Early Advance Settlement ---")
    adv_id = first_adv["id"]
    settle_payload = {
        "settlement_amount": 500.0,
        "payment_mode": "Cash",
        "remarks": "Test partial clearance"
    }
    status, res = make_req(f"/v1/payment-management/staff-salary/advances/{adv_id}/settle", "POST", settle_payload, token=token)
    assert status == 200, f"Expected 200, got {status}: {res}"
    assert res.get("success") == True, f"Settlement failed: {res}"
    print(f"[PASS] Advance settlement executed: remaining balance is ₹{res.get('outstanding_balance')}.")

    print("\n=================================================================")
    print("        ALL 7 EXTENDED STAFF SALARY BACKEND TESTS PASSED!        ")
    print("=================================================================")

if __name__ == "__main__":
    run_tests()
