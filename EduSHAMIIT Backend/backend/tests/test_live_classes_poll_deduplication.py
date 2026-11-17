import requests
import json
import jwt
import os
import concurrent.futures
import time

API_BASE_URL = "http://localhost:8082/api"
JWT_SECRET = os.environ.get("JWT_SECRET", "super-secret-jwt-token-with-at-least-32-characters-long")
SCHOOL_ID = "11111111-1111-1111-1111-111111111111"
ADMIN_USER_ID = "5198c4b0-f1cb-45db-9649-41688d0438ba"  # King Doe

def get_jwt(user_id=ADMIN_USER_ID, role="super_admin", email="mathematicsking888@gmail.com"):
    payload = {
        "sub": user_id,
        "school_id": SCHOOL_ID,
        "role": role,
        "email": email,
        "exp": 9999999999
    }
    return jwt.encode(payload, JWT_SECRET, algorithm="HS256")

token = get_jwt()
headers = {
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/json"
}

print("==================================================================")
print("TEST SUITE: LIVE CLASS POLL MULTI-CLICK & DEDUPLICATION DEFENSE")
print("==================================================================")

# Step 1: Create a test live class session with valid dynamic metadata
print("\n[STEP 1] Creating a dedicated live class session...")
meta_res = requests.get(f"{API_BASE_URL}/live-classes/meta/dropdowns", headers=headers)
assert meta_res.status_code == 200, f"Dropdowns failed: {meta_res.text}"
meta_data = meta_res.json().get("data", {})
target_class = meta_data.get("classes", [])[0]
target_section = meta_data.get("sections", [])[0]
target_subject = meta_data.get("subjects", [])[0]

create_res = requests.post(
    f"{API_BASE_URL}/live-classes/sessions/instant",
    json={
        "title": "Poll Multi-Click Defense Verification Session",
        "description": "Verifying multi-click debouncing and zero duplicate polls",
        "duration_minutes": 45,
        "class_id": target_class["id"],
        "section_id": target_section["id"],
        "subject_id": target_subject["id"],
    },
    headers=headers
)
assert create_res.status_code == 200, f"Failed to create session: {create_res.text}"
session = create_res.json()["data"]
session_id = session.get("id") or session.get("session_id")
print(f"SUCCESS: Created session {session_id}")

# Step 2: Simulate multi-clicking "Launch Poll Now" (5 concurrent rapid requests)
print("\n[STEP 2] Simulating rapid multi-clicks on 'Launch Poll Now' (5 parallel requests)...")
poll_payload = {
    "title": "Calculus Concept Check",
    "question": "What is the derivative of e^(2x)?",
    "options": [
        {"id": "opt_1", "text": "2e^(2x)"},
        {"id": "opt_2", "text": "e^(2x)"},
        {"id": "opt_3", "text": "e^(x)"},
        {"id": "opt_4", "text": "0"}
    ]
}

def send_poll_request(req_id):
    res = requests.post(
        f"{API_BASE_URL}/live-classes/sessions/{session_id}/polls",
        json=poll_payload,
        headers=headers
    )
    return req_id, res.status_code, res.json()

results = []
with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
    futures = [executor.submit(send_poll_request, i) for i in range(5)]
    for f in concurrent.futures.as_completed(futures):
        results.append(f.result())

poll_ids = set()
suppressed_count = 0
for req_id, status, body in results:
    assert status == 200, f"Request {req_id} failed: {body}"
    data = body.get("data", {})
    p_id = data.get("id")
    is_suppressed = data.get("is_duplicate_suppressed", False)
    if is_suppressed:
        suppressed_count += 1
    poll_ids.add(p_id)
    print(f"Request #{req_id} -> HTTP {status}, Poll ID: {p_id}, Duplicate Suppressed: {is_suppressed}")

print(f"\nResults across 5 parallel rapid clicks:")
print(f"- Unique Poll IDs returned: {len(poll_ids)} (IDs: {list(poll_ids)})")
print(f"- Suppressed duplicate requests: {suppressed_count}")
assert len(poll_ids) == 1, f"ERROR: More than 1 unique poll was returned! {poll_ids}"
assert suppressed_count >= 1, f"ERROR: Expected at least 1 suppressed duplicate, got {suppressed_count}"
print("SUCCESS: All 5 rapid requests resolved to the EXACT same single poll ID!")

# Step 3: Check conduct session state
print("\n[STEP 3] Verifying conduct session data from API...")
conduct_res = requests.get(f"{API_BASE_URL}/live-classes/sessions/{session_id}/conduct", headers=headers)
assert conduct_res.status_code == 200
conduct_data = conduct_res.json()["data"]

active_poll = conduct_data.get("active_poll")
poll_history = conduct_data.get("poll_history", [])

assert active_poll is not None, "Active poll should exist"
assert active_poll["question"] == poll_payload["question"]
print(f"SUCCESS: Active poll is '{active_poll['question']}' (ID: {active_poll['id']})")

# Verify poll history doesn't have duplicate closed polls
matching_polls = [p for p in poll_history if p["question"] == poll_payload["question"]]
print(f"Total polls in history matching question: {len(matching_polls)}")
assert len(matching_polls) == 1, f"ERROR: Duplicate polls found in history! {len(matching_polls)} matching polls"
print("SUCCESS: Zero duplicate polls found in conduct session data!")

# Step 4: Cleanup test session
print("\n[STEP 4] Cleaning up test session...")
del_res = requests.delete(f"{API_BASE_URL}/live-classes/sessions/{session_id}", headers=headers)
assert del_res.status_code == 200
print(f"SUCCESS: Deleted test session {session_id}")

print("\n==================================================================")
print("ALL MULTI-CLICK & DEDUPLICATION DEFENSE TESTS PASSED 100%!")
print("==================================================================")
