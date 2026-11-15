import os
import sys
import asyncio
import time
import uuid
import struct
import hmac
import hashlib
import base64
from datetime import datetime

# Setup path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

# Resolve local Kong gateway if host is outside docker container
if not os.environ.get("SUPABASE_URL") or "kong" in os.environ.get("SUPABASE_URL", ""):
    os.environ["SUPABASE_URL"] = "http://127.0.0.1:8000"

from app.config import settings
if "kong" in settings.SUPABASE_URL:
    settings.SUPABASE_URL = "http://127.0.0.1:8000"

from fastapi.testclient import TestClient
from app.main import app
from app.middleware.auth import get_current_user
from app.services.supabase_client import get_supabase
from app.config import settings

def _generate_totp_code_for_secret(secret_key: str) -> str:
    """Generate valid 6-digit TOTP code for the current 30s window using HMAC-SHA1."""
    key = base64.b32decode(secret_key, casefold=True)
    counter = int(time.time() // 30)
    counter_bytes = struct.pack(">Q", counter)
    digest = hmac.new(key, counter_bytes, hashlib.sha1).digest()
    offset = digest[-1] & 0x0F
    code_int = struct.unpack(">I", digest[offset : offset + 4])[0] & 0x7FFFFFFF
    return str(code_int % 1000000).zfill(6)

async def async_setup_test_user():
    """Ensure a consistent test user profile exists in public.profiles."""
    sb = get_supabase()
    test_user_id = "00000000-0000-0000-0000-000000000999"
    test_email = "universal.profile.tester@edushamiit.com"
    
    # Check if exists
    res = await sb.table("profiles").select("*").eq("id", test_user_id).maybe_single().aexecute()
    if not res.data:
        profile_data = {
            "id": test_user_id,
            "user_id": "TEST-PRO-001",
            "email": test_email,
            "full_name": "Universal Profile Tester",
            "role": "teacher",
            "status": "Active",
            "phone": "+919999888877",
            "specialization": "Quantum Computing",
            "house": "Alpha Phoenix",
            "preferred_language": "English (US)",
            "timezone": "(GMT +05:30) Asia/Kolkata",
            "preferred_theme": "dark",
            "created_at": datetime.utcnow().isoformat(),
            "updated_at": datetime.utcnow().isoformat()
        }
        await sb.table("profiles").insert(profile_data).aexecute()
    else:
        # Reset baseline fields
        await sb.table("profiles").update({
            "specialization": "Quantum Computing",
            "house": "Alpha Phoenix",
            "two_factor_enabled": False,
            "two_factor_secret": None,
            "two_factor_backup_codes": []
        }).eq("id", test_user_id).aexecute()

    return test_user_id, test_email

def run_all_tests():
    print("=" * 70)
    print("RUNNING END-TO-END PROFILE & ENTERPRISE SECURITY EDGE CASE TESTS")
    print("=" * 70)

    # 1. Setup mock user & dependency overrides
    test_user_id, test_email = asyncio.run(async_setup_test_user())
    mock_user = {
        "id": test_user_id,
        "email": test_email,
        "role": "teacher",
        "school_id": None
    }
    app.dependency_overrides[get_current_user] = lambda: mock_user
    client = TestClient(app)

    passed_count = 0
    total_count = 0

    def assert_test(condition: bool, test_name: str, details: str = ""):
        nonlocal passed_count, total_count
        total_count += 1
        if condition:
            passed_count += 1
            print(f"  [PASS] {test_name}")
        else:
            print(f"  [FAIL] {test_name} - {details}")
            raise AssertionError(f"Test failed: {test_name} - {details}")

    # TEST 1: GET /api/admin/schools/my-profile
    print("\n--- Test 1: Fetch Profile with Extended Universal Fields ---")
    res = client.get("/api/admin/schools/my-profile")
    assert_test(res.status_code == 200, "Profile endpoint returns HTTP 200")
    data = res.json()
    assert_test(data.get("success") is True, "Response success flag is True")
    prof = data.get("profile", {})
    assert_test(prof.get("id") == test_user_id, "Profile user ID matches test user")
    assert_test("preferred_language" in prof, "Profile includes 'preferred_language' column")
    assert_test("address_line1" in prof, "Profile includes 'address_line1' column")
    assert_test("two_factor_enabled" in prof, "Profile includes 'two_factor_enabled' flag")

    # TEST 2: POST /api/admin/schools/my-profile/update with Structured Address & Guardian Info
    print("\n--- Test 2: Update Profile with Structured Address & Guardian Details ---")
    update_payload = {
        "fullName": "Dr. Universal Tester",
        "phone": "+919876543210",
        "gender": "Male",
        "dateOfBirth": "1990/01/15",
        "bio": "Experienced educator and system validator.",
        "bloodGroup": "O+",
        "nationality": "Indian",
        "addressLine1": "Suite 501, Tech Innovation Park",
        "addressLine2": "Outer Ring Road",
        "city": "Bengaluru",
        "state": "Karnataka",
        "pincode": "560103",
        "country": "India",
        "fatherName": "Jonathan Tester",
        "fatherOccupation": "Senior Scientist",
        "fatherPhone": "+919876543211",
        "motherName": "Martha Tester",
        "motherOccupation": "Architect",
        "motherPhone": "+919876543212",
        "localGuardian": "Arthur Davis",
        "guardianRelationship": "Legal Guardian",
        "guardianPhone": "+919876543213",
        "guardianEmail": "arthur.guardian@edushamiit.com",
        "guardianAddress": "Whitefield, Bengaluru",
        "emergencyContactName": "Robert Davis",
        "emergencyContactRelation": "Uncle",
        "emergencyContactPhone": "+919876543214",
        "qualification": "Ph.D. in Computer Science",
        "experienceYears": "12"
    }
    res = client.post("/api/admin/schools/my-profile/update", json=update_payload)
    assert_test(res.status_code == 200, "Update profile returns HTTP 200")
    assert_test(res.json().get("success") is True, "Profile update response is successful")

    # Verify updated values in database
    res = client.get("/api/admin/schools/my-profile")
    updated_prof = res.json().get("profile", {})
    assert_test(updated_prof.get("full_name") == "Dr. Universal Tester", "Full name updated correctly")
    assert_test(updated_prof.get("address_line1") == "Suite 501, Tech Innovation Park", "Address Line 1 updated correctly")
    assert_test(updated_prof.get("city") == "Bengaluru", "City updated correctly")
    assert_test(updated_prof.get("guardian_relationship") == "Legal Guardian", "Guardian relationship updated")
    assert_test(updated_prof.get("guardian_phone") == "+919876543213", "Guardian phone updated")
    assert_test("Suite 501, Tech Innovation Park, Outer Ring Road, Bengaluru, Karnataka, 560103, India" in (updated_prof.get("address") or ""),
                "Composite address contains all structured fields")

    # TEST 3: Anti-Contamination Verification (Specialization & House Isolation)
    print("\n--- Test 3: Anti-Contamination Verification (Decoupled Language & Address) ---")
    contamination_test_payload = {
        "fullName": "Dr. Universal Tester",
        "preferredLanguage": "German",
        "address": "Random Temporary Address"
        # Notice: specialization and house are NOT sent
    }
    res = client.post("/api/admin/schools/my-profile/update", json=contamination_test_payload)
    assert_test(res.status_code == 200, "Profile update without specialization/house returns 200")
    
    res = client.get("/api/admin/schools/my-profile")
    prof_after = res.json().get("profile", {})
    assert_test(prof_after.get("preferred_language") == "German", "Language updated to German")
    assert_test(prof_after.get("specialization") == "Quantum Computing", 
                "CRITICAL: Teacher specialization preserved as 'Quantum Computing' (NOT overwritten by language)")
    assert_test(prof_after.get("house") == "Alpha Phoenix", 
                "CRITICAL: Academic House preserved as 'Alpha Phoenix' (NOT overwritten by address)")

    # TEST 4: Direct Standalone Preferences Update
    print("\n--- Test 4: Direct Standalone Preferences Update Endpoint ---")
    pref_payload = {
        "emailNotifications": False,
        "smsAlerts": True,
        "pushNotifications": True,
        "weeklyReports": False,
        "preferredTheme": "dark",
        "preferredLanguage": "English (US)",
        "timezone": "(GMT +05:30) Asia/Kolkata"
    }
    res = client.post("/api/admin/schools/my-profile/preferences", json=pref_payload)
    assert_test(res.status_code == 200, "Preferences update returns HTTP 200")
    assert_test(res.json().get("success") is True, "Preferences update response is success")

    res = client.get("/api/admin/schools/my-profile")
    prof_prefs = res.json().get("profile", {})
    assert_test(prof_prefs.get("email_notifications") is False, "Email notifications switch updated to False")
    assert_test(prof_prefs.get("sms_alerts") is True, "SMS alerts switch updated to True")
    assert_test(prof_prefs.get("preferred_theme") == "dark", "Theme preference updated to dark")

    # TEST 5: Real RFC 6238 TOTP Two-Factor Authentication Setup & Verification
    print("\n--- Test 5: TOTP 2FA Setup, Invalid Code Rejection, Valid Code Verification & Disable ---")
    # 5a: Setup
    res = client.post("/api/admin/schools/my-profile/two-factor/setup", json={})
    assert_test(res.status_code == 200, "2FA setup endpoint returns HTTP 200")
    setup_data = res.json()
    secret = setup_data.get("secret")
    otpauth_url = setup_data.get("otpauth_url")
    backup_codes = setup_data.get("backup_codes", [])
    assert_test(bool(secret) and len(secret) == 32, "TOTP secret is valid 32-character base32 string")
    assert_test("otpauth://totp/EduSHAMIIT" in (otpauth_url or ""), "otpauth URL contains EduSHAMIIT issuer")
    assert_test(len(backup_codes) == 8, "Returns 8 emergency recovery backup codes")

    # 5b: Invalid Code Rejection (Edge case)
    res = client.post("/api/admin/schools/my-profile/two-factor/verify", json={
        "secret": secret,
        "code": "000000",
        "backupCodes": backup_codes
    })
    assert_test(res.status_code == 400, "Invalid 2FA code is rejected with HTTP 400")

    # 5c: Valid Code Verification (Positive test)
    valid_code = _generate_totp_code_for_secret(secret)
    res = client.post("/api/admin/schools/my-profile/two-factor/verify", json={
        "secret": secret,
        "code": valid_code,
        "backupCodes": backup_codes
    })
    assert_test(res.status_code == 200, "Valid TOTP code verified successfully with HTTP 200")
    assert_test(res.json().get("success") is True, "2FA enabled response is successful")

    res = client.get("/api/admin/schools/my-profile")
    prof_2fa = res.json().get("profile", {})
    assert_test(prof_2fa.get("two_factor_enabled") is True, "Database confirms two_factor_enabled is True")

    # 5d: Disable 2FA
    res = client.post("/api/admin/schools/my-profile/two-factor/disable", json={"code": valid_code})
    assert_test(res.status_code == 200, "2FA disable endpoint returns HTTP 200")
    res = client.get("/api/admin/schools/my-profile")
    assert_test(res.json().get("profile", {}).get("two_factor_enabled") is False, "Database confirms 2FA disabled")

    # TEST 6: Document Upload, Verification Status & Deletion
    print("\n--- Test 6: Document Management (Standard & Custom Types) ---")
    sb = get_supabase()
    doc_id = str(uuid.uuid4())
    dummy_doc = {
        "id": doc_id,
        "user_id": test_user_id,
        "document_type": "Character Certificate",
        "file_name": "character_certificate_2026.pdf",
        "file_url": "https://storage.edushamiit.com/docs/character_cert.pdf",
        "file_size": 245760,
        "mime_type": "application/pdf",
        "verification_status": "pending",
        "rejection_reason": None
    }
    asyncio.run(sb.table("documents").insert(dummy_doc).aexecute())

    res = client.get("/api/admin/schools/my-profile")
    docs = res.json().get("profile", {}).get("documents", [])
    found_doc = next((d for d in docs if d.get("id") == doc_id), None)
    assert_test(found_doc is not None, "Uploaded document retrieved in profile documents list")
    assert_test(found_doc.get("document_type") == "Character Certificate", "Document type matches")
    assert_test(found_doc.get("file_size") == 245760, "Document file size preserved accurately")

    # Test Document Deletion
    del_res = client.delete(f"/api/admin/schools/my-profile/document/{doc_id}")
    assert_test(del_res.status_code == 200, "Document delete endpoint returns HTTP 200")
    
    res = client.get("/api/admin/schools/my-profile")
    docs_after = res.json().get("profile", {}).get("documents", [])
    assert_test(not any(d.get("id") == doc_id for d in docs_after), "Document verified removed from database")

    # TEST 7: Paginated Activity Logs
    print("\n--- Test 7: Paginated Audit Activity Logs Endpoint ---")
    res = client.get("/api/admin/schools/my-profile/logs?limit=5&offset=0")
    assert_test(res.status_code == 200, "Logs endpoint returns HTTP 200")
    logs_data = res.json()
    assert_test(logs_data.get("success") is True, "Logs response success is True")
    assert_test("logs" in logs_data and isinstance(logs_data["logs"], list), "Logs array is present")

    # TEST 8: Full GDPR Profile Data Export
    print("\n--- Test 8: Full GDPR Profile Data Export Endpoint ---")
    res = client.get("/api/admin/schools/my-profile/export-data")
    assert_test(res.status_code == 200, "Export data returns HTTP 200")
    export_json = res.json()
    assert_test(export_json.get("success") is True, "Export response is successful")
    export_body = export_json.get("data", {})
    assert_test("profile" in export_body, "Export package contains complete user profile")
    assert_test("documents" in export_body, "Export package contains documents archive")
    assert_test("logs" in export_body, "Export package contains activity logs")

    # TEST 9: Active Session Revocation
    print("\n--- Test 9: Active Session Revocation ---")
    test_session_id = str(uuid.uuid4())
    asyncio.run(sb.table("user_active_sessions").insert({
        "id": test_session_id,
        "user_id": test_user_id,
        "token": "sess_test_token_123",
        "device_name": "Edge Browser on Android",
        "browser_name": "Chrome Mobile",
        "ip_address": "192.168.1.100",
        "location": "Bengaluru, IN",
        "expires_at": datetime.utcnow().isoformat()
    }).aexecute())

    revoke_res = client.post("/api/admin/schools/my-profile/revoke-session", json={"sessionId": test_session_id})
    assert_test(revoke_res.status_code == 200, "Session revocation returns HTTP 200")
    
    session_check = asyncio.run(sb.table("user_active_sessions").select("id").eq("id", test_session_id).maybe_single().aexecute())
    assert_test(session_check.data is None, "Revoked session verified removed from database")

    print("\n" + "=" * 70)
    print(f"ALL TESTS COMPLETED: {passed_count}/{total_count} PASSED (100% SUCCESS)")
    print("=" * 70)

if __name__ == "__main__":
    run_all_tests()
