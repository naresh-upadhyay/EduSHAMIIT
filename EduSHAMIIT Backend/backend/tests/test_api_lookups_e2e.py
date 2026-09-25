"""
Comprehensive API-Level End-to-End HTTP Test Script for Lookup Management
Authenticates with JWT and tests all 16 endpoints against the live FastAPI backend container.
"""
import sys
import os
import requests
import json
import uuid
import psycopg2
from psycopg2.extras import RealDictCursor
from jose import jwt

# Database and API base configuration
DATABASE_URL = os.environ.get("DATABASE_URL", "postgresql://postgres:postgres@supabase-db:5432/postgres")
API_BASE_URL = os.environ.get("API_BASE_URL", "http://localhost:8000")
JWT_SECRET = os.environ.get("JWT_SECRET", "super-secret-jwt-token-key-for-edushamiit-backend-auth")

def get_db():
    return psycopg2.connect(DATABASE_URL)

def get_test_token(user_id: str, school_id: str, role: str = "super_admin", email: str = "superadmin@school.com"):
    payload = {
        "sub": user_id,
        "school_id": school_id,
        "role": role,
        "email": email,
        "exp": 9999999999
    }
    return jwt.encode(payload, JWT_SECRET, algorithm="HS256")

passed = 0
failed = 0

def log_test(name: str, success: bool, detail: str = ""):
    global passed, failed
    if success:
        passed += 1
        print(f"  ✅ [PASS] {name} {detail}")
    else:
        failed += 1
        print(f"  ❌ [FAIL] {name} - {detail}")


def run_e2e_tests():
    global passed, failed
    print("\n" + "=" * 70)
    print("🌐 RUNNING FULL E2E HTTP API TEST SUITE (FASTAPI CONTAINER)")
    print("=" * 70)

    # 1. Obtain Real User Context (King Doe / School 11111111-1111-1111-1111-111111111111)
    school_id = "11111111-1111-1111-1111-111111111111"
    user_id = "38a93170-997b-4b4c-bc8e-256b93169c23" # King Doe
    token = get_test_token(user_id, school_id, "super_admin", "mathematicsking888@gmail.com")

    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }

    test_key_id = None
    test_val_id = None

    try:
        # --------------------------------------------------------------------
        # TEST 1: GET /api/lookups (List pre-seeded keys)
        # --------------------------------------------------------------------
        res = requests.get(f"{API_BASE_URL}/api/lookups", headers=headers)
        data = res.json()
        log_test(
            "GET /api/lookups (List Keys)",
            res.status_code == 200 and data.get("success") == True and len(data.get("data", [])) >= 10,
            f"Total Keys: {data.get('total_records')}"
        )

        # --------------------------------------------------------------------
        # TEST 2: POST /api/lookups (Create new Custom Key with initial values)
        # --------------------------------------------------------------------
        unique_suffix = str(uuid.uuid4())[:6]
        create_payload = {
            "key_name": f"Extracurricular Clubs {unique_suffix}",
            "key_code": f"CLUBS_{unique_suffix.upper()}",
            "description": "Student clubs and technical societies",
            "key_type": "CUSTOM",
            "icon": "people_outline_rounded",
            "status": "ACTIVE",
            "initial_values": [
                {"value_name": "Robotics Club", "value_code": "ROBOTICS", "status": "ACTIVE", "sort_order": 1},
                {"value_name": "Coding Club", "value_code": "CODING", "status": "ACTIVE", "sort_order": 2}
            ]
        }
        res = requests.post(f"{API_BASE_URL}/api/lookups", headers=headers, json=create_payload)
        data = res.json()
        test_key_id = data.get("data", {}).get("id")
        log_test(
            "POST /api/lookups (Create Key + Initial Values)",
            res.status_code == 200 and data.get("success") == True,
            f"Created Key ID: {test_key_id}"
        )

        # --------------------------------------------------------------------
        # TEST 3: Duplicate Key Code Rejection (409 Conflict)
        # --------------------------------------------------------------------
        res_dup = requests.post(f"{API_BASE_URL}/api/lookups", headers=headers, json=create_payload)
        log_test(
            "POST /api/lookups (Duplicate Code Rejected with 409)",
            res_dup.status_code == 409,
            f"Status: {res_dup.status_code}"
        )

        # --------------------------------------------------------------------
        # TEST 4: GET /api/lookups/{id} (Key Detail, Stats, & Usage)
        # --------------------------------------------------------------------
        res = requests.get(f"{API_BASE_URL}/api/lookups/{test_key_id}", headers=headers)
        data = res.json()
        log_test(
            "GET /api/lookups/{id} (Key Detail & Stats)",
            res.status_code == 200 and data.get("success") == True and data.get("data", {}).get("key_code") == f"CLUBS_{unique_suffix.upper()}"
        )

        # --------------------------------------------------------------------
        # TEST 5: PATCH /api/lookups/{id} (Update Key Metadata & Version Lock)
        # --------------------------------------------------------------------
        update_payload = {
            "key_name": f"Student Societies {unique_suffix}",
            "description": "Updated description for clubs",
            "version": 1
        }
        res = requests.patch(f"{API_BASE_URL}/api/lookups/{test_key_id}", headers=headers, json=update_payload)
        data = res.json()
        log_test(
            "PATCH /api/lookups/{id} (Update Key Display Name)",
            res.status_code == 200 and data.get("success") == True
        )

        # --------------------------------------------------------------------
        # TEST 6: GET /api/lookups/{id}/values (List Values)
        # --------------------------------------------------------------------
        res = requests.get(f"{API_BASE_URL}/api/lookups/{test_key_id}/values", headers=headers)
        data = res.json()
        val_list = data.get("data", [])
        test_val_id = val_list[0]["id"] if val_list else None
        log_test(
            "GET /api/lookups/{id}/values (List Values)",
            res.status_code == 200 and len(val_list) == 2,
            f"Values Count: {len(val_list)}"
        )

        # --------------------------------------------------------------------
        # TEST 7: POST /api/lookups/{id}/values (Add Single Value)
        # --------------------------------------------------------------------
        val_payload = {
            "value_name": "Astronomy Club",
            "value_code": "ASTRONOMY",
            "description": "Stargazing and astrophysics",
            "sort_order": 3
        }
        res = requests.post(f"{API_BASE_URL}/api/lookups/{test_key_id}/values", headers=headers, json=val_payload)
        data = res.json()
        added_val_id = data.get("data", {}).get("id")
        log_test(
            "POST /api/lookups/{id}/values (Add Single Value)",
            res.status_code == 200 and data.get("success") == True,
            f"Value ID: {added_val_id}"
        )

        # --------------------------------------------------------------------
        # TEST 8: POST /api/lookups/{id}/values/bulk (Bulk Add Values)
        # --------------------------------------------------------------------
        bulk_payload = {
            "values": [
                {"value_name": "Debating Society", "value_code": "DEBATE", "sort_order": 4},
                {"value_name": "Drama Club", "value_code": "DRAMA", "sort_order": 5}
            ]
        }
        res = requests.post(f"{API_BASE_URL}/api/lookups/{test_key_id}/values/bulk", headers=headers, json=bulk_payload)
        data = res.json()
        log_test(
            "POST /api/lookups/{id}/values/bulk (Bulk Add 2 Values)",
            res.status_code == 200 and data.get("success") == True,
            f"Imported: {data.get('data', {}).get('imported_count')}"
        )

        # --------------------------------------------------------------------
        # TEST 9: PATCH /api/lookups/{id}/values/{val_id} (Update Single Value)
        # --------------------------------------------------------------------
        edit_val_payload = {
            "value_name": "Robotics & AI Club",
            "description": "Advanced robotics laboratory"
        }
        res = requests.patch(f"{API_BASE_URL}/api/lookups/{test_key_id}/values/{test_val_id}", headers=headers, json=edit_val_payload)
        log_test(
            "PATCH /api/lookups/{id}/values/{val_id} (Update Value Name)",
            res.status_code == 200
        )

        # --------------------------------------------------------------------
        # TEST 10: PATCH /api/lookups/{id}/values/reorder (Reorder Sequence)
        # --------------------------------------------------------------------
        reorder_payload = {
            "ordered_value_ids": [added_val_id, test_val_id]
        }
        res = requests.patch(f"{API_BASE_URL}/api/lookups/{test_key_id}/values/reorder", headers=headers, json=reorder_payload)
        log_test(
            "PATCH /api/lookups/{id}/values/reorder (Reorder Sort Sequence)",
            res.status_code == 200,
            f"Status: {res.status_code}, Res: {res.text}"
        )

        # --------------------------------------------------------------------
        # TEST 11: GET /api/lookups/code/{key_code} (Generic Module Resolver)
        # --------------------------------------------------------------------
        res = requests.get(f"{API_BASE_URL}/api/lookups/code/CLUBS_{unique_suffix.upper()}", headers=headers)
        data = res.json()
        resolved_codes = [v["code"] for v in data.get("values", [])]
        log_test(
            "GET /api/lookups/code/{key_code} (Module Resolution)",
            res.status_code == 200 and "ASTRONOMY" in resolved_codes and "CODING" in resolved_codes,
            f"Resolved codes: {resolved_codes}"
        )

        # --------------------------------------------------------------------
        # TEST 12: GET /api/lookups/{id}/export (Export Key to CSV)
        # --------------------------------------------------------------------
        res = requests.get(f"{API_BASE_URL}/api/lookups/{test_key_id}/export", headers=headers)
        log_test(
            "GET /api/lookups/{id}/export (Export Key CSV)",
            res.status_code == 200 and "value_name,value_code" in res.text
        )

        # --------------------------------------------------------------------
        # TEST 13: GET /api/lookups/export/all (Export All CSV)
        # --------------------------------------------------------------------
        res = requests.get(f"{API_BASE_URL}/api/lookups/export/all", headers=headers)
        log_test(
            "GET /api/lookups/export/all (Export All CSV)",
            res.status_code == 200 and "key_name,key_code" in res.text
        )

        # --------------------------------------------------------------------
        # TEST 14: POST /api/lookups/{id}/import (Import CSV String)
        # --------------------------------------------------------------------
        csv_str = "value_name,value_code,status,sort_order,description\nChess Club,CHESS,ACTIVE,6,Mind sports\nMusic Club,MUSIC,ACTIVE,7,Band and orchestra"
        res = requests.post(f"{API_BASE_URL}/api/lookups/{test_key_id}/import", headers=headers, json={"csv_content": csv_str})
        data = res.json()
        log_test(
            "POST /api/lookups/{id}/import (Import CSV Content)",
            res.status_code == 200 and data.get("data", {}).get("imported_count") == 2
        )

        # --------------------------------------------------------------------
        # TEST 15: GET /api/lookups/{id}/audit-logs (Audit Trail Logs)
        # --------------------------------------------------------------------
        res = requests.get(f"{API_BASE_URL}/api/lookups/{test_key_id}/audit-logs", headers=headers)
        data = res.json()
        logs = data.get("data", [])
        log_test(
            "GET /api/lookups/{id}/audit-logs (Audit Trail)",
            res.status_code == 200 and len(logs) >= 5,
            f"Logged Events: {len(logs)}"
        )

        # --------------------------------------------------------------------
        # TEST 16: DELETE /api/lookups/{id}/values/{val_id} (Delete Single Value)
        # --------------------------------------------------------------------
        res = requests.delete(f"{API_BASE_URL}/api/lookups/{test_key_id}/values/{added_val_id}", headers=headers)
        log_test(
            "DELETE /api/lookups/{id}/values/{val_id} (Delete Value)",
            res.status_code == 200
        )

        # --------------------------------------------------------------------
        # TEST 17: DELETE /api/lookups/{id} (Delete Key)
        # --------------------------------------------------------------------
        res = requests.delete(f"{API_BASE_URL}/api/lookups/{test_key_id}", headers=headers)
        log_test(
            "DELETE /api/lookups/{id} (Delete Key)",
            res.status_code == 200
        )

    finally:
        # Cleanup any remaining test artifacts
        if test_key_id:
            conn = get_db()
            with conn.cursor() as cur:
                cur.execute("DELETE FROM public.audit_logs WHERE (changes->>'lookup_key_id') = %s;", (str(test_key_id),))
                cur.execute("DELETE FROM public.lookup_values WHERE lookup_key_id = %s;", (test_key_id,))
                cur.execute("DELETE FROM public.lookup_keys WHERE id = %s;", (test_key_id,))
            conn.commit()
            conn.close()

    print("\n" + "=" * 70)
    total = passed + failed
    print(f"📊 HTTP API RESULTS: {passed} PASSED | {failed} FAILED (Total: {total})")
    print(f"🎯 SUCCESS RATE: {(passed / total * 100.0) if total > 0 else 0:.1f}%")
    print("=" * 70 + "\n")

    if failed > 0:
        sys.exit(1)


if __name__ == "__main__":
    run_e2e_tests()
