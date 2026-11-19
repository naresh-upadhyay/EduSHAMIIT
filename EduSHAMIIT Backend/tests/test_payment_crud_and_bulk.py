import requests
import json

BASE_URL = "http://localhost:8082/api/v1/payment-management"
token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJjZGZkYmFlMC1iN2Y5LTRhMzgtYjVjNy1iYjQyZGRjOWI0NWUiLCJlbWFpbCI6ImFkbWluQHNjaG9vbC5jb20iLCJyb2xlIjoiYWRtaW4iLCJzY2hvb2xfaWQiOiIxMTExMTExMS0xMTExLTExMTEtMTExMS0xMTExMTExMTExMTEiLCJleHAiOjE4OTM0NTYwMDB9.QF-VRC9LquYQEA0zxtzS8A8eJZgXs0qkNkG8JcXYLUw"
headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
session = requests.Session()

print("--- TEST 5: Student Fee Bulk Actions ---")
# 1. Fetch students from roster
roster_res = session.get(f"{BASE_URL}/student-fees/students?page=1&page_size=2", headers=headers)
assert roster_res.status_code == 200, f"Roster fetch failed: {roster_res.text}"
students = roster_res.json()["students"]
student_ids = [s["student_id"] for s in students]
print(f"Fetched {len(student_ids)} students for bulk test: {student_ids}")

# 2. Test send_reminder bulk action
reminder_res = session.post(
    f"{BASE_URL}/student-fees/bulk-actions",
    headers=headers,
    json={"action": "send_reminder", "ids": student_ids, "notes": "Automated Test Reminder"}
)
assert reminder_res.status_code == 200, f"Bulk reminder failed: {reminder_res.text}"
print("Bulk reminder response:", reminder_res.json())

# 3. Test mark_paid bulk action
paid_res = session.post(
    f"{BASE_URL}/student-fees/bulk-actions",
    headers=headers,
    json={"action": "mark_paid", "ids": [student_ids[0]]}
)
assert paid_res.status_code == 200, f"Bulk mark paid failed: {paid_res.text}"
print("Bulk mark paid response:", paid_res.json())

print("\n--- TEST 6: Staff Salary Bulk Actions ---")
# 1. Fetch staff members from roster
staff_res = session.get(f"{BASE_URL}/staff-salary/staff?month_str=2026-10&page=1&page_size=2", headers=headers)
assert staff_res.status_code == 200, f"Staff roster fetch failed: {staff_res.text}"
staff_members = staff_res.json()["staff"]
staff_ids = [s["staff_id"] for s in staff_members]
print(f"Fetched {len(staff_ids)} staff members for bulk test: {staff_ids}")

# 2. Test hold_selected bulk action
hold_res = session.post(
    f"{BASE_URL}/staff-salary/bulk-actions",
    headers=headers,
    json={"action": "hold_selected", "ids": staff_ids, "month_str": "2026-10", "notes": "Test Hold"}
)
assert hold_res.status_code == 200, f"Bulk hold failed: {hold_res.text}"
print("Bulk hold response:", hold_res.json())

# 3. Test disburse_selected bulk action
disburse_res = session.post(
    f"{BASE_URL}/staff-salary/bulk-actions",
    headers=headers,
    json={"action": "disburse_selected", "ids": staff_ids, "month_str": "2026-10", "payment_mode": "Direct Bank Transfer (NEFT/RTGS)"}
)
assert disburse_res.status_code == 200, f"Bulk disburse failed: {disburse_res.text}"
print("Bulk disburse response:", disburse_res.json())

print("\n--- TEST 7: Single Fee Collection & Receipt ---")
collect_res = session.post(
    f"{BASE_URL}/student-fees/payments",
    headers=headers,
    json={
        "student_id": student_ids[0],
        "amount": 2500.0,
        "payment_method": "UPI",
        "transaction_reference": "TXN-TEST-12345",
        "remarks": "Automated Integration Test Payment"
    }
)
assert collect_res.status_code in (200, 201), f"Fee collection failed: {collect_res.text}"
print("Collect payment response:", collect_res.json())

print("\n--- TEST 8: Staff Advance Request ---")
advance_res = session.post(
    f"{BASE_URL}/staff-salary/advances",
    headers=headers,
    json={
        "staff_id": staff_ids[0],
        "amount": 10000.0,
        "purpose_type": "Medical Emergency",
        "reason": "Emergency medical treatment for family member",
        "repayment_months": 3
    }
)
assert advance_res.status_code in (200, 201), f"Advance request failed: {advance_res.text}"
print("Advance request response:", advance_res.json())

print("\nALL BULK AND CRUD TESTS PASSED SUCCESSFULLY 100%!")
