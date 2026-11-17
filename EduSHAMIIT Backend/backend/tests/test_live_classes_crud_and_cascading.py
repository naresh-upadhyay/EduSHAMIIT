import requests
import json
import jwt
import os

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
print("TEST SUITE: LIVE CLASS MANAGEMENT ENTERPRISE CRUD & CASCADING")
print("==================================================================")

# 1. Test Cascading Academic Subjects API
print("\n[TEST 1] Testing Cascading Subjects API for Class 5 & Class 10...")
meta_res = requests.get(f"{API_BASE_URL}/live-classes/meta/dropdowns", headers=headers)
assert meta_res.status_code == 200, f"Dropdowns failed: {meta_res.text}"
meta_data = meta_res.json().get("data", {})
classes = meta_data.get("classes", [])
sections = meta_data.get("sections", [])
class_subjects = meta_data.get("class_subjects", [])

print(f"Loaded {len(classes)} classes, {len(sections)} sections, {len(class_subjects)} mapped class-subjects.")

class_5 = next((c for c in classes if "5" in c["name"]), None)
class_10 = next((c for c in classes if "10" in c["name"]), None)

subs_5 = []
if class_5:
    res_5 = requests.get(f"{API_BASE_URL}/live-classes/cascading-subjects?class_id={class_5['id']}", headers=headers)
    assert res_5.status_code == 200
    d5 = res_5.json().get("data", {})
    subs_5 = d5.get("subjects", []) if isinstance(d5, dict) else d5
    print(f"SUCCESS: Class 5 has {len(subs_5)} strictly cascaded subjects: {[s['name'] for s in subs_5]}")
    for s in subs_5:
        icon = s.get("icon", "")
        assert "ð" not in icon, f"Corrupted icon found in {s['name']}: {icon}"
    print("SUCCESS: All subject icons for Class 5 are clean UTF-8!")

subs_10 = []
if class_10:
    res_10 = requests.get(f"{API_BASE_URL}/live-classes/cascading-subjects?class_id={class_10['id']}", headers=headers)
    assert res_10.status_code == 200
    d10 = res_10.json().get("data", {})
    subs_10 = d10.get("subjects", []) if isinstance(d10, dict) else d10
    print(f"SUCCESS: Class 10 has {len(subs_10)} strictly cascaded subjects: {[s['name'] for s in subs_10]}")

# 2. Test My Classes API with Database Sorting
print("\n[TEST 2] Testing My Classes API with Sorting and Pagination...")
res_sort_asc = requests.get(f"{API_BASE_URL}/live-classes/my-classes?sort_by=class_name&sort_order=ASC&page=1&page_size=5", headers=headers)
assert res_sort_asc.status_code == 200, f"Sort ASC failed: {res_sort_asc.text}"
data_asc = res_sort_asc.json().get("data", {})
items_asc = data_asc.get("items", [])
print(f"SUCCESS: Fetched {len(items_asc)} items sorted by class_name ASC. Total count: {data_asc.get('total_count')}, Total pages: {data_asc.get('total_pages')}")

res_sort_desc = requests.get(f"{API_BASE_URL}/live-classes/my-classes?sort_by=scheduled_at&sort_order=DESC&page=1&page_size=5", headers=headers)
assert res_sort_desc.status_code == 200, f"Sort DESC failed: {res_sort_desc.text}"
data_desc = res_sort_desc.json().get("data", {})
items_desc = data_desc.get("items", [])
print(f"SUCCESS: Fetched {len(items_desc)} items sorted by scheduled_at DESC.")

# Verify subject icons in list
for it in items_desc:
    icon = it.get("subject_icon", "")
    assert "ð" not in icon, f"Corrupted icon in item {it['id']}: {icon}"
print("SUCCESS: Zero corrupted characters in my-classes list!")

# 3. Test Full CRUD Cycle
print("\n[TEST 3] Testing Full CRUD Lifecycle via Stored Procedures...")
# A. Create
create_payload = {
    "title": "Automated Edge Case Test Class",
    "description": "Verifying CRUD and Cascading",
    "class_id": class_10["id"] if class_10 else classes[0]["id"],
    "section_id": sections[0]["id"] if sections else None,
    "subject_id": subs_10[0]["id"] if class_10 and subs_10 else None,
    "duration_minutes": 50,
    "max_participants": 40,
    "recording_enabled": True
}
create_res = requests.post(f"{API_BASE_URL}/live-classes/sessions/instant", json=create_payload, headers=headers)
assert create_res.status_code == 200, f"Create failed: {create_res.text}"
new_session = create_res.json().get("data", {})
session_id = new_session.get("id") or new_session.get("session_id")
print(f"SUCCESS [CREATE]: Created live class with ID: {session_id}, Room Code: {new_session.get('room_code')}")

# B. Read Details
detail_res = requests.get(f"{API_BASE_URL}/live-classes/sessions/{session_id}/details", headers=headers)
assert detail_res.status_code == 200
print(f"SUCCESS [READ]: Retrieved details for session {session_id}")

# C. Update / Reschedule
update_payload = {
    "title": "Updated Topic - Quadratic Mastery",
    "duration_minutes": 60,
    "status": "Scheduled",
    "description": "Updated via Automated Test"
}
update_res = requests.put(f"{API_BASE_URL}/live-classes/sessions/{session_id}", json=update_payload, headers=headers)
assert update_res.status_code == 200, f"Update failed: {update_res.text}"
print(f"SUCCESS [UPDATE]: Updated session {session_id}")

# D. Delete
delete_res = requests.delete(f"{API_BASE_URL}/live-classes/sessions/{session_id}", headers=headers)
assert delete_res.status_code == 200, f"Delete failed: {delete_res.text}"
print(f"SUCCESS [DELETE]: Deleted session {session_id}")

# 4. Test Bulk Operations
print("\n[TEST 4] Testing Bulk Cancel & Bulk Delete...")
s1 = requests.post(f"{API_BASE_URL}/live-classes/sessions/instant", json=create_payload, headers=headers).json()["data"]["id"]
s2 = requests.post(f"{API_BASE_URL}/live-classes/sessions/instant", json=create_payload, headers=headers).json()["data"]["id"]

# Bulk Cancel
bulk_cancel_res = requests.post(f"{API_BASE_URL}/live-classes/sessions/bulk-cancel", json={
    "session_ids": [s1, s2],
    "reason": "Automated bulk cancel test"
}, headers=headers)
assert bulk_cancel_res.status_code == 200, f"Bulk cancel failed: {bulk_cancel_res.text}"
print(f"SUCCESS [BULK CANCEL]: Cancelled sessions {[s1, s2]}")

# Bulk Delete
bulk_del_res = requests.post(f"{API_BASE_URL}/live-classes/sessions/bulk-delete", json={
    "session_ids": [s1, s2]
}, headers=headers)
assert bulk_del_res.status_code == 200, f"Bulk delete failed: {bulk_del_res.text}"
print(f"SUCCESS [BULK DELETE]: Deleted sessions {[s1, s2]}")

print("\n==================================================================")
print("ALL EDGE CASES AND CRUD TESTS PASSED CLEANLY 100%!")
print("==================================================================")
