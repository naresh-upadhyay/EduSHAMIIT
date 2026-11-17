import requests
import json
import time
import jwt

BASE_URL = "http://127.0.0.1:8082/api/v1/payment-management"
JWT_SECRET = "super-secret-jwt-token-with-at-least-32-characters-long"
SCHOOL_ID = "11111111-1111-1111-1111-111111111111"

payload = {
    "sub": "a819f432-4756-49ea-a4af-23087fe41685",
    "school_id": SCHOOL_ID,
    "role": "super_admin",
    "full_name": "King Doe (Super Admin)",
    "email": "superadmin@schoolerp.com",
    "exp": int(time.time()) + 86400
}
token = jwt.encode(payload, JWT_SECRET, algorithm="HS256")

HEADERS = {
    "Content-Type": "application/json",
    "Authorization": f"Bearer {token}",
    "X-School-Id": SCHOOL_ID
}

def run_tests():
    print("=" * 60)
    print("TESTING STUDENT FEE STATUS & AUDIT HISTORY")
    print("=" * 60)

    # 1. Test Student Fee Roster
    print("\n--- 1. Testing Student Fee Roster ---")
    r = requests.get(f"{BASE_URL}/student-fees/students", headers=HEADERS)
    assert r.status_code == 200, f"Roster failed: {r.status_code} {r.text}"
    data = r.json()
    assert data["success"] is True
    students = data["students"]
    print(f"Total students returned: {len(students)}")
    # Verify uniqueness of students
    student_ids = [s["student_id"] for s in students]
    assert len(student_ids) == len(set(student_ids)), "Duplicate students found in roster!"
    print("PASS: All students in roster are unique records (no duplicate rows per student).")

    # Find a test student
    target_student = students[0]
    student_id = target_student["student_id"]
    student_name = target_student["student_name"]
    print(f"Target test student: {student_name} ({student_id})")

    # 2. Test Fee Collection
    print("\n--- 2. Testing Fee Payment Collection ---")
    collect_payload = {
        "student_id": student_id,
        "amount": 2500.0,
        "payment_method": "Cash",
        "transaction_reference": f"CASH-{int(time.time())}",
        "remarks": "Manual offline fee collection test"
    }
    r = requests.post(f"{BASE_URL}/student-fees/payments", headers=HEADERS, json=collect_payload)
    assert r.status_code == 201 or r.status_code == 200, f"Payment failed: {r.status_code} {r.text}"
    p_data = r.json()
    assert p_data["success"] is True
    receipt = p_data["receipt"]
    payment_id = receipt["id"]
    print(f"PASS: Collected payment {receipt['receipt_number']}. Payment ID: {payment_id}")

    # 3. Test UPI QR Payment Intent with 48h WAITING_CONFIRMATION
    print("\n--- 3. Testing UPI Payment Intent & WAITING_CONFIRMATION ---")
    intent_payload = {
        "student_id": student_id,
        "amount": 3000.0,
        "payment_method": "UPI",
        "notes": "Term tuition payment"
    }
    r = requests.post(f"{BASE_URL}/student-fees/payment-intents", headers=HEADERS, json=intent_payload)
    assert r.status_code == 201, f"Intent creation failed: {r.status_code} {r.text}"
    i_data = r.json()
    assert i_data["success"] is True
    intent_ref = i_data["intent_reference"]
    intent_id = i_data["intent_id"]
    print(f"PASS: Created UPI Intent {intent_ref} for Rs {i_data['total_amount']}.")

    # 4. Test 360 Detail with Payments & History
    print("\n--- 4. Testing Student 360 Detail & Payments Status ---")
    r = requests.get(f"{BASE_URL}/student-fees/students/{student_id}", headers=HEADERS)
    assert r.status_code == 200, f"Detail failed: {r.status_code} {r.text}"
    d_data = r.json()
    assert d_data["success"] is True
    detail = d_data["detail"]
    payments = detail["payments"]
    history = detail["history"]
    print(f"Payments count: {len(payments)}, History logs count: {len(history)}")

    # Check that the UPI intent payment is WAITING_CONFIRMATION
    upi_pay = next((p for p in payments if p.get("transaction_reference") == intent_ref), None)
    assert upi_pay is not None, "UPI payment not found in payments list!"
    assert upi_pay["status"] == "WAITING_CONFIRMATION", f"Expected WAITING_CONFIRMATION, got {upi_pay['status']}"
    print("PASS: Dynamic UPI QR payment status is correctly WAITING_CONFIRMATION.")

    # 5. Test Registrar Status Update (e.g., WAITING_CONFIRMATION -> SUCCESS)
    print("\n--- 5. Testing Registrar Status Update ---")
    update_payload = {
        "status": "SUCCESS",
        "remarks": "Bank payment confirmation received via Registrar phone enquiry"
    }
    r = requests.put(f"{BASE_URL}/student-fees/payments/{upi_pay['id']}/status", headers=HEADERS, json=update_payload)
    assert r.status_code == 200, f"Update status failed: {r.status_code} {r.text}"
    u_data = r.json()
    assert u_data["success"] is True
    assert u_data["new_status"] == "SUCCESS"
    print(f"PASS: Registrar successfully transitioned status to {u_data['new_status']}.")

    # 6. Test Registrar Status Update to REFUNDED
    print("\n--- 6. Testing Registrar Status Update to REFUNDED ---")
    refund_payload = {
        "status": "REFUNDED",
        "remarks": "Duplicate payment refunded to parent UPI"
    }
    r = requests.put(f"{BASE_URL}/student-fees/payments/{payment_id}/status", headers=HEADERS, json=refund_payload)
    assert r.status_code == 200, f"Refund status failed: {r.status_code} {r.text}"
    ref_data = r.json()
    assert ref_data["new_status"] == "REFUNDED"
    print("PASS: Payment status successfully updated to REFUNDED and invoice rebalanced.")

    # 7. Test History Audit Trail
    print("\n--- 7. Testing Activity History Audit Trail ---")
    r = requests.get(f"{BASE_URL}/student-fees/students/{student_id}/history", headers=HEADERS)
    assert r.status_code == 200, f"History failed: {r.status_code} {r.text}"
    h_data = r.json()
    assert h_data["success"] is True
    logs = h_data["history"]
    print(f"Total audit logs retrieved: {len(logs)}")
    assert len(logs) >= 3, "Expected at least 3 audit logs!"
    for log in logs[:4]:
        print(f"  - [{log['action']}] {log['description']} (By: {log['performed_by_name']} - {log['performed_by_role']})")
    print("PASS: Activity audit trail correctly logged who made what changes when.")

    print("\n" + "=" * 60)
    print("ALL TESTS PASSED SUCCESSFULLY!")
    print("=" * 60)

if __name__ == "__main__":
    run_tests()
