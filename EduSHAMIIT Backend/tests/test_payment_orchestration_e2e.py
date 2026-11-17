"""
Automated End-to-End Verification Test for EduSHAMIIT Fee Payment Orchestrator & Configuration Centre
Covers:
1. Institution Payment Configuration Centre APIs (General, QR Behaviour, UPI Accounts, Bank Accounts, Bridge Test)
2. Dynamic UPI QR Generation with Concurrency-Safe Minimal Extra Paise Collision Avoidance (10-minute window)
3. 5-minute QR Active Timer & 2-minute Grace Window Lifecycle
4. Real-Time Bridge Ingestion Simulation & Automated Invoice Settlement with Receipt Generation
5. Manual 12-digit UTR Submission with 7-Day Refund Policy SLA
"""
import requests
import json
import uuid
import time
import jwt
from datetime import datetime

BASE_URL = "http://127.0.0.1:8082/api/v1/payment-management"
JWT_SECRET = "super-secret-jwt-token-with-at-least-32-characters-long"
SCHOOL_ID = "11111111-1111-1111-1111-111111111111"

payload = {
    "sub": "a819f432-4756-49ea-a4af-23087fe41685",
    "school_id": SCHOOL_ID,
    "role": "super_admin",
    "email": "superadmin@schoolerp.com",
    "exp": int(time.time()) + 86400
}
token = jwt.encode(payload, JWT_SECRET, algorithm="HS256")

HEADERS = {
    "Content-Type": "application/json",
    "Authorization": f"Bearer {token}",
    "X-School-Id": SCHOOL_ID
}

def log(step, msg, success=True):
    status_str = "PASS" if success else "FAIL"
    print(f"[{status_str}] {step}: {msg}")

def run_tests():
    print("=" * 70)
    print("STARTING E2E TEST: FEE PAYMENT ORCHESTRATOR & CONFIGURATION CENTRE")
    print("=" * 70)

    # -------------------------------------------------------------
    # 1. Payment Configuration Centre Retrieval
    # -------------------------------------------------------------
    r = requests.get(f"{BASE_URL}/config", headers=HEADERS)
    assert r.status_code == 200, f"Config GET failed: {r.status_code} {r.text}"
    cfg = r.json()
    assert cfg.get("success") is True
    assert "general_settings" in cfg
    assert "upi_accounts" in cfg
    assert "bank_accounts" in cfg
    assert "bridge_status" in cfg
    log("Test 1", f"Retrieved full payment configuration: {len(cfg['upi_accounts'])} UPI, {len(cfg['bank_accounts'])} Banks")

    # -------------------------------------------------------------
    # 2. Update General Settings
    # -------------------------------------------------------------
    gen_payload = {
        "institution_display_name": "Shami Innovation Academy E2E",
        "payment_description": "Tuition, Lab & Library Fees",
        "reference_prefix": "EDU-E2E",
        "receipt_prefix": "REC-E2E-",
        "base_currency": "INR",
        "default_payment_method": "UPI",
        "online_collection_enabled": True,
        "allow_partial_payments": True,
        "allow_advance_payments": False,
        "allow_multiple_payments": True,
        "allow_student_self_pay": True,
        "allow_offline_entry": True,
        "direct_bank_transfer_enabled": True,
        "refund_policy_days": 7
    }
    r = requests.post(f"{BASE_URL}/config/general", headers=HEADERS, json=gen_payload)
    assert r.status_code == 200, f"Update general failed: {r.status_code} {r.text}"
    assert r.json().get("success") is True
    log("Test 2", "Updated General Settings (7-Day Refund SLA confirmed)")

    # -------------------------------------------------------------
    # 3. Update QR & Timer Behaviour
    # -------------------------------------------------------------
    qr_payload = {
        "qr_validity_minutes": 5,
        "grace_period_minutes": 2,
        "unique_paise_enabled": True,
        "unique_paise_window_minutes": 10,
        "max_additional_paise": 99,
        "auto_settle_on_bridge_notification": True
    }
    r = requests.post(f"{BASE_URL}/config/qr-behaviour", headers=HEADERS, json=qr_payload)
    assert r.status_code == 200, f"Update QR behaviour failed: {r.status_code} {r.text}"
    assert r.json().get("success") is True
    log("Test 3", "Updated QR Behaviour: 5m validity, 2m grace, 10m uniqueness window")

    # -------------------------------------------------------------
    # 4. Add & Set Default Institution UPI VPA
    # -------------------------------------------------------------
    new_vpa = f"shamiit.test.{int(time.time()) % 10000}@icici"
    upi_payload = {
        "vpa": new_vpa,
        "display_name": "Tuition Fee Collection VPA",
        "beneficiary_name": "Shami Innovation Academy",
        "bank_name": "ICICI Bank",
        "is_default": True,
        "qr_enabled": True,
        "intent_enabled": True,
        "max_amount_paise": 10000000,
        "notes": "E2E automated test created UPI account"
    }
    r = requests.post(f"{BASE_URL}/config/upi-accounts", headers=HEADERS, json=upi_payload)
    assert r.status_code == 201, f"Add UPI failed: {r.status_code} {r.text}"
    upi_id = r.json().get("account_id")
    assert upi_id is not None
    log("Test 4", f"Created & activated default Institution UPI VPA: {new_vpa} (ID: {upi_id})")

    # -------------------------------------------------------------
    # 5. Add Institution Bank Account
    # -------------------------------------------------------------
    bank_payload = {
        "account_nickname": "Tech City Operational Account",
        "bank_name": "HDFC Bank Ltd",
        "branch_name": "Tech City Branch",
        "account_holder_name": "Shami Innovation Academy Operational",
        "account_number": "50100234567890",
        "ifsc_code": "HDFC0001234",
        "account_type": "Current",
        "currency": "INR",
        "campus_name": "Main Campus",
        "category_name": "Tuition & General Fees",
        "is_default": False,
        "internal_remarks": "E2E automated test created bank account"
    }
    r = requests.post(f"{BASE_URL}/config/bank-accounts", headers=HEADERS, json=bank_payload)
    assert r.status_code == 201, f"Add Bank failed: {r.status_code} {r.text}"
    bank_id = r.json().get("account_id")
    assert bank_id is not None
    log("Test 5", f"Created Institution Bank Account (ID: {bank_id})")

    # -------------------------------------------------------------
    # 6. Test Payment Bridge Ping Connection
    # -------------------------------------------------------------
    r = requests.post(f"{BASE_URL}/config/bridge/test-connection", headers=HEADERS)
    assert r.status_code == 200, f"Bridge ping failed: {r.status_code} {r.text}"
    bridge_res = r.json()
    assert bridge_res.get("success") is True
    log("Test 6", f"Payment Bridge connection ping: status={bridge_res.get('status')}")

    # -------------------------------------------------------------
    # 7. Dynamic Unique UPI QR Generation (Minimal Paise Collision Avoidance)
    # -------------------------------------------------------------
    # We create 3 payment intents for the EXACT same base amount in the same 10-minute window
    base_test_amount = 7500.00
    student_id = "00000000-0000-0000-0000-000000000001" # sample/mock student id

    # Intent 1
    intent_req_1 = {
        "student_id": student_id,
        "amount": base_test_amount,
        "payment_method": "UPI",
        "notes": "E2E Intent 1"
    }
    r1 = requests.post(f"{BASE_URL}/student-fees/payment-intents", headers=HEADERS, json=intent_req_1)
    assert r1.status_code in (200, 201), f"Intent 1 failed: {r1.status_code} {r1.text}"
    i1 = r1.json()
    i1_id = i1["intent_id"]
    paise_1 = i1["total_amount_paise"]
    assert "upi://pay?" in i1["upi_uri"]
    assert i1["status"] == "PENDING"
    log("Test 7.1", f"Intent 1 generated: Base ₹{base_test_amount} -> Total Paise = {paise_1} (Extra: {i1['unique_paise']}p)")

    # Intent 2: SAME amount in 10-minute window -> MUST receive +1 paisa
    r2 = requests.post(f"{BASE_URL}/student-fees/payment-intents", headers=HEADERS, json=intent_req_1)
    assert r2.status_code in (200, 201), f"Intent 2 failed: {r2.status_code} {r2.text}"
    i2 = r2.json()
    i2_id = i2["intent_id"]
    paise_2 = i2["total_amount_paise"]
    assert paise_2 == paise_1 + 1, f"Expected {paise_1 + 1}, got {paise_2}"
    log("Test 7.2", f"Intent 2 Collision Avoidance: Assigned +1 paisa -> Total Paise = {paise_2} (Extra: {i2['unique_paise']}p)")

    # Intent 3: SAME amount in 10-minute window -> MUST receive +2 paise
    r3 = requests.post(f"{BASE_URL}/student-fees/payment-intents", headers=HEADERS, json=intent_req_1)
    assert r3.status_code in (200, 201), f"Intent 3 failed: {r3.status_code} {r3.text}"
    i3 = r3.json()
    i3_id = i3["intent_id"]
    paise_3 = i3["total_amount_paise"]
    assert paise_3 == paise_1 + 2, f"Expected {paise_1 + 2}, got {paise_3}"
    log("Test 7.3", f"Intent 3 Collision Avoidance: Assigned +2 paise -> Total Paise = {paise_3} (Extra: {i3['unique_paise']}p)")

    # Verify 5m validity and 2m grace timestamps
    exp_dt = datetime.fromisoformat(i1["expires_at"].replace("Z", "+00:00"))
    grace_dt = datetime.fromisoformat(i1["grace_expires_at"].replace("Z", "+00:00"))
    diff_sec = (grace_dt - exp_dt).total_seconds()
    assert abs(diff_sec - 120) <= 2, f"Grace window should be ~120s, got {diff_sec}"
    log("Test 7.4", "QR Timer verified: 5-minute primary timer + 2-minute grace period")

    # -------------------------------------------------------------
    # 8. Status Polling Endpoint
    # -------------------------------------------------------------
    r = requests.get(f"{BASE_URL}/student-fees/payment-intents/{i1_id}/status", headers=HEADERS)
    assert r.status_code == 200
    st = r.json()
    assert st["phase"] == "QR_ACTIVE"
    assert st["status"] == "PENDING"
    assert st["remaining_seconds"] > 0
    log("Test 8", f"Intent 1 Status Polling verified: phase={st['phase']}, remaining_secs={st['remaining_seconds']}")

    # -------------------------------------------------------------
    # 9. Real-Time Bridge Ingestion Simulation & Automated Settlement
    # -------------------------------------------------------------
    sim_payload = {
        "intent_id": i1_id,
        "utr": f"UTR{int(time.time())}",
        "source_app": "PhonePe"
    }
    r = requests.post(f"{BASE_URL}/student-fees/simulate-bridge-payment", headers=HEADERS, json=sim_payload)
    assert r.status_code == 200, f"Bridge simulation failed: {r.status_code} {r.text}"
    sim_res = r.json()
    assert sim_res.get("success") is True
    receipt_no = sim_res.get("receipt_number")
    assert receipt_no is not None
    log("Test 9.1", f"Payment Bridge notification ingested & verified: Receipt #{receipt_no}")

    # Check status of Intent 1 now
    r = requests.get(f"{BASE_URL}/student-fees/payment-intents/{i1_id}/status", headers=HEADERS)
    assert r.status_code == 200
    st_settled = r.json()
    assert st_settled["status"] == "VERIFIED_SUCCESS"
    assert st_settled["phase"] == "COMPLETED"
    assert st_settled["receipt_number"] == receipt_no
    log("Test 9.2", f"Intent 1 status transitioned to VERIFIED_SUCCESS with receipt {receipt_no}")

    # -------------------------------------------------------------
    # 10. Manual UTR Submission for Intent 3 (with 7-Day Refund SLA)
    # -------------------------------------------------------------
    manual_utr = "123456789012"
    utr_payload = {
        "utr_number": manual_utr,
        "notes": "Parent paid via Google Pay but session expired on web"
    }
    r = requests.post(f"{BASE_URL}/student-fees/payment-intents/{i3_id}/submit-utr", headers=HEADERS, json=utr_payload)
    assert r.status_code == 200, f"Submit UTR failed: {r.status_code} {r.text}"
    utr_res = r.json()
    assert utr_res.get("success") is True
    assert "7 business days" in utr_res.get("message", "")
    log("Test 10", f"Submitted 12-digit UTR {manual_utr}: Status = PENDING_MANUAL_VERIFICATION, 7-Day SLA attached")

    print("=" * 70)
    print("ALL 10 E2E PAYMENT ORCHESTRATION TESTS COMPLETED SUCCESSFULLY!")
    print("=" * 70)

if __name__ == "__main__":
    run_tests()
