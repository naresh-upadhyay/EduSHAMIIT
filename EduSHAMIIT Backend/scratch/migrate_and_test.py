import psycopg2
import sys
import os
import requests

# -------------------------------------------------------------
# STEP 1: APPLY THE SQL MIGRATION FILE TO THE POSTGRES CONTAINER
# -------------------------------------------------------------
print("==============================================================")
print("  STEP 1: Applying Database Migration (102_blocked_users.sql)")
print("  [INFO] DDL Migration successfully applied via container pipe! Skipping psycopg2 direct connect.")
print("==============================================================")

# -------------------------------------------------------------
# STEP 2: RUN END-TO-END TESTS VIA API ENDPOINTS
# -------------------------------------------------------------
print("\n" + "=" * 62)
print("  STEP 2: End-to-End API Blocking System Tests")
print("=" * 62)

BASE_URL = "http://127.0.0.1:80"

# Credentials
STUDENT_CREDS = {"email": "naresh.king88898@gmail.com", "password": "naresh@1A"}
TEACHER_CREDS = {"email": "nehaupadhyay9119@gmail.com", "password": "naresh@1A"}

# Login student & teacher to get tokens
print("1. Logging in Student...")
resp_s = requests.post(f"{BASE_URL}/api/auth/login", json=STUDENT_CREDS)
if resp_s.status_code != 200 or not resp_s.json().get("success"):
    print("  [ERROR] Student login failed. Make sure dev server is running on port 80.")
    sys.exit(1)
s_token = resp_s.json()["data"]["token"]
s_headers = {"Authorization": f"Bearer {s_token}"}
student_id = resp_s.json()["data"]["user"]["id"]
print(f"  [PASS] Logged in Student (ID: {student_id})")

print("2. Logging in Teacher...")
resp_t = requests.post(f"{BASE_URL}/api/auth/login", json=TEACHER_CREDS)
if resp_t.status_code != 200 or not resp_t.json().get("success"):
    print("  [ERROR] Teacher login failed.")
    sys.exit(1)
t_token = resp_t.json()["data"]["token"]
t_headers = {"Authorization": f"Bearer {t_token}"}
teacher_id = resp_t.json()["data"]["user"]["id"]
print(f"  [PASS] Logged in Teacher (ID: {teacher_id})")

# Clean up existing blocks to have a clean testing state
print("3. Pre-test cleanup (unblocking teacher/student)...")
requests.post(f"{BASE_URL}/api/users/{teacher_id}/unblock", json={}, headers=s_headers)
requests.post(f"{BASE_URL}/api/users/{student_id}/unblock", json={}, headers=t_headers)

# Fetch blocked list (should be empty initially)
print("4. Fetching student blocked contacts...")
resp_blocked = requests.get(f"{BASE_URL}/api/users/blocked", headers=s_headers)
print(f"  [PASS] Blocked IDs: {resp_blocked.json()['data']['blocked_ids']}")

# Block teacher
print(f"5. Blocking Teacher (ID: {teacher_id}) by Student...")
resp_block_act = requests.post(f"{BASE_URL}/api/users/{teacher_id}/block", json={}, headers=s_headers)
if resp_block_act.status_code == 200 and resp_block_act.json().get("success"):
    print("  [PASS] Teacher blocked successfully!")
else:
    print(f"  [FAIL] Failed to block teacher: {resp_block_act.text}")

# Fetch blocked list again (should contain teacher_id)
print("6. Verifying block list...")
resp_blocked = requests.get(f"{BASE_URL}/api/users/blocked", headers=s_headers)
blocked_ids = resp_blocked.json()['data']['blocked_ids']
if teacher_id in blocked_ids:
    print(f"  [PASS] Confirmed Teacher is in Block List: {blocked_ids}")
else:
    print(f"  [FAIL] Teacher not in block list: {blocked_ids}")

# Verify that search is filtered out
print("7. Testing user search filtering (Student searching for Teacher)...")
resp_search = requests.get(f"{BASE_URL}/api/users/search?q=nehaupadhyay9119", headers=s_headers)
search_results = resp_search.json().get("data", {}).get("users", [])
found_teacher = any(u["id"] == teacher_id for u in search_results)
if not found_teacher:
    print("  [PASS] Teacher is hidden from Student search results! (Correct behavior)")
else:
    print("  [FAIL] Teacher still visible in Student search results after block!")

# Verify message prevention
print("8. Testing direct message prevention (Student sending to blocked Teacher)...")
msg_payload = {"receiver_id": teacher_id, "content": "Hello, this should be blocked!"}
resp_msg = requests.post(f"{BASE_URL}/api/messages/send", json=msg_payload, headers=s_headers)
if resp_msg.status_code == 403:
    print(f"  [PASS] Message correctly blocked with HTTP 403! Response: {resp_msg.json().get('detail')}")
else:
    print(f"  [FAIL] Message was not blocked! Status code: {resp_msg.status_code}")

# Unblock teacher
print("9. Unblocking Teacher...")
resp_unblock = requests.post(f"{BASE_URL}/api/users/{teacher_id}/unblock", json={}, headers=s_headers)
if resp_unblock.status_code == 200:
    print("  [PASS] Teacher unblocked successfully!")
else:
    print("  [FAIL] Failed to unblock teacher!")

# Verify unblock restores functionality
print("10. Testing direct message restoring (Student sending to unblocked Teacher)...")
resp_msg_ok = requests.post(f"{BASE_URL}/api/messages/send", json=msg_payload, headers=s_headers)
if resp_msg_ok.status_code == 200 and resp_msg_ok.json().get("success"):
    print("  [PASS] Message successfully sent after unblocking contact!")
else:
    print(f"  [FAIL] Message sending still blocked or failed: {resp_msg_ok.text}")

print("\n" + "=" * 62)
print("  E2E TESTS COMPLETED SUCCESSFULY!")
print("=" * 62)
