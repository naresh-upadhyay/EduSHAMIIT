import asyncio
import uuid
from app.services.supabase_client import get_supabase
from app.api.superadmin import (
    get_role_hierarchy,
    list_roles,
    get_role_detail,
    create_role,
    update_role,
    update_role_parent,
    get_role_users,
    get_role_audit_logs,
    delete_role,
    RoleCreateRequest,
    RoleUpdateRequest,
    RoleParentUpdateRequest,
    detect_circular_parent,
    compute_ancestor_permissions
)
from fastapi import HTTPException

async def run_tests():
    print("=================================================================")
    print("🚀 RUNNING EXHAUSTIVE ROLE HIERARCHY TEST SUITE")
    print("=================================================================")
    sb = get_supabase()
    user_admin = {"id": str(uuid.uuid4()), "email": "admin@schoolerp.com", "role": "super_admin", "name": "Super Admin"}
    
    # TEST 1: Get complete Role Hierarchy Tree
    print("\n--- TEST 1: Get complete Role Hierarchy Tree ---")
    res = await get_role_hierarchy(school_id=None, user=user_admin)
    assert res["success"] is True, "Failed to fetch hierarchy"
    assert res["total_roles"] > 0, "Expected roles in database"
    assert len(res["tree"]) > 0, "Expected tree root nodes"
    print(f"✅ Success: {res['total_roles']} roles loaded, {len(res['tree'])} root nodes.")
    
    # TEST 2: Verify Canonical Tree Hierarchy Linkages
    print("\n--- TEST 2: Verify Canonical Parent-Child Tree Linkages ---")
    flat = res["flat_roles"]
    roles_map = {r["name"]: r for r in flat}
    
    assert "super_admin" in roles_map, "super_admin missing"
    assert "admin" in roles_map, "admin missing"
    assert "principal" in roles_map, "principal missing"
    assert "teacher" in roles_map, "teacher missing"
    assert "student" in roles_map, "student missing"
    
    super_role = roles_map["super_admin"]
    admin_role = roles_map["admin"]
    principal_role = roles_map["principal"]
    teacher_role = roles_map["teacher"]
    student_role = roles_map["student"]
    
    assert super_role["level"] == 1, f"Expected super_admin level 1, got {super_role['level']}"
    assert admin_role["level"] == 2, f"Expected admin level 2, got {admin_role['level']}"
    assert principal_role["level"] == 2, f"Expected principal level 2, got {principal_role['level']}"
    assert teacher_role["level"] == 3, f"Expected teacher level 3, got {teacher_role['level']}"
    assert student_role["level"] == 3, f"Expected student level 3, got {student_role['level']}"
    
    assert admin_role.get("parent_role_id") == super_role["id"], "admin parent should be super_admin"
    assert teacher_role.get("parent_role_id") == admin_role["id"], "teacher parent should be admin"
    assert student_role.get("parent_role_id") == principal_role["id"], "student parent should be principal"
    print("✅ Canonical linkages verified (Super Admin -> Institution Admin / Academic Admin -> Teacher / Student).")

    # TEST 3: Direct vs Inherited vs Effective Permissions
    print("\n--- TEST 3: Verify Direct vs Inherited vs Effective Permissions ---")
    assert teacher_role["permissions_count"] >= 3, "Teacher should have direct permissions"
    assert "inherited_permissions" in teacher_role, "Teacher should have inherited_permissions list"
    assert "effective_permissions" in teacher_role, "Teacher should have effective_permissions list"
    assert teacher_role["effective_permissions_count"] >= teacher_role["permissions_count"], "Effective permissions must be >= direct"
    print(f"✅ Teacher Permissions: Direct={teacher_role['permissions_count']}, Inherited={teacher_role['inherited_permissions_count']}, Effective={teacher_role['effective_permissions_count']}")

    # TEST 4: Search & Multi-field Filtering
    print("\n--- TEST 4: Test Search & Filtering in list_roles ---")
    search_res = await list_roles(q="Teacher", page=1, limit=10, user=user_admin)
    assert search_res["success"] is True
    assert search_res["total"] >= 1
    found_names = [r["name"] for r in search_res["data"]]
    assert any("teacher" in n for n in found_names), "Expected teacher in search results"
    print(f"✅ Search for 'Teacher' returned {search_res['total']} matching roles.")

    filter_res = await list_roles(role_type="CUSTOM", page=1, limit=10, user=user_admin)
    assert filter_res["success"] is True
    for r in filter_res["data"]:
        assert r["role_type"] == "CUSTOM"
    print(f"✅ Filter by role_type=CUSTOM returned {filter_res['total']} custom roles.")

    # TEST 5: Create Custom Role with Hierarchy & Auto Level
    print("\n--- TEST 5: Create Custom Role under Teacher with Auto-calculated Level ---")
    unique_suffix = str(uuid.uuid4())[:6]
    test_role_name = f"Assistant Teacher {unique_suffix}"
    test_role_code = f"ASST_TEACHER_{unique_suffix.upper()}"
    
    create_req = RoleCreateRequest(
        name=test_role_name,
        code=test_role_code,
        description="Assistant instructor supporting classroom activities",
        parent_role_id=teacher_role["id"],
        role_type="CUSTOM",
        inherit_permissions=True,
        permissions=["view_courses", "grade_assignments"],
        status="Active"
    )
    
    created_res = await create_role(create_req, user=user_admin)
    assert created_res["success"] is True
    created_role = created_res["data"]
    test_role_id = str(created_role["id"])
    assert created_role["level"] == teacher_role["level"] + 1, f"Expected level {teacher_role['level'] + 1}, got {created_role['level']}"
    assert created_role["code"] == test_role_code
    print(f"✅ Created role '{test_role_name}' with ID {test_role_id} and Level {created_role['level']} (Parent Level {teacher_role['level']}).")

    # TEST 6: Prevent Duplicate Role Code
    print("\n--- TEST 6: Prevent Duplicate Role Code ---")
    dup_code_req = RoleCreateRequest(
        name=f"Duplicate Test {unique_suffix}",
        code=test_role_code,
        parent_role_id=teacher_role["id"],
    )
    try:
        await create_role(dup_code_req, user=user_admin)
        assert False, "Should have failed on duplicate code"
    except HTTPException as e:
        assert e.status_code == 400
        assert "already exists" in e.detail
        print(f"✅ Blocked duplicate code '{test_role_code}' with 400 Bad Request.")

    # TEST 7: Prevent Self-Parenting
    print("\n--- TEST 7: Prevent Self-Parenting ---")
    self_parent_req = RoleParentUpdateRequest(new_parent_role_id=test_role_id)
    try:
        await update_role_parent(test_role_id, self_parent_req, user=user_admin)
        assert False, "Should have failed on self-parenting"
    except HTTPException as e:
        assert e.status_code == 400
        assert "circular" in e.detail.lower()
        print("✅ Blocked self-parenting with 400 Circular Hierarchy error.")

    # TEST 8: Prevent Multi-node Circular Hierarchy Loop (A -> B -> C -> A)
    print("\n--- TEST 8: Prevent Multi-node Circular Hierarchy Loop ---")
    # Let's create child of test_role
    sub_role_req = RoleCreateRequest(
        name=f"Sub Assistant {unique_suffix}",
        code=f"SUB_ASST_{unique_suffix.upper()}",
        parent_role_id=test_role_id,
        role_type="CUSTOM",
    )
    sub_res = await create_role(sub_role_req, user=user_admin)
    sub_role_id = str(sub_res["data"]["id"])
    
    # Attempt to set test_role's parent to sub_role (Cycle: test_role -> sub_role -> test_role)
    cycle_req = RoleParentUpdateRequest(new_parent_role_id=sub_role_id)
    try:
        await update_role_parent(test_role_id, cycle_req, user=user_admin)
        assert False, "Should have failed on circular cycle"
    except HTTPException as e:
        assert e.status_code == 400
        assert "circular" in e.detail.lower()
        print("✅ Blocked circular hierarchy cycle (A -> B -> A) with 400 Circular Hierarchy error.")

    # TEST 9: Reparenting Role & Recalculating Levels
    print("\n--- TEST 9: Reparent Role & Verify Descendant Level Recalculation ---")
    # Reparent test_role from Teacher (level 3) to Academic Admin / Principal (level 2)
    reparent_req = RoleParentUpdateRequest(new_parent_role_id=principal_role["id"])
    reparent_res = await update_role_parent(test_role_id, reparent_req, user=user_admin)
    assert reparent_res["success"] is True
    assert reparent_res["data"]["level"] == 3, f"Expected level 3 under principal, got {reparent_res['data']['level']}"
    
    # Verify sub_role level also cascaded down to level 4
    sub_role_detail = await get_role_detail(sub_role_id, user=user_admin)
    assert sub_role_detail["data"]["level"] == 4, f"Expected sub_role level 4, got {sub_role_detail['data']['level']}"
    print("✅ Reparenting succeeded and descendant levels correctly cascaded.")

    # TEST 10: Fetch Role Users
    print("\n--- TEST 10: Fetch Users Assigned to Role ---")
    users_res = await get_role_users(teacher_role["id"], page=1, limit=10, user=user_admin)
    assert users_res["success"] is True
    print(f"✅ Fetched users for role '{teacher_role['name']}': Total={users_res['total']}, returned={len(users_res['data'])}.")

    # TEST 11: Fetch Role Audit Logs
    print("\n--- TEST 11: Fetch Role Audit Logs ---")
    audit_res = await get_role_audit_logs(test_role_id, page=1, limit=10, user=user_admin)
    assert audit_res["success"] is True
    print(f"✅ Fetched audit logs for role '{test_role_name}': Count={audit_res['total']}.")

    # TEST 12: Delete Role with Child Dependencies is Blocked
    print("\n--- TEST 12: Delete Role with Child Roles is Blocked ---")
    try:
        await delete_role(test_role_id, user=user_admin)
        assert False, "Should have blocked deletion because sub_role depends on it"
    except HTTPException as e:
        assert e.status_code == 400
        assert "child role" in e.detail.lower()
        print("✅ Deletion of parent role blocked due to dependent child roles.")

    # TEST 13: Clean up created test roles
    print("\n--- TEST 13: Clean Up Test Roles ---")
    del_sub = await delete_role(sub_role_id, user=user_admin)
    assert del_sub["success"] is True
    del_test = await delete_role(test_role_id, user=user_admin)
    assert del_test["success"] is True
    print("✅ Cleaned up temporary test roles successfully.")

    print("\n=================================================================")
    print("🎉 ALL 13 TEST CASES PASSED SUCCESSFULLY WITH ZERO ERRORS!")
    print("=================================================================")

if __name__ == "__main__":
    asyncio.run(run_tests())
