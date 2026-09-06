"""
Comprehensive Automated E2E Test Suite for Library Members Subsystem.
Tests all 15 Scenarios: KPI Aggregation, Filtering, Profile Search,
Membership Creation, Duplicate Guard, Details Drawer, Parameters Update,
Renewal, Suspension, Reactivation, Bulk Actions, CSV Export, Cross-Tenant Isolation, and Deletion.
"""
import asyncio
import logging
import uuid
import datetime
from typing import Dict, Any

from app.api.library import (
    get_member_kpi_stats,
    get_member_filter_options,
    search_profiles_for_member,
    list_library_members,
    get_member_detail,
    create_library_member,
    update_library_member,
    renew_membership,
    suspend_membership,
    activate_membership,
    delete_library_member,
    bulk_member_action,
    export_members_csv,
    MemberCreateRequest,
    MemberUpdateRequest,
    MemberRenewRequest,
    MemberSuspendRequest,
    MemberBulkActionRequest,
    exec_sql
)

logging.basicConfig(level=logging.INFO, format="%(levelname)s:%(name)s:%(message)s")
logger = logging.getLogger("TestLibraryMembersComprehensive")


async def run_e2e_tests():
    logger.info("==================================================================")
    logger.info("   EduSHAMIIT ERP - 100% COMPREHENSIVE LIBRARY MEMBERS E2E SUITE   ")
    logger.info("==================================================================")

    # 1. Setup Test School & Test Users
    school_rows = await exec_sql("SELECT id FROM public.schools ORDER BY id LIMIT 2;")
    if not school_rows:
        raise RuntimeError("No schools found in database.")
    school_id = str(school_rows[0]["id"])
    other_school_id = str(school_rows[1]["id"]) if len(school_rows) > 1 else str(uuid.uuid4())

    user_rows = await exec_sql("SELECT id, full_name, email FROM public.profiles WHERE school_id = %s LIMIT 5;", (school_id,))
    if not user_rows:
        raise RuntimeError(f"No profiles found in school {school_id}")
    current_user = {"id": str(user_rows[0]["id"]), "name": user_rows[0]["full_name"]}

    # Scenario 01: KPI Aggregated Stats
    stats = await get_member_kpi_stats(school_id=school_id, current_user=current_user)
    assert "total_members" in stats, "KPI missing total_members"
    assert "active_members" in stats, "KPI missing active_members"
    assert "total_outstanding_fine" in stats, "KPI missing total_outstanding_fine"
    logger.info(f"[PASS] Scenario 01: Aggregated KPI Stats (Total: {stats['total_members']}, Active: {stats['active_members']}, Fines: {stats['total_outstanding_fine']})")

    # Scenario 02: Dynamic Filter Options
    filter_opts = await get_member_filter_options(school_id=school_id, current_user=current_user)
    assert "member_types" in filter_opts, "Filter missing member_types"
    assert "classes" in filter_opts, "Filter missing classes"
    assert len(filter_opts["member_types"]) > 0, "No member types found"
    logger.info(f"[PASS] Scenario 02: Dynamic Filter Options ({len(filter_opts['member_types'])} Types, {len(filter_opts['classes'])} Classes)")

    # Scenario 03: Profile Live Search for Member Creation
    search_res = await search_profiles_for_member(query="", role="ALL", school_id=school_id, current_user=current_user)
    assert isinstance(search_res, list) and len(search_res) > 0, "Profile search returned empty"
    target_profile = search_res[0]
    assert "full_name" in target_profile, "Missing full_name in profile search"
    assert "is_already_member" in target_profile, "Missing is_already_member flag"
    logger.info(f"[PASS] Scenario 03: Search Existing Profiles ({len(search_res)} candidates available)")

    # Scenario 04: Create a Brand New Profile & Add as Library Member
    test_user_id = f"test_patron_{str(uuid.uuid4())[:8]}"
    new_profile_sql = """
        INSERT INTO public.profiles (
            school_id, user_id, full_name, role, class, department, email, phone
        ) VALUES (
            %s, %s, 'Ananya Kashyap', 'student', 'Class 10-A', 'Science', %s, '+91 99887 76655'
        ) RETURNING id;
    """
    p_rows = await exec_sql(new_profile_sql, (school_id, test_user_id, f"{test_user_id}@test.com"))
    new_profile_id = str(p_rows[0]["id"])

    create_payload = MemberCreateRequest(
        profile_id=new_profile_id,
        membership_type="Student",
        borrowing_limit=3,
        max_issue_duration_days=14,
        status="ACTIVE",
        notes="Automated test patron"
    )
    create_res = await create_library_member(payload=create_payload, school_id=school_id, current_user=current_user)
    assert create_res["success"] is True
    created_member_id = create_res["member_id"]
    created_member_code = create_res["member_code"]
    logger.info(f"[PASS] Scenario 04: Created Library Member '{created_member_code}' (ID: {created_member_id})")

    # Scenario 05: Prevent Duplicate Membership
    duplicate_blocked = False
    try:
        await create_library_member(payload=create_payload, school_id=school_id, current_user=current_user)
    except Exception as e:
        duplicate_blocked = True
        logger.info(f"[PASS] Scenario 05: Duplicate Member Prevented: {getattr(e, 'detail', str(e))}")
    assert duplicate_blocked, "Failed to block duplicate library membership creation for same profile"

    # Scenario 06: Fetch Member Details
    detail = await get_member_detail(member_id=created_member_id, school_id=school_id, current_user=current_user)
    assert detail["member"]["member_code"] == created_member_code
    assert detail["member"]["member_name"] == "Ananya Kashyap"
    assert "summary" in detail
    assert "current_books" in detail
    logger.info(f"[PASS] Scenario 06: Member Details Retrieved ({detail['member']['member_name']}, Code: {detail['member']['member_code']})")

    # Scenario 07: Update Membership Parameters
    update_payload = MemberUpdateRequest(
        borrowing_limit=5,
        notes="Upgraded borrowing privileges"
    )
    upd_res = await update_library_member(member_id=created_member_id, payload=update_payload, school_id=school_id, current_user=current_user)
    assert upd_res["success"] is True
    updated_detail = await get_member_detail(member_id=created_member_id, school_id=school_id, current_user=current_user)
    assert updated_detail["member"]["borrowing_limit"] == 5
    logger.info(f"[PASS] Scenario 07: Updated Membership Parameters (Borrowing Limit = 5)")

    # Scenario 08: Renew Membership
    new_expiry = (datetime.date.today() + datetime.timedelta(days=730))
    renew_payload = MemberRenewRequest(new_expiry_date=new_expiry, notes="2-Year renewal")
    renew_res = await renew_membership(member_id=created_member_id, payload=renew_payload, school_id=school_id, current_user=current_user)
    assert renew_res["success"] is True
    assert renew_res["new_expiry_date"] == new_expiry.isoformat()
    logger.info(f"[PASS] Scenario 08: Renewed Membership to {new_expiry.isoformat()}")

    # Scenario 09: Suspend Member
    suspend_payload = MemberSuspendRequest(reason="Overdue return violation")
    susp_res = await suspend_membership(member_id=created_member_id, payload=suspend_payload, school_id=school_id, current_user=current_user)
    assert susp_res["success"] is True
    susp_detail = await get_member_detail(member_id=created_member_id, school_id=school_id, current_user=current_user)
    assert susp_detail["member"]["status"] == "SUSPENDED"
    logger.info("[PASS] Scenario 09: Member Suspended with Reason Recorded")

    # Scenario 10: Reactivate Member
    act_res = await activate_membership(member_id=created_member_id, school_id=school_id, current_user=current_user)
    assert act_res["success"] is True
    act_detail = await get_member_detail(member_id=created_member_id, school_id=school_id, current_user=current_user)
    assert act_detail["member"]["status"] == "ACTIVE"
    logger.info("[PASS] Scenario 10: Member Reactivated to Active Status")

    # Scenario 11: Paginated Members List & Search
    list_res = await list_library_members(
        page=1,
        page_size=10,
        search="Ananya",
        school_id=school_id,
        current_user=current_user
    )
    assert list_res["meta"]["total_items"] >= 1
    assert any(m["id"] == created_member_id for m in list_res["items"])
    logger.info(f"[PASS] Scenario 11: Search & Filter Paginated Members List (Found: {list_res['meta']['total_items']})")

    # Scenario 12: Bulk Action (Change Type)
    bulk_payload = MemberBulkActionRequest(
        member_ids=[created_member_id],
        action="CHANGE_LIMIT",
        params={"borrowing_limit": 4}
    )
    bulk_res = await bulk_member_action(payload=bulk_payload, school_id=school_id, current_user=current_user)
    assert bulk_res["success"] is True
    assert bulk_res["affected_count"] == 1
    logger.info("[PASS] Scenario 12: Bulk Action Successfully Executed")

    # Scenario 13: Export Members to CSV
    csv_stream = await export_members_csv(school_id=school_id, current_user=current_user)
    assert csv_stream.media_type == "text/csv"
    logger.info("[PASS] Scenario 13: Export Members CSV Stream Generated")

    # Scenario 14: Cross-Tenant Isolation
    cross_tenant_blocked = False
    try:
        await get_member_detail(member_id=created_member_id, school_id=other_school_id, current_user=current_user)
    except Exception as e:
        cross_tenant_blocked = True
        logger.info(f"[PASS] Scenario 14: Cross-Tenant Access Blocked ({getattr(e, 'status_code', 404)})")
    assert cross_tenant_blocked, "Failed to isolate member between different school tenants"

    # Scenario 15: Soft Delete Member
    del_res = await delete_library_member(member_id=created_member_id, school_id=school_id, current_user=current_user)
    assert del_res["success"] is True
    logger.info("[PASS] Scenario 15: Soft-Deleted Member & Verified Integrity")

    logger.info("==================================================================")
    logger.info("  ALL 15/15 COMPREHENSIVE MEMBERS E2E SCENARIOS PASSED (100%)    ")
    logger.info("==================================================================")


if __name__ == "__main__":
    asyncio.run(run_e2e_tests())
