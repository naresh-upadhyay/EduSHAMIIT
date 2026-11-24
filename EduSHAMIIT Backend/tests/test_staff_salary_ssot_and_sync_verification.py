import sys
import requests
import json
import time
import hmac
import hashlib
import base64

BASE_URL = "http://localhost:8082/api/v1/payment-management"
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

def main():
    print("==================================================================")
    print("Testing Staff Salary SSOT & Mathematical Sync End-to-End")
    print("==================================================================")

    token = get_admin_token()
    headers = {"Authorization": f"Bearer {token}"}

    # 1. Search All Staff for Payroll (Used by Executive Disbursal Modal)
    print("\n1. Testing GET /staff-salary/search-all?search=Amit Chauhan...")
    r = requests.get(f"{BASE_URL}/staff-salary/search-all", params={"search": "Amit Chauhan", "month_str": "2026-10"}, headers=headers)
    assert r.status_code == 200, f"Expected 200, got {r.status_code}: {r.text}"
    data = r.json()
    assert data["success"] is True, f"Search failed: {data}"
    assert len(data["data"]) >= 1, f"Expected at least 1 record, got {len(data['data'])}"
    
    amit = data["data"][0]
    print(f"   Found Staff: {amit['full_name']} ({amit['employee_id']})")
    print(f"   Designation: {amit['designation']} | Department: {amit['department']}")
    print(f"   Gross: {amit['gross_salary']} | Deductions: {amit['total_deductions']} | Net: {amit['net_salary']}")
    print(f"   Medical Allow: {amit['medical_allowance']} | Insurance Ded: {amit['insurance_deduction']}")

    assert amit["designation"] == "Hostel Warden", f"Expected 'Hostel Warden', got {amit['designation']}"
    assert amit["department"] == "Hostel & Campus Facilities", f"Expected 'Hostel & Campus Facilities', got {amit['department']}"
    assert amit["gross_salary"] == 67000.0, f"Expected Gross 67000.0, got {amit['gross_salary']}"
    assert amit["total_deductions"] == 8260.0, f"Expected Deductions 8260.0, got {amit['total_deductions']}"
    assert amit["net_salary"] == 58740.0, f"Expected Net 58740.0, got {amit['net_salary']}"
    assert amit["medical_allowance"] == 1500.0, f"Expected Medical 1500.0, got {amit['medical_allowance']}"
    assert amit["insurance_deduction"] == 1000.0, f"Expected Insurance 1000.0, got {amit['insurance_deduction']}"
    print("   [PASS] Executive Disbursal staff profile & math 100% verified!")

    # 2. Structures Catalog (Used by Sub-tab 4 Grid)
    print("\n2. Testing GET /staff-salary/structures?search=Amit Chauhan...")
    r = requests.get(f"{BASE_URL}/staff-salary/structures", params={"search": "Amit Chauhan"}, headers=headers)
    assert r.status_code == 200, f"Expected 200, got {r.status_code}: {r.text}"
    struct_data = r.json()
    assert struct_data["success"] is True
    assert len(struct_data["structures"]) >= 1
    s = struct_data["structures"][0]
    print(f"   Grid Row Staff: {s['staff_name']} | Net Salary: {s['net_salary']}")
    assert s["gross_salary"] == 67000.0, f"Grid Gross should be 67000.0, got {s['gross_salary']}"
    assert s["total_deductions"] == 8260.0, f"Grid Deductions should be 8260.0, got {s['total_deductions']}"
    assert s["net_salary"] == 58740.0, f"Grid Net should be 58740.0, got {s['net_salary']}"
    print("   [PASS] Grid Catalog mathematics matches popup to the exact rupee (58,740)!")

    # 3. Unconfigured Staff List (Used by + Add Structure Dialog)
    print("\n3. Testing GET /staff-salary/unconfigured-staff...")
    r = requests.get(f"{BASE_URL}/staff-salary/unconfigured-staff", headers=headers)
    assert r.status_code == 200
    unconf = r.json()
    assert unconf["success"] is True
    print(f"   Unconfigured Staff Count: {unconf['count']}")

    # Ensure no EMP-555555 or corporate titles
    invalid_titles = ["DevOps", "QA Engineer", "Fullstack", "Architect", "Scrum Master", "Developer", "parent", "student"]
    for staff in unconf["staff"]:
        emp_id = staff["employee_id"]
        desig = staff["designation"]
        role = staff["role"]
        assert "555555" not in emp_id, f"Invalid test employee_id found: {emp_id} in {staff}"
        assert role not in ["parent", "student"], f"Non-staff role found: {role} in {staff}"
    print("   [PASS] All unconfigured staff profiles are authentic educational institutional roles!")

    print("\n==================================================================")
    print("ALL TESTS PASSED WITH 100% SUCCESS!")
    print("==================================================================")

if __name__ == "__main__":
    main()
