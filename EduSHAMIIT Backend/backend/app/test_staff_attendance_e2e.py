import asyncio
import json
import logging
import uuid
from app.api.attendance import (
    exec_sql,
    get_staff_attendance,
    save_staff_attendance,
    SaveStaffAttendanceRequest,
    StaffAttendanceItemPayload,
    get_manager_status,
)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("TestStaffAttendance")

async def run_tests():
    logger.info("==========================================================================")
    logger.info("  TESTING ENHANCED FACULTY & STAFF ATTENDANCE AND MANAGER FILTER (E2E)    ")
    logger.info("==========================================================================")

    # 1. Fetch school and staff profiles
    schools = await exec_sql("SELECT id FROM public.schools LIMIT 1;")
    assert len(schools) > 0, "No school found"
    school_id = str(schools[0]["id"])
    test_date = "2026-08-22"

    # 2. Get a manager profile or assign a test manager
    managers = await exec_sql("SELECT id, full_name, email, role FROM public.profiles WHERE role IN ('admin', 'super_admin', 'director', 'principal') LIMIT 1;")
    manager_id = str(managers[0]["id"])
    manager_name = managers[0]["full_name"]
    manager_role = managers[0]["role"]

    user_dict = {
        "id": manager_id,
        "email": managers[0]["email"],
        "role": manager_role,
        "school_id": school_id
    }

    # Fetch 2 staff members belonging to this school
    staff_rows = await exec_sql("SELECT id, full_name FROM public.profiles WHERE school_id = %s AND role IN ('teacher', 'faculty', 'instructor', 'staff') LIMIT 2;", (school_id,))
    if len(staff_rows) < 2:
        staff_rows = await exec_sql("SELECT id, full_name FROM public.profiles WHERE role IN ('teacher', 'faculty', 'instructor', 'staff') LIMIT 2;")
        for s in staff_rows:
            await exec_sql("UPDATE public.profiles SET school_id = %s WHERE id = %s;", (school_id, str(s["id"])))

    assert len(staff_rows) >= 2, "Need at least 2 staff profiles for testing"
    emp1_id = str(staff_rows[0]["id"])
    emp1_name = staff_rows[0]["full_name"]
    emp2_id = str(staff_rows[1]["id"])
    emp2_name = staff_rows[1]["full_name"]

    # Assign emp1 to report to manager_id
    await exec_sql("UPDATE public.profiles SET school_id = %s, manager_id = %s::UUID WHERE id = %s::UUID;", (school_id, manager_id, emp1_id))
    # Ensure emp2 does NOT report to manager_id
    await exec_sql("UPDATE public.profiles SET school_id = %s, manager_id = NULL WHERE id = %s::UUID;", (school_id, emp2_id))

    logger.info(f"Using Manager: {manager_name} ({manager_id})")
    logger.info(f"Direct Report: {emp1_name} ({emp1_id})")
    logger.info(f"Non-Direct Report: {emp2_name} ({emp2_id})")

    # -------------------------------------------------------------------------
    # TEST 1: Manager Status Check
    # -------------------------------------------------------------------------
    logger.info("\n--- TEST 1: Checking Manager Status API ---")
    mgr_status = await get_manager_status(current_user=user_dict, school_id=school_id)
    assert mgr_status["data"]["is_manager"] is True
    assert mgr_status["data"]["direct_reports_count"] >= 1
    logger.info(f"✅ Manager Status verified: is_manager={mgr_status['data']['is_manager']}, direct_reports={mgr_status['data']['direct_reports_count']}")

    # -------------------------------------------------------------------------
    # TEST 2: Fetch All Staff (as Super Admin) vs My Direct Reports Only
    # -------------------------------------------------------------------------
    logger.info("\n--- TEST 2: Fetching Roster (All Staff vs Direct Reports) ---")
    admin_dict = {
        "id": manager_id,
        "email": "admin@edushamiit.com",
        "role": "super_admin",
        "school_id": school_id
    }
    all_roster = await get_staff_attendance(
        attendance_date=test_date,
        department="ALL",
        role="ALL",
        status="ALL",
        search="",
        page=1,
        page_size=50,
        manager_id=None,
        current_user=admin_dict,
        school_id=school_id
    )
    all_staff_ids = [str(s.get("employee_id") or s.get("id") or s.get("user_id")) for s in all_roster["data"]["staff"]]
    logger.info(f"Total All Staff in Roster: {len(all_staff_ids)}")
    assert emp1_id in all_staff_ids
    assert emp2_id in all_staff_ids

    # Query with manager_id='MY_REPORTS' (using manager_id filter)
    my_roster = await get_staff_attendance(
        attendance_date=test_date,
        department="ALL",
        role="ALL",
        status="ALL",
        search="",
        page=1,
        page_size=50,
        manager_id=manager_id,
        current_user=admin_dict,
        school_id=school_id
    )
    my_staff_ids = [str(s.get("employee_id") or s.get("id") or s.get("user_id")) for s in my_roster["data"]["staff"]]
    logger.info(f"Total Direct Reports in Roster: {len(my_staff_ids)}")
    assert emp1_id in my_staff_ids
    assert emp2_id not in my_staff_ids, "Non-direct report should not appear when filtered by manager"
    logger.info("✅ Verified: 'My Direct Reports Only' strictly filters staff where manager_id matches logged-in manager!")

    # -------------------------------------------------------------------------
    # TEST 3: Save Staff Attendance with Check-In, Check-Out, Status & Remarks
    # -------------------------------------------------------------------------
    logger.info("\n--- TEST 3: Saving Staff Attendance (Check-In/Out + Remarks) ---")
    save_res = await save_staff_attendance(
        payload=SaveStaffAttendanceRequest(
            attendance_date=test_date,
            records=[
                StaffAttendanceItemPayload(
                    employee_id=uuid.UUID(emp1_id),
                    status="PRESENT",
                    check_in_time="08:30:00",
                    check_out_time="16:30:00",
                    is_wfh=False,
                    remarks="Official duty in morning, present on time"
                ),
                StaffAttendanceItemPayload(
                    employee_id=uuid.UUID(emp2_id),
                    status="LATE",
                    check_in_time="09:45:00",
                    check_out_time="17:00:00",
                    is_wfh=False,
                    remarks="Approved late arrival due to heavy rain"
                ),
            ]
        ),
        current_user=user_dict,
        school_id=school_id
    )
    assert save_res["success"] is True
    logger.info(f"✅ Save API Response: {save_res}")

    # -------------------------------------------------------------------------
    # TEST 4: Verify Saved Data from DB Roster
    # -------------------------------------------------------------------------
    logger.info("\n--- TEST 4: Verifying Saved Data in Database ---")
    verify_roster = await get_staff_attendance(
        attendance_date=test_date,
        department="ALL",
        role="ALL",
        status="ALL",
        search="",
        page=1,
        page_size=50,
        manager_id=None,
        current_user=admin_dict,
        school_id=school_id
    )
    emp1_saved = next(s for s in verify_roster["data"]["staff"] if s["employee_id"] == emp1_id)
    emp2_saved = next(s for s in verify_roster["data"]["staff"] if s["employee_id"] == emp2_id)

    assert emp1_saved["status"] == "PRESENT"
    assert "08:30" in str(emp1_saved["check_in_time"])
    assert "16:30" in str(emp1_saved["check_out_time"])
    assert emp1_saved["remarks"] == "Official duty in morning, present on time"

    assert emp2_saved["status"] == "LATE"
    assert "09:45" in str(emp2_saved["check_in_time"])
    assert "17:00" in str(emp2_saved["check_out_time"])
    assert emp2_saved["remarks"] == "Approved late arrival due to heavy rain"

    logger.info(f"✅ Verified: {emp1_name} -> Status: {emp1_saved['status']}, Check-In: {emp1_saved['check_in_time']}, Check-Out: {emp1_saved['check_out_time']}, Remarks: {emp1_saved['remarks']}")
    logger.info(f"✅ Verified: {emp2_name} -> Status: {emp2_saved['status']}, Check-In: {emp2_saved['check_in_time']}, Check-Out: {emp2_saved['check_out_time']}, Remarks: {emp2_saved['remarks']}")

    logger.info("\n==========================================================================")
    logger.info("  🎉 ALL STAFF ATTENDANCE, TIME PICKER & MANAGER FILTER TESTS PASSED 100%! ")
    logger.info("==========================================================================")

if __name__ == "__main__":
    asyncio.run(run_tests())
