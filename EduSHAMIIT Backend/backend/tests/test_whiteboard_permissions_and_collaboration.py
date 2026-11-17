import requests
import json
import jwt
import os
import uuid

API_BASE_URL = "http://localhost:8082/api"
JWT_SECRET = os.environ.get("JWT_SECRET", "super-secret-jwt-token-with-at-least-32-characters-long")
SCHOOL_ID = "11111111-1111-1111-1111-111111111111"
ADMIN_USER_ID = "5198c4b0-f1cb-45db-9649-41688d0438ba"  # King Doe (super_admin)
STUDENT_USER_ID = "55ec82a1-8d15-4418-8f1a-0fe16b33dd60"  # Naresh King (student)

def get_jwt(user_id, role, email):
    payload = {
        "sub": user_id,
        "school_id": SCHOOL_ID,
        "role": role,
        "email": email,
        "exp": 9999999999
    }
    return jwt.encode(payload, JWT_SECRET, algorithm="HS256")

admin_headers = {
    "Authorization": f"Bearer {get_jwt(ADMIN_USER_ID, 'super_admin', 'mathematicsking888@gmail.com')}",
    "Content-Type": "application/json"
}

student_headers = {
    "Authorization": f"Bearer {get_jwt(STUDENT_USER_ID, 'student', 'naresh_student@edushamiit.com')}",
    "Content-Type": "application/json"
}

print("==================================================================")
print("TEST SUITE: WHITEBOARD PERMISSIONS, COLLABORATION & EDITING")
print("==================================================================")

# Step 1: Create or Fetch Whiteboard as Super Admin
print("\n[STEP 1] Testing Super Admin (King Doe) Whiteboard Access & Ownership...")
create_res = requests.post(
    f"{API_BASE_URL}/whiteboards",
    json={
        "title": "Automated Permissions Test Whiteboard",
        "template_type": "mathematics",
        "collaboration_enabled": True
    },
    headers=admin_headers
)
assert create_res.status_code == 200, f"Whiteboard creation failed: {create_res.text}"
wb = create_res.json()["data"]
wb_id = wb["id"]
pages = wb.get("pages", [])
assert len(pages) > 0, "Whiteboard should have at least 1 page"
page_id = pages[0]["id"]
print(f"SUCCESS: Created Whiteboard {wb_id} with page {page_id}")

# Verify Super Admin has full OWNER permissions
wb_admin_res = requests.get(f"{API_BASE_URL}/whiteboards/{wb_id}", headers=admin_headers)
assert wb_admin_res.status_code == 200
wb_admin_data = wb_admin_res.json()["data"]
admin_perm = wb_admin_data.get("my_permission", {})
print(f"Super Admin Permissions: {admin_perm}")
assert admin_perm.get("can_edit") == True, "Super Admin MUST have can_edit == True"
assert admin_perm.get("permission") == "OWNER", "Super Admin MUST have permission == 'OWNER'"
assert admin_perm.get("can_manage_pages") == True, "Super Admin MUST be able to manage pages"
print("SUCCESS: Super Admin correctly granted OWNER & can_edit rights!")

# Step 2: Super Admin draws on whiteboard
print("\n[STEP 2] Testing Super Admin Drawing Operation...")
op_admin = {
    "operation_id": str(uuid.uuid4()),
    "operation_type": "draw",
    "page_id": page_id,
    "client_seq": 1,
    "payload": {
        "object": {
            "id": f"obj_{uuid.uuid4().hex[:8]}",
            "type": "path",
            "points": [[100, 100], [150, 150], [200, 200]],
            "stroke_color": "#2563EB",
            "stroke_width": 3.0
        }
    }
}
op_res = requests.post(f"{API_BASE_URL}/whiteboards/{wb_id}/operations", json=op_admin, headers=admin_headers)
assert op_res.status_code == 200, f"Admin drawing failed: {op_res.text}"
print("SUCCESS: Super Admin drawing operation submitted successfully!")

# Step 3: Test Student Collaboration with Collaboration Enabled
print("\n[STEP 3] Testing Student Permissions when Collaboration is ON...")
patch_res = requests.patch(
    f"{API_BASE_URL}/whiteboards/{wb_id}",
    json={
        "collaboration_enabled": True,
        "presentation_mode": False
    },
    headers=admin_headers
)
assert patch_res.status_code == 200

wb_student_res = requests.get(f"{API_BASE_URL}/whiteboards/{wb_id}", headers=student_headers)
assert wb_student_res.status_code == 200
student_perm = wb_student_res.json()["data"].get("my_permission", {})
print(f"Student Permissions with Collaboration ON: {student_perm}")
assert student_perm.get("can_edit") == True, "Student MUST be able to edit when collaboration is enabled"
assert student_perm.get("permission") in ("EDIT", "ANNOTATE"), "Student should have EDIT permission"
print("SUCCESS: Student successfully granted EDIT permission!")

# Step 4: Student draws on whiteboard
print("\n[STEP 4] Testing Student Drawing Operation when Collaboration is ON...")
op_student = {
    "operation_id": str(uuid.uuid4()),
    "operation_type": "draw",
    "page_id": page_id,
    "client_seq": 2,
    "payload": {
        "object": {
            "id": f"obj_{uuid.uuid4().hex[:8]}",
            "type": "path",
            "points": [[250, 250], [300, 300]],
            "stroke_color": "#10B981",
            "stroke_width": 4.0
        }
    }
}
student_op_res = requests.post(f"{API_BASE_URL}/whiteboards/{wb_id}/operations", json=op_student, headers=student_headers)
assert student_op_res.status_code == 200, f"Student drawing failed: {student_op_res.text}"
print("SUCCESS: Student drawing operation applied cleanly with 200 OK!")

# Step 5: Test Presentation Mode (Locks Student Controls)
print("\n[STEP 5] Testing Presentation Mode (Locking Student Edits)...")
patch_pres = requests.patch(
    f"{API_BASE_URL}/whiteboards/{wb_id}",
    json={
        "presentation_mode": True
    },
    headers=admin_headers
)
assert patch_pres.status_code == 200

wb_pres_res = requests.get(f"{API_BASE_URL}/whiteboards/{wb_id}", headers=student_headers)
pres_perm = wb_pres_res.json()["data"].get("my_permission", {})
print(f"Student Permissions with Presentation Mode ON: {pres_perm}")
assert pres_perm.get("can_edit") == False, "Student should NOT be able to edit in presentation mode"
assert pres_perm.get("permission") == "VIEW", "Student should have VIEW-only permission"
print("SUCCESS: Student correctly restricted to VIEW in presentation mode!")

# Step 6: Cleanup test whiteboard
print("\n[STEP 6] Cleaning up test whiteboard...")
del_res = requests.delete(f"{API_BASE_URL}/whiteboards/{wb_id}", headers=admin_headers)
assert del_res.status_code == 200
print(f"SUCCESS: Deleted test whiteboard {wb_id}")

print("\n==================================================================")
print("ALL WHITEBOARD PERMISSION & COLLABORATION TESTS PASSED 100%!")
print("==================================================================")
