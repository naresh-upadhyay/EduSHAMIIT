import sys
import os
import uuid
import httpx

BASE_URL = "http://127.0.0.1:80"
client = httpx.Client(base_url=BASE_URL, timeout=30.0)

def register_and_login(name, role, class_name=None):
    """Helper to create a user and get their token and user info"""
    email = f"test_{role}_{uuid.uuid4().hex[:6]}@example.com"
    data = {
        "email": email,
        "password": "Password123!",
        "full_name": name,
        "role": role,
        "school_id": "11111111-1111-1111-1111-111111111111",
        "class_name": class_name
    }
    
    # Register
    res = client.post("/api/auth/register", json=data)
    if res.status_code != 200:
        print(f"Failed to register user {name}: {res.text}")
        return None
        
    # Login
    res = client.post("/api/auth/login", json={"email": email, "password": "Password123!", "role": role})
    if res.status_code == 200:
        login_data = res.json().get("data", {})
        token = login_data.get("token")
        user_info = login_data.get("user", {})
        return {"token": token, "user": user_info}
    else:
        print(f"Failed to login {name}: {res.text}")
        return None

def run_tests():
    print("="*60)
    print("STARTING GROUPS PRIVACY AND ADMIN ACTIONS INTEGRATION TESTS")
    print("="*60)
    
    # 1. Create test users
    # Student A & B are classmates (Class 10A)
    # Student C is in Class 10B
    # Teacher A is a teacher
    user_a = register_and_login("Student A", "student", "10A")
    user_b = register_and_login("Student B", "student", "10A")
    user_c = register_and_login("Student C", "student", "10B")
    teacher_a = register_and_login("Teacher A", "teacher")
    
    if not all([user_a, user_b, user_c, teacher_a]):
        print("Failed to create test users. Exiting.")
        sys.exit(1)
        
    headers_a = {"Authorization": f"Bearer {user_a['token']}"}
    headers_b = {"Authorization": f"Bearer {user_b['token']}"}
    headers_c = {"Authorization": f"Bearer {user_c['token']}"}
    headers_teacher = {"Authorization": f"Bearer {teacher_a['token']}"}
    
    id_a = user_a['user']['id']
    id_b = user_b['user']['id']
    id_c = user_c['user']['id']
    id_teacher = teacher_a['user']['id']
    
    print("Test users registered successfully.")
    
    # ── Test 1: Create Private Group as Student (Only Creator + Selected Members) ──
    print("\n[Test 1] Student A creating private group with Student B...")
    group_payload = {
        "name": "Secret Physics Revision",
        "description": "Private physics study session",
        "group_level": "class",
        "is_private": True
    }
    
    # Create group
    res = client.post("/api/student/groups/create", json=group_payload, headers=headers_a)
    assert res.status_code == 200, f"Failed group creation: {res.text}"
    group = res.json().get("data", {}).get("group")
    group_id = group["id"]
    print(f"Group created successfully with ID: {group_id}")
    
    # Add Student B
    res = client.post(f"/api/groups/{group_id}/members", json={"member_id": id_b}, headers=headers_a)
    assert res.status_code == 200, f"Failed to add member B: {res.text}"
    
    # Retrieve group members
    res = client.get(f"/api/groups/{group_id}/members", headers=headers_a)
    assert res.status_code == 200
    members = res.json().get("data", {}).get("members", [])
    member_ids = {m["id"] for m in members}
    print(f"Members in group: {[m['full_name'] for m in members]}")
    
    # Verify creator (Student A) and Student B are the only ones in the group.
    # No auto-population of all classmates (e.g. 22 members)
    assert id_a in member_ids
    assert id_b in member_ids
    assert len(member_ids) == 2, f"Expected exactly 2 members, but got {len(member_ids)}"
    print("Passed: Only selected members are in the private group.")
    
    # ── Test 2: Verify Group Visibility (Private groups are hidden from non-members) ──
    print("\n[Test 2] Verifying private group visibility...")
    # Student A can see it
    res = client.get("/api/student/groups", headers=headers_a)
    group_ids_a = {g["id"] for g in res.json().get("data", {}).get("groups", [])}
    assert group_id in group_ids_a, "Student A (creator) should see the private group"
    
    # Student B can see it
    res = client.get("/api/student/groups", headers=headers_b)
    group_ids_b = {g["id"] for g in res.json().get("data", {}).get("groups", [])}
    assert group_id in group_ids_b, "Student B (member) should see the private group"
    
    # Student C (non-member) cannot see it
    res = client.get("/api/student/groups", headers=headers_c)
    group_ids_c = {g["id"] for g in res.json().get("data", {}).get("groups", [])}
    assert group_id not in group_ids_c, "Student C (non-member) should NOT see the private group"
    print("Passed: Private group is invisible to non-members.")
    
    # ── Test 3: Deny Join to Private Group ──
    print("\n[Test 3] Verifying join restriction on private group...")
    res = client.post(f"/api/student/groups/{group_id}/join", headers=headers_c)
    assert res.status_code == 403, f"Expected 403, got {res.status_code}: {res.text}"
    print("Passed: Non-member cannot join private group.")
    
    # ── Test 4: Student creating Public Group (Classmates can see, non-classmates cannot) ──
    print("\n[Test 4] Student A creating public class-level group...")
    pub_group_payload = {
        "name": "Public Math 10A Study",
        "description": "Public math discussion",
        "group_level": "class",
        "is_private": False
    }
    res = client.post("/api/student/groups/create", json=pub_group_payload, headers=headers_a)
    assert res.status_code == 200
    pub_group_id = res.json().get("data", {}).get("group")["id"]
    
    # Student B (classmate in 10A) can see it
    res = client.get("/api/student/groups", headers=headers_b)
    group_ids_b = {g["id"] for g in res.json().get("data", {}).get("groups", [])}
    assert pub_group_id in group_ids_b, "Student B (classmate) should see the public class group"
    
    # Student C (non-classmate in 10B) cannot see it
    res = client.get("/api/student/groups", headers=headers_c)
    group_ids_c = {g["id"] for g in res.json().get("data", {}).get("groups", [])}
    assert pub_group_id not in group_ids_c, "Student C (non-classmate) should NOT see the public class group"
    print("Passed: Student public group is visible to classmates but hidden from others.")
    
    # ── Test 5: Teacher creating Public Group (Visible to everyone in school) ──
    print("\n[Test 5] Teacher A creating public school-level group...")
    teacher_pub_payload = {
        "name": "School Science Fair Discussion",
        "description": "Open to all students",
        "group_level": "school",
        "is_private": False
    }
    res = client.post("/api/teacher/groups/create", json=teacher_pub_payload, headers=headers_teacher)
    assert res.status_code == 200
    teacher_group_id = res.json().get("data", {}).get("group")["id"]
    
    # Student A (10A) can see it
    res = client.get("/api/student/groups", headers=headers_a)
    group_ids_a = {g["id"] for g in res.json().get("data", {}).get("groups", [])}
    assert teacher_group_id in group_ids_a, "Student A should see teacher public school group"
    
    # Student C (10B) can see it
    res = client.get("/api/student/groups", headers=headers_c)
    group_ids_c = {g["id"] for g in res.json().get("data", {}).get("groups", [])}
    assert teacher_group_id in group_ids_c, "Student C should see teacher public school group"
    print("Passed: Teacher public group is visible to everyone in the school.")
    
    # ── Test 6: Admin Management (Promote, Demote, Demote Last Admin, Remove Member) ──
    print("\n[Test 6] Testing admin actions (promote, demote, demote last admin, remove)...")
    
    # Get initial roles in Secret Physics Revision (group_id)
    # Student A is admin (creator), Student B is member.
    res = client.get(f"/api/groups/{group_id}/members", headers=headers_a)
    members = res.json().get("data", {}).get("members", [])
    for m in members:
        if m["id"] == id_b:
            assert m["group_role"] == "member"
            
    # Student A promotes Student B to admin
    res = client.post(f"/api/groups/{group_id}/members/{id_b}/role", json={"role": "admin"}, headers=headers_a)
    assert res.status_code == 200, f"Failed to promote B: {res.text}"
    
    # Verify Student B is admin
    res = client.get(f"/api/groups/{group_id}/members", headers=headers_a)
    members = res.json().get("data", {}).get("members", [])
    role_b = next(m["group_role"] for m in members if m["id"] == id_b)
    assert role_b == "admin"
    print("Passed: Student B successfully promoted to admin.")
    
    # Student B demotes Student A to member
    res = client.post(f"/api/groups/{group_id}/members/{id_a}/role", json={"role": "member"}, headers=headers_b)
    assert res.status_code == 200, f"Failed to demote A: {res.text}"
    
    # Verify Student A is member
    res = client.get(f"/api/groups/{group_id}/members", headers=headers_b)
    members = res.json().get("data", {}).get("members", [])
    role_a = next(m["group_role"] for m in members if m["id"] == id_a)
    assert role_a == "member"
    print("Passed: Student A successfully demoted to member.")
    
    # Student B tries to demote themselves to member (last admin remaining!)
    res = client.post(f"/api/groups/{group_id}/members/{id_b}/role", json={"role": "member"}, headers=headers_b)
    assert res.status_code == 400, f"Expected 400, got {res.status_code}: {res.text}"
    assert "last admin" in res.json().get("detail", "").lower()
    print("Passed: Prevented demoting the last admin in group.")
    
    # Student B removes Student A from the group
    res = client.delete(f"/api/groups/{group_id}/members/{id_a}", headers=headers_b)
    assert res.status_code == 200, f"Failed to remove A: {res.text}"
    
    # Verify Student A is no longer a member
    res = client.get(f"/api/shared/groups/{group_id}/members", headers=headers_b)
    members = res.json().get("data", {}).get("members", [])
    assert not any(m["id"] == id_a for m in members)
    print("Passed: Student A successfully removed from the group.")
    
    print("\n" + "="*60)
    print("ALL GROUP PRIVACY AND ADMIN ENDPOINT TESTS PASSED SUCCESSFULLY!")
    print("="*60)

if __name__ == "__main__":
    run_tests()
