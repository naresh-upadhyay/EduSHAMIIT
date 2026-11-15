import asyncio
import os
import sys
import httpx
import uuid
import time
from jose import jwt

API_BASE_URL = os.environ.get("API_BASE_URL", "http://localhost:8082")
JWT_SECRET = "super-secret-jwt-token-with-at-least-32-characters-long"
SCHOOL_ID = "11111111-1111-1111-1111-111111111111"

def create_test_jwt(user_id: str, email: str, role: str, school_id: str = SCHOOL_ID) -> str:
    payload = {
        "sub": user_id,
        "email": email,
        "role": role,
        "school_id": school_id,
        "exp": int(time.time()) + 86400
    }
    return jwt.encode(payload, JWT_SECRET, algorithm="HS256")

async def run_tests():
    print("=" * 70)
    print("RUNNING COMPREHENSIVE MESSAGING & GROUP MANAGEMENT EDGE-CASE TEST SUITE")
    print("=" * 70)
    
    async with httpx.AsyncClient(base_url=API_BASE_URL, timeout=30.0) as client:
        # 1. Health check
        health_res = await client.get("/health")
        assert health_res.status_code == 200, f"Health check failed: {health_res.text}"
        print("✓ Step 1: Backend API is healthy and reachable.")
        
        # 2. Authenticate as Super Admin (King Doe)
        admin_token = create_test_jwt("SUP-A699FB", "mathematicsking888@gmail.com", "super_admin")
        admin_headers = {
            "Authorization": f"Bearer {admin_token}",
            "X-School-Id": SCHOOL_ID
        }
        print("✓ Step 2: Authenticated as Admin/SuperAdmin (King Doe - SUP-A699FB).")

        # 3. Authenticate as Teacher (Dr. Neha Sharma)
        teacher_token = create_test_jwt("TEA-F78F76", "nehaupadhyay9119@gmail.com", "teacher")
        teacher_headers = {
            "Authorization": f"Bearer {teacher_token}",
            "X-School-Id": SCHOOL_ID
        }
        print("✓ Step 3: Authenticated as Teacher (Dr. Neha Sharma - TEA-F78F76).")

        # 4. Authenticate as Student (Naresh King)
        student_id = "STU-9E9847"
        student_token = create_test_jwt(student_id, "naresh.king88898@gmail.com", "student")
        student_headers = {
            "Authorization": f"Bearer {student_token}",
            "X-School-Id": SCHOOL_ID
        }
        print(f"✓ Step 4: Authenticated as Student (Naresh King - {student_id}).")

        # 5. Create New Group (by Admin)
        unique_suffix = uuid.uuid4().hex[:6]
        group_name = f"Test Group {unique_suffix}"
        create_res = await client.post("/api/groups/create", headers=admin_headers, json={
            "name": group_name,
            "description": "Comprehensive test group for school communication",
            "is_private": False,
            "group_level": "school",
            "avatar_url": "https://images.unsplash.com/photo-1577896851231-70ef18881754?w=150"
        })
        assert create_res.status_code == 200, f"Create group failed: {create_res.text}"
        group = create_res.json()["data"]["group"]
        group_id = group["id"]
        print(f"✓ Step 5: Group created successfully. Group ID: {group_id}, Name: '{group_name}'")

        # 6. Add Members to Group (Add Teacher & Student)
        add_teacher_res = await client.post(f"/api/groups/{group_id}/members", headers=admin_headers, json={
            "member_id": "TEA-F78F76"
        })
        assert add_teacher_res.status_code == 200, f"Add teacher failed: {add_teacher_res.text}"
        
        add_student_res = await client.post(f"/api/groups/{group_id}/members", headers=admin_headers, json={
            "member_id": student_id
        })
        assert add_student_res.status_code == 200, f"Add student failed: {add_student_res.text}"
        print("✓ Step 6: Added Teacher and Student to the group.")

        # Duplicate Add Test (should not crash, return success or graceful message)
        dup_res = await client.post(f"/api/groups/{group_id}/members", headers=admin_headers, json={
            "member_id": student_id
        })
        assert dup_res.status_code == 200, f"Duplicate member add crashed: {dup_res.text}"
        print("✓ Step 6b: Duplicate member add handled gracefully without error.")

        # 7. Get Group Members and Verify Real Profile Data
        members_res = await client.get(f"/api/groups/{group_id}/members", headers=admin_headers)
        assert members_res.status_code == 200, f"Get members failed: {members_res.text}"
        members = members_res.json()["data"]["members"]
        assert len(members) >= 3, f"Expected at least 3 members, found {len(members)}"
        
        for m in members:
            assert m["name"] and "Member (" not in m["name"], f"Generic placeholder name found: {m}"
            assert m["role"] in ("admin", "member"), f"Invalid group role: {m.get('role')}"
            print(f"   - Member: {m['name']} | Role: {m['role']} | Email: {m.get('email')} | Type: {m.get('user_role')}")
        print("✓ Step 7: Group members list returned real full names and verified profile details.")

        # 8. Promote Teacher to Group Admin
        teacher_mid = next(m["id"] for m in members if "Neha" in m["name"] or m.get("user_role") == "teacher")
        promote_res = await client.post(f"/api/groups/{group_id}/members/{teacher_mid}/role", headers=admin_headers, json={
            "role": "admin"
        })
        assert promote_res.status_code == 200, f"Promote admin failed: {promote_res.text}"
        
        # Verify teacher is now admin
        members_check = (await client.get(f"/api/groups/{group_id}/members", headers=admin_headers)).json()["data"]["members"]
        teacher_mem = next(m for m in members_check if m["id"] == teacher_mid)
        assert teacher_mem["role"] == "admin", f"Teacher role should be admin, got {teacher_mem['role']}"
        print(f"✓ Step 8: Teacher successfully promoted to Group Admin.")

        # 9. Dismiss as Admin (Demote Teacher back to Member)
        dismiss_res = await client.post(f"/api/groups/{group_id}/members/{teacher_mid}/role", headers=admin_headers, json={
            "role": "member"
        })
        assert dismiss_res.status_code == 200, f"Dismiss admin failed: {dismiss_res.text}"
        
        # Verify teacher is member again
        members_check2 = (await client.get(f"/api/groups/{group_id}/members", headers=admin_headers)).json()["data"]["members"]
        teacher_mem2 = next(m for m in members_check2 if m["id"] == teacher_mid)
        assert teacher_mem2["role"] == "member", f"Teacher role should be member, got {teacher_mem2['role']}"
        print(f"✓ Step 9: 'Dismiss as admin' executed successfully and instantly reflected.")

        # 10. Test Demoting the LAST Admin Constraint
        admin_mid = next(m["id"] for m in members_check2 if m["role"] == "admin")
        demote_last_res = await client.post(f"/api/groups/{group_id}/members/{admin_mid}/role", headers=admin_headers, json={
            "role": "member"
        })
        assert demote_last_res.status_code == 400, f"Expected 400 when demoting last admin, got {demote_last_res.status_code}"
        print("✓ Step 10: System prevented demoting the last remaining admin (HTTP 400 safety check passed).")

        # 11. Edit Group Details (Name & Description & Avatar)
        new_group_name = f"Updated Squad {unique_suffix}"
        edit_res = await client.put(f"/api/groups/{group_id}", headers=admin_headers, json={
            "name": new_group_name,
            "description": "Updated squad description for immediate UI sync",
            "avatar_url": "https://images.unsplash.com/photo-1546410531-bb4caa6b424d?w=150"
        })
        assert edit_res.status_code == 200, f"Edit group details failed: {edit_res.text}"
        
        # Verify in get_messages
        msg_convs = (await client.get("/api/messages", headers=admin_headers)).json()["data"]["conversations"]
        updated_conv = next((c for c in msg_convs if c["id"] == group_id), None)
        assert updated_conv is not None, "Updated group not found in conversations"
        assert updated_conv["name"] == new_group_name, f"Expected '{new_group_name}', got '{updated_conv['name']}'"
        print(f"✓ Step 11: Edit group details updated name to '{new_group_name}' and verified in conversations.")

        # 12. Send Message to Group (by Student Member)
        student_msg_res = await client.post("/api/messages/send", headers=student_headers, json={
            "group_id": group_id,
            "content": "Hello team, I am ready for the project!"
        })
        assert student_msg_res.status_code == 200, f"Student send message failed: {student_msg_res.text}"
        student_msg = student_msg_res.json()["data"]["message"]
        student_msg_id = student_msg["id"]
        print(f"✓ Step 12: Student sent message to group successfully. Message ID: {student_msg_id}")

        # 13. Message Deletion Permissions
        # Student deletes their own message: SHOULD SUCCEED
        del_own_res = await client.delete(f"/api/messages/{student_msg_id}", headers=student_headers)
        assert del_own_res.status_code == 200, f"Student deleting own message failed: {del_own_res.text}"
        print("✓ Step 13a: Student successfully deleted their own message.")

        # Send a message by Admin
        admin_msg_res = await client.post("/api/messages/send", headers=admin_headers, json={
            "group_id": group_id,
            "content": "Notice from Admin to all members"
        })
        assert admin_msg_res.status_code == 200, f"Admin send message failed: {admin_msg_res.text}"
        admin_msg_id = admin_msg_res.json()["data"]["message"]["id"]

        # Student attempts to delete Admin's message: SHOULD BE FORBIDDEN (403)
        del_other_res = await client.delete(f"/api/messages/{admin_msg_id}", headers=student_headers)
        assert del_other_res.status_code == 403, f"Expected 403 when deleting others' message, got {del_other_res.status_code}"
        print("✓ Step 13b: Security Check Passed: Regular student blocked from deleting other users' messages (HTTP 403).")

        # 14. Non-Admin Cannot Clear Group Chat History (403)
        clear_by_student = await client.post("/api/messages/clear", headers=student_headers, json={
            "chat_id": group_id
        })
        assert clear_by_student.status_code == 403, f"Expected 403 when non-admin clears chat, got {clear_by_student.status_code}"
        print("✓ Step 14: Security Check Passed: Regular student blocked from clearing group chat history (HTTP 403).")

        # 15. Student Leaves Group (Exit Group)
        leave_res = await client.post(f"/api/groups/{group_id}/leave", headers=student_headers)
        assert leave_res.status_code == 200, f"Leave group failed: {leave_res.text}"
        print("✓ Step 15: Student successfully exited the group.")

        # 16. Exited Student Does Not See Group in Active Conversations
        student_convs = (await client.get("/api/messages", headers=student_headers)).json()["data"]["conversations"]
        assert not any(c["id"] == group_id for c in student_convs), "Exited group must NOT appear in student's conversations"
        print("✓ Step 16: Exited group is completely hidden from student's active conversation list.")

        # 17. Exited Student Cannot Send Message to Exited Group (403 Forbidden)
        send_after_exit = await client.post("/api/messages/send", headers=student_headers, json={
            "group_id": group_id,
            "content": "Trying to send message after leaving"
        })
        assert send_after_exit.status_code == 403, f"Expected 403 when exited member sends message, got {send_after_exit.status_code}"
        print("✓ Step 17: Security Check Passed: Exited member blocked from sending messages to group (HTTP 403).")

        # 18. Admin Clears Chat History (Should Succeed)
        admin_clear_res = await client.post("/api/messages/clear", headers=admin_headers, json={
            "chat_id": group_id
        })
        assert admin_clear_res.status_code == 200, f"Admin clear chat failed: {admin_clear_res.text}"
        print("✓ Step 18: Admin successfully cleared group chat history.")

        # 19. Clean up test group
        del_group_res = await client.delete(f"/api/groups/{group_id}", headers=admin_headers)
        assert del_group_res.status_code == 200, f"Clean up group failed: {del_group_res.text}"
        print("✓ Step 19: Test group cleaned up successfully.")

    print("=" * 70)
    print("ALL 19 END-TO-END EDGE-CASE TESTS PASSED PERFECTLY WITH ZERO DEFECTS!")
    print("=" * 70)

if __name__ == "__main__":
    asyncio.run(run_tests())
