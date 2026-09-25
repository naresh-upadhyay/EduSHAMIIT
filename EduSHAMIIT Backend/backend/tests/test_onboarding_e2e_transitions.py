"""
End-to-End Onboarding Stage Transition & Reminder Verification Test for EduSHAMIIT ERP.

Verifies:
1. Creation of test onboarding record with checklist items (documents and tasks).
2. Step-by-step pipeline transitions through all 6 stages:
   'Offer Accepted' -> 'Document Collection' -> 'Orientation' -> 'IT Setup' -> 'Training' -> 'Completed'.
3. Automatic status synchronization ('Pending' -> 'In Progress' -> 'Completed').
4. Onboarding activity audit logging for every stage transition.
5. Onboarding reminder dispatch endpoint with pending documents & tasks aggregation.
6. Error handling for invalid stages and non-existent records.
"""

import os
import sys
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import asyncio
import uuid
import datetime
from datetime import date, timedelta
from fastapi import HTTPException

from app.api.recruitment import exec_sql
from app.api.onboarding import (
    update_onboarding_stage,
    update_onboarding_status,
    send_reminder,
    UpdateStageRequest,
    UpdateStatusRequest,
    SendReminderRequest
)

ADMIN_USER = {
    "id": "11111111-1111-1111-1111-111111111111",
    "email": "admin@edushamiit.com",
    "role": "admin",
    "school_id": "11111111-1111-1111-1111-111111111111"
}
SCHOOL_ID = "11111111-1111-1111-1111-111111111111"


async def run_e2e_onboarding_test():
    print("=" * 80)
    print("STARTING ONBOARDING STAGE TRANSITION & REMINDER END-TO-END TEST")
    print("=" * 80)

    test_email = "test.e2e.onboarding@shamiit.edu"
    test_code = "EMP-TEST-999"

    try:
        # Step 0: Cleanup previous test data
        print("\n--- STEP 0: CLEANUP PREVIOUS TEST DATA ---")
        await exec_sql("DELETE FROM public.onboarding_activities WHERE onboarding_id IN (SELECT id FROM public.employee_onboarding WHERE onboarding_code = %s);", (test_code,), fetch=False)
        await exec_sql("DELETE FROM public.onboarding_documents WHERE onboarding_id IN (SELECT id FROM public.employee_onboarding WHERE onboarding_code = %s);", (test_code,), fetch=False)
        await exec_sql("DELETE FROM public.onboarding_tasks WHERE onboarding_id IN (SELECT id FROM public.employee_onboarding WHERE onboarding_code = %s);", (test_code,), fetch=False)
        await exec_sql("DELETE FROM public.employee_onboarding WHERE onboarding_code = %s;", (test_code,), fetch=False)
        await exec_sql("DELETE FROM public.recruitment_candidates WHERE email = %s;", (test_email,), fetch=False)
        print("  ✓ Cleanup complete.")

        # Step 1: Create Candidate & Onboarding Record
        print("\n--- STEP 1: CREATE TEST CANDIDATE & ONBOARDING RECORD ---")
        cand_res = await exec_sql("""
            INSERT INTO public.recruitment_candidates (
                school_id, full_name, email, phone, candidate_code
            ) VALUES (
                %s, 'Vinay Onboarding Test', %s, '9876543210', 'CAND-TEST-999'
            ) RETURNING id;
        """, (SCHOOL_ID, test_email))
        cand_id = str(cand_res[0]["id"])

        test_joining_date = date.today() + timedelta(days=7)
        onb_res = await exec_sql("""
            INSERT INTO public.employee_onboarding (
                school_id, candidate_id, onboarding_code, department, designation,
                employment_type, stage, status, joining_date, expected_joining_date, reporting_time,
                reporting_location, joining_status
            ) VALUES (
                %s, %s, %s, 'Mathematics', 'Math Teacher',
                'Full-time', 'Offer Accepted', 'Pending', %s, %s, '09:00 AM',
                'Main Campus - Block A', 'Expected'
            ) RETURNING id;
        """, (SCHOOL_ID, cand_id, test_code, test_joining_date, test_joining_date))
        onboarding_id = str(onb_res[0]["id"])
        print(f"  ✓ Created Onboarding Record: ID={onboarding_id}, Code={test_code}")

        # Add sample documents (1 mandatory unverified, 1 verified)
        await exec_sql("""
            INSERT INTO public.onboarding_documents (school_id, onboarding_id, document_name, is_mandatory, status)
            VALUES (%s, %s, 'Aadhaar / National ID', true, 'Pending'),
                   (%s, %s, 'Degree Certificate', true, 'Pending');
        """, (SCHOOL_ID, onboarding_id, SCHOOL_ID, onboarding_id), fetch=False)

        # Add sample tasks (1 mandatory pending)
        await exec_sql("""
            INSERT INTO public.onboarding_tasks (school_id, onboarding_id, title, is_mandatory, status, due_date)
            VALUES (%s, %s, 'Complete HR Induction Program', true, 'Pending', %s);
        """, (SCHOOL_ID, onboarding_id, date.today() + timedelta(days=3)), fetch=False)
        print("  ✓ Seeded test documents and tasks.")

        # Step 2: Test Stage Progression Pipeline
        print("\n--- STEP 2: TEST STAGE TRANSITIONS & STATUS AUTO-SYNC ---")
        transitions = [
            ("Document Collection", "In Progress", "Candidate accepted offer; collecting KYC."),
            ("Orientation", "In Progress", "Documents verified; scheduled for induction."),
            ("IT Setup", "In Progress", "Orientation completed; IT assets allocation in progress."),
            ("Training", "In Progress", "Laptop issued; department training initiated."),
            ("Completed", "Completed", "Training completed; employee fully active.")
        ]

        for target_stage, expected_status, notes in transitions:
            print(f"  -> Transitioning to '{target_stage}'...")
            res = await update_onboarding_stage(
                onboarding_id=onboarding_id,
                payload=UpdateStageRequest(stage=target_stage, notes=notes, send_email=False),
                user=ADMIN_USER,
                school_id=SCHOOL_ID
            )
            assert res["success"] is True, f"Failed transition to {target_stage}: {res}"

            # Verify in DB
            db_check = await exec_sql("SELECT stage, status FROM public.employee_onboarding WHERE id = %s;", (onboarding_id,))
            current_stage = db_check[0]["stage"]
            current_status = db_check[0]["status"]
            assert current_stage == target_stage, f"Expected stage '{target_stage}', got '{current_stage}'"
            assert current_status == expected_status, f"Expected status '{expected_status}', got '{current_status}'"
            print(f"     ✓ Stage={current_stage}, Status={current_status}")

            # Verify activity log
            acts = await exec_sql("SELECT action, description FROM public.onboarding_activities WHERE onboarding_id = %s ORDER BY created_at DESC LIMIT 1;", (onboarding_id,))
            assert acts and acts[0]["action"] == "Stage Changed", f"Activity log missing for {target_stage}"
            print(f"     ✓ Logged: {acts[0]['description']}")

        # Step 3: Test Reminder Endpoint with Pending Docs & Tasks
        print("\n--- STEP 3: TEST ONBOARDING REMINDER DISPATCH ---")
        reminder_res = await send_reminder(
            onboarding_id=onboarding_id,
            payload=SendReminderRequest(
                reminder_type="documents",
                custom_message="Please bring original degree certificates.",
                send_email=False
            ),
            user=ADMIN_USER,
            school_id=SCHOOL_ID
        )
        assert reminder_res["success"] is True, f"Reminder endpoint failed: {reminder_res}"
        data = reminder_res.get("data", {})
        print(f"  ✓ Reminder Result: {reminder_res['message']}")
        print(f"     Pending Docs Count: {data.get('pending_documents_count')}")
        print(f"     Pending Tasks Count: {data.get('pending_tasks_count')}")
        assert data.get("pending_documents_count") == 2, f"Expected 2 pending docs, got {data.get('pending_documents_count')}"
        assert data.get("pending_tasks_count") == 1, f"Expected 1 pending task, got {data.get('pending_tasks_count')}"

        # Step 4: Test Edge Cases & Validation
        print("\n--- STEP 4: TEST EDGE CASES & VALIDATION ---")
        try:
            await update_onboarding_stage(
                onboarding_id=onboarding_id,
                payload=UpdateStageRequest(stage="NonExistentStage", send_email=False),
                user=ADMIN_USER,
                school_id=SCHOOL_ID
            )
            assert False, "Should have rejected invalid stage!"
        except HTTPException as e:
            assert e.status_code == 400
            print(f"  ✓ Successfully rejected invalid stage (HTTP 400: {e.detail})")

        try:
            fake_id = str(uuid.uuid4())
            await update_onboarding_stage(
                onboarding_id=fake_id,
                payload=UpdateStageRequest(stage="Orientation", send_email=False),
                user=ADMIN_USER,
                school_id=SCHOOL_ID
            )
            assert False, "Should have 404'd on fake onboarding id!"
        except HTTPException as e:
            assert e.status_code == 404
            print(f"  ✓ Successfully returned 404 for non-existent record: {e.detail}")

        # Step 5: Final Cleanup
        print("\n--- STEP 5: CLEANUP TEST DATA ---")
        await exec_sql("DELETE FROM public.onboarding_activities WHERE onboarding_id = %s;", (onboarding_id,), fetch=False)
        await exec_sql("DELETE FROM public.onboarding_documents WHERE onboarding_id = %s;", (onboarding_id,), fetch=False)
        await exec_sql("DELETE FROM public.onboarding_tasks WHERE onboarding_id = %s;", (onboarding_id,), fetch=False)
        await exec_sql("DELETE FROM public.employee_onboarding WHERE id = %s;", (onboarding_id,), fetch=False)
        await exec_sql("DELETE FROM public.recruitment_candidates WHERE id = %s;", (cand_id,), fetch=False)
        print("  ✓ Cleanup complete.")

        print("\n" + "=" * 80)
        print("ALL ONBOARDING STAGE TRANSITION & REMINDER TESTS PASSED SUCCESSFULLY!")
        print("=" * 80)

    except Exception as e:
        print(f"\n❌ TEST FAILED WITH ERROR: {e}")
        import traceback
        traceback.print_exc()
        raise e

if __name__ == "__main__":
    asyncio.run(run_e2e_onboarding_test())
