import asyncio
import json
import hmac
import hashlib
import base64
import time
import httpx

BASE_URL = "http://localhost:8000/api/v1/payment-management"
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

async def run_tests():
    print("=== STARTING COMPREHENSIVE E2E VERIFICATION TEST ===")
    token_payload = {
        "sub": "00000000-0000-0000-0000-000000000001",
        "id": "00000000-0000-0000-0000-000000000001",
        "school_id": SCHOOL_ID,
        "role": "Super Admin",
        "full_name": "King Doe",
        "email": "king@edushamiit.com",
        "exp": int(time.time()) + 3600
    }
    token = create_jwt_token(token_payload, JWT_SECRET)
    headers = {"Authorization": f"Bearer {token}"}

    async with httpx.AsyncClient(timeout=30.0) as client:
        # 1. Test Payment Deletion Security Guard (Audit Protection)
        print("\n1. Testing Payment Deletion Security Guard...")
        pays_res = await client.get(f"{BASE_URL}/student-fees/payments-list", headers=headers)
        assert pays_res.status_code == 200, f"Failed to get payments: {pays_res.text}"
        pays_data = pays_res.json()
        payments = pays_data.get("payments", [])
        print(f"Found {len(payments)} payments in master registry.")

        if payments:
            completed_pay = next((p for p in payments if (p.get("status") or "").upper() in ("COMPLETED", "SUCCESS", "CLEARED") or float(p.get("amount_paid") or 0) > 0), None)
            if completed_pay:
                pay_id = completed_pay["id"]
                rcpt_no = completed_pay["receipt_number"]
                print(f"Attempting deletion on completed receipt {rcpt_no} (ID: {pay_id})...")
                del_res = await client.delete(f"{BASE_URL}/student-fees/payments/{pay_id}", headers=headers)
                print(f"Delete response: {del_res.status_code} - {del_res.text}")
                assert del_res.status_code == 400, f"Expected 400 for completed payment deletion, got {del_res.status_code}"
                assert "audit" in del_res.text.lower() or "completed" in del_res.text.lower(), "Expected audit protection message in response"
                print("SUCCESS: Completed payment deletion was strictly rejected by backend audit protection!")

        # 2. Test Invoices List returns student_advance_balance
        print("\n2. Testing Invoices List API for student_advance_balance...")
        invs_res = await client.get(f"{BASE_URL}/student-fees/invoices-list", headers=headers)
        assert invs_res.status_code == 200, f"Failed to get invoices: {invs_res.text}"
        invs_data = invs_res.json()
        invoices = invs_data.get("invoices", [])
        print(f"Found {len(invoices)} invoices in registry.")
        if invoices:
            first_inv = invoices[0]
            print(f"Sample Invoice {first_inv.get('invoice_number')}: Student={first_inv.get('student_name')}, Advance Balance={first_inv.get('student_advance_balance')}")
            assert "student_advance_balance" in first_inv, "student_advance_balance column missing from invoice item"
            print("SUCCESS: Invoices API successfully returns live student_advance_balance!")

        # 3. Test Single Invoice Generation with Advance Credit Auto-Deduction
        print("\n3. Testing Invoice Generation with Advance Credit Auto-Deduction...")
        studs_res = await client.get(f"{BASE_URL}/student-fees/students?search=Aditi%20Sharma", headers=headers)
        assert studs_res.status_code == 200, f"Failed to search student: {studs_res.text}"
        students = studs_res.json().get("students", [])
        assert len(students) > 0, "Aditi Sharma not found"
        aditi = students[0]
        aditi_id = aditi["student_id"]
        print(f"Found student {aditi['student_name']} (ID: {aditi_id}), Advance Credit = {aditi.get('advance_amount')}")

        new_inv_payload = {
            "student_id": aditi_id,
            "title": "Automated Advance Credit Test Invoice",
            "fee_type": "Tuition Fee",
            "fee_plan": "Monthly",
            "academic_year": "2026 - 2027",
            "due_date": "2026-12-15",
            "subtotal": 2500.0,
            "concession_amount": 0.0,
            "penalty_amount": 0.0,
            "notes": "Testing advance credit auto deduction engine"
        }
        create_res = await client.post(f"{BASE_URL}/student-fees/invoices", json=new_inv_payload, headers=headers)
        print(f"Invoice creation response: {create_res.status_code} - {create_res.text}")
        assert create_res.status_code == 201, f"Failed to create invoice: {create_res.text}"
        created_data = create_res.json()
        assert created_data.get("success") == True, "Invoice creation unsuccessful"
        assert created_data.get("advance_deducted", 0) > 0, "Expected advance credit to be auto-deducted!"
        assert created_data.get("status") == "Paid", "Expected invoice to be immediately Paid by advance credit!"
        created_inv_id = created_data.get("invoice_id")
        print(f"SUCCESS: New Invoice {created_data.get('invoice_number')} was generated and automatically settled using advance credit! Status={created_data.get('status')}, Advance Deducted={created_data.get('advance_deducted')}")

        # 4. Test Dedicated Advance Settle Endpoint (fn_settle_invoice_from_advance)
        print("\n4. Testing Dedicated Settle-From-Advance Endpoint...")
        settle_res = await client.post(f"{BASE_URL}/student-fees/invoices/{created_inv_id}/settle-from-advance", headers=headers)
        print(f"Settle response: {settle_res.status_code} - {settle_res.text}")
        assert settle_res.status_code == 400 or settle_res.json().get("success") == True
        print("SUCCESS: Settle-from-advance endpoint responded correctly!")

        # 5. Test Auto-Settle All Student Invoices
        print("\n5. Testing Auto-Settle All Invoices for Student...")
        settle_all_res = await client.post(f"{BASE_URL}/student-fees/students/{aditi_id}/settle-advance", headers=headers)
        assert settle_all_res.status_code == 200, f"Failed to auto-settle: {settle_all_res.text}"
        print(f"Auto-settle all result: {settle_all_res.json()}")
        print("SUCCESS: Auto-settle all student invoices executed flawlessly!")

    print("\n=== ALL E2E VERIFICATION TESTS PASSED WITH 100% SUCCESS! ===")

if __name__ == "__main__":
    asyncio.run(run_tests())
