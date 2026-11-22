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
    req = urllib.request.Request(url, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    body = json.dumps(data).encode("utf-8") if data else None
    try:
        with urllib.request.urlopen(req, data=body, timeout=10) as resp:
            return resp.status, json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        err_msg = e.read().decode("utf-8")
        return e.code, {"error": err_msg}
    except Exception as e:
        return 500, {"error": str(e)}

def run_tests():
    token = get_admin_token()
    print("[1] Testing GET /v1/payment-management/staff-salary/unconfigured-staff...")
    code, res = make_req("/v1/payment-management/staff-salary/unconfigured-staff", token=token)
    print(f"Status: {code}")
    assert code == 200, f"Expected 200, got {code}: {res}"
    print(f"Success: {res.get('success')}, Unconfigured count: {res.get('count')}")
    assert res.get("count", 0) > 0, "Expected unconfigured staff to be found"
    
    first_staff = res["staff"][0]
    print(f"Sample unconfigured staff: {first_staff.get('staff_name')} ({first_staff.get('employee_id')}) - Role: {first_staff.get('role')}")

    print("\n[2] Testing GET /v1/payment-management/staff-salary/structures (Configured catalog)...")
    code, cat = make_req("/v1/payment-management/staff-salary/structures?page=1&page_size=10", token=token)
    print(f"Status: {code}, Total configured: {cat.get('total_items')}")
    assert code == 200
    assert cat.get("total_items", 0) > 0

    print("\n[3] Testing POST /v1/payment-management/staff-salary/auto-payroll-run...")
    auto_payload = {
        "month_str": "2026-11",
        "payment_mode": "Direct Bank Transfer (NEFT/RTGS)",
        "send_email_notifications": True
    }
    code, auto_res = make_req("/v1/payment-management/staff-salary/auto-payroll-run", method="POST", data=auto_payload, token=token)
    print(f"Status: {code}, Result: {auto_res.get('message')}")
    assert code == 200
    print(f"Generated count: {auto_res.get('generated_count')}, Eligible: {auto_res.get('eligible_count')}")

    print("\nALL BACKEND API TESTS PASSED SUCCESSFULLY!")

if __name__ == "__main__":
    run_tests()
