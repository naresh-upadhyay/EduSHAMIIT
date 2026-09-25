#!/usr/bin/env python3
"""
Comprehensive End-to-End Edge Case Test Suite for HR Training & Learning.
Validates:
1. Program Detail & KPI Aggregation (0 sessions/materials/attendance, math precision, div-by-zero guards)
2. Assessment & Scoring (0 participants, boundary thresholds 0/100%, pass/fail thresholds, bulk grading, audit logging)
3. Feedback & Reviews (0 reviews default 0.0, star distribution math, extreme ratings 1/5)
4. Certificate Management (KPIs, issuance, idempotent upsert, revocation, ReportLab PDF generation)
5. Session Attendance (Upsert idempotency, progress updates)
6. Participant Assignment (Duplicate assignment prevention, count sync)
7. Multi-Tenant School Isolation & Security
"""

import sys
import os
import uuid
import json
import asyncio
from datetime import date, timedelta

# Ensure python path includes root app directory
sys.path.insert(0, '/app')
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../../..')))
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

# When run inside container or with backend on path
try:
    from app.api.recruitment import exec_sql
    from app.api.hr_training import _generate_certificate_pdf_bytes
except ImportError:
    print("❌ Cannot import app modules. Please execute this script inside the edushamiit-api container.")
    sys.exit(1)



class TestRunner:
    def __init__(self):
        self.passed = 0
        self.failed = 0
        self.errors = []

    def assert_true(self, condition: bool, test_name: str, details: str = ""):
        if condition:
            self.passed += 1
            print(f"  ✅ PASS: {test_name}")
        else:
            self.failed += 1
            msg = f"  ❌ FAIL: {test_name} - {details}"
            print(msg)
            self.errors.append(msg)

    def assert_equal(self, actual, expected, test_name: str):
        self.assert_true(
            actual == expected,
            test_name,
            f"Expected: {expected!r}, Got: {actual!r}"
        )

    def print_summary(self):
        print("\n" + "=" * 70)
        print(f"TEST RESULTS: {self.passed} Passed, {self.failed} Failed")
        print("=" * 70)
        if self.errors:
            print("\nFailures:")
            for err in self.errors:
                print(err)
        return self.failed == 0


async def run_all_edge_case_tests():
    runner = TestRunner()

    print("======================================================================")
    print("🚀 STARTING HR TRAINING & LEARNING END-TO-END EDGE CASE TEST SUITE")
    print("======================================================================")

    # Setup Test Tenant & Fixtures
    school_res = await exec_sql("SELECT id FROM public.schools LIMIT 1;")
    if not school_res:
        print("❌ No school found in database. Cannot run tests.")
        return False
    school_id = str(school_res[0]["id"])
    fake_school_id = "99999999-9999-9999-9999-999999999999"

    # Fetch 2 test employees from profiles
    emp_res = await exec_sql(
        "SELECT id, full_name, employee_id, department, designation FROM public.profiles WHERE school_id = %s LIMIT 2;",
        (school_id,)
    )
    if len(emp_res) < 2:
        print("❌ Need at least 2 profiles in school to run test suite.")
        return False
    emp1 = emp_res[0]
    emp2 = emp_res[1]
    emp1_id = str(emp1["id"])
    emp2_id = str(emp2["id"])

    # Create a clean isolated test training program
    test_prog_code = f"TEST-EDGE-{uuid.uuid4().hex[:6].upper()}"
    create_sql = """
        INSERT INTO public.hr_training_programs (
            school_id, program_code, title, training_type, start_date, duration_hours,
            assessment_type, passing_score, has_certificate, status
        ) VALUES (
            %s, %s, 'Edge Case Testing Program', 'Technical', CURRENT_DATE, 4.0,
            'Quiz', 70.0, TRUE, 'UPCOMING'
        ) RETURNING id;
    """
    prog_res = await exec_sql(create_sql, (school_id, test_prog_code))
    prog_id = str(prog_res[0]["id"])
    print(f"📌 Created Isolated Test Program: {prog_id} ({test_prog_code})")

    try:
        # =====================================================================
        # SUITE 1: PROGRAM DETAIL & ATTENDANCE AGGREGATION EDGE CASES
        # =====================================================================
        print("\n--- SUITE 1: Program Detail & Attendance Aggregation ---")

        # 1.1 Fresh Program with 0 sessions, 0 materials, 0 attendance
        res1 = await exec_sql(
            "SELECT public.fn_hr_training_get_program_detail(%s::uuid, %s::uuid) as d;",
            (prog_id, school_id)
        )
        d1 = res1[0]["d"] if res1 else None
        runner.assert_true(d1 is not None, "1.1 Program detail returns non-null JSON")
        runner.assert_equal(d1.get("sessions"), [], "1.1 Sessions list is empty []")
        runner.assert_equal(d1.get("materials"), [], "1.1 Materials list is empty []")
        runner.assert_equal(d1.get("passing_score"), 70.0, "1.1 Default passing score is 70.0")

        att_sum = d1.get("attendance_summary", {})
        runner.assert_equal(att_sum.get("compliance_rate"), 0.0, "1.1 Compliance rate 0.0 on zero attendance (no div/0)")
        runner.assert_equal(att_sum.get("total_records"), 0, "1.1 Total attendance records is 0")
        runner.assert_equal(att_sum.get("has_records"), False, "1.1 has_records is False")

        # 1.2 Multi-tenant isolation: Querying with wrong school_id must return NULL
        res_iso = await exec_sql(
            "SELECT public.fn_hr_training_get_program_detail(%s::uuid, %s::uuid) as d;",
            (prog_id, fake_school_id)
        )
        runner.assert_true(res_iso[0]["d"] is None, "1.2 Tenant isolation: wrong school_id returns NULL")

        # =====================================================================
        # SUITE 2: PARTICIPANT ASSIGNMENT & DUPLICATE PREVENTION
        # =====================================================================
        print("\n--- SUITE 2: Participant Assignment & Duplicate Prevention ---")

        # 2.1 Assign 2 employees
        assign_res = await exec_sql(
            "SELECT public.fn_hr_training_assign_participants(%s::uuid, %s::uuid, %s::uuid[], %s, %s::uuid, %s) as d;",
            (prog_id, school_id, [emp1_id, emp2_id], False, None, "TestRunner")
        )
        runner.assert_true(assign_res[0]["d"]["success"], "2.1 Participant assignment returns success")
        runner.assert_equal(assign_res[0]["d"]["assigned_count"], 2, "2.1 Assigned 2 employees initially")

        # 2.2 Re-assign same employees: must be idempotent and not create duplicate rows
        reassign_res = await exec_sql(
            "SELECT public.fn_hr_training_assign_participants(%s::uuid, %s::uuid, %s::uuid[], %s, %s::uuid, %s) as d;",
            (prog_id, school_id, [emp1_id, emp2_id], False, None, "TestRunner")
        )
        runner.assert_equal(reassign_res[0]["d"]["assigned_count"], 0, "2.2 Duplicate assignment prevents duplicates (assigned_count = 0)")

        # Verify enrolled_count on program
        prog_chk = await exec_sql("SELECT enrolled_count FROM public.hr_training_programs WHERE id = %s;", (prog_id,))
        runner.assert_equal(prog_chk[0]["enrolled_count"], 2, "2.2 Program enrolled_count is exactly 2")

        # Get enrollment IDs
        enr_rows = await exec_sql(
            "SELECT id, employee_id FROM public.hr_training_enrollments WHERE program_id = %s ORDER BY employee_id;",
            (prog_id,)
        )
        enr1_id = str(enr_rows[0]["id"])
        enr2_id = str(enr_rows[1]["id"])

        # =====================================================================
        # SUITE 3: ASSESSMENT, SCORING & THRESHOLD BOUNDARY EDGE CASES
        # =====================================================================
        print("\n--- SUITE 3: Assessment, Scoring & Threshold Boundaries ---")

        # 3.1 Initial Assessment KPIs before any scoring
        asmt1 = await exec_sql(
            "SELECT public.fn_hr_training_get_assessment_data(%s::uuid, %s::uuid) as d;",
            (prog_id, school_id)
        )
        kpis1 = asmt1[0]["d"]["kpis"]
        runner.assert_equal(kpis1["total_participants"], 2, "3.1 Assessment total_participants is 2")
        runner.assert_equal(kpis1["passed_count"], 0, "3.1 Initial passed_count is 0")
        runner.assert_equal(kpis1["failed_count"], 0, "3.1 Initial failed_count is 0")
        runner.assert_equal(kpis1["pending_count"], 2, "3.1 Initial pending_count is 2")
        runner.assert_equal(kpis1["average_score"], 0.0, "3.1 Average score is 0.0 when no scores recorded")

        # 3.2 Update Assessment Criteria (Custom threshold: 80.0%)
        cfg_res = await exec_sql(
            "SELECT public.fn_hr_training_update_assessment_settings(%s::uuid, %s::uuid, %s, %s, %s::uuid, %s) as d;",
            (prog_id, school_id, "Practical Exam", 80.0, None, "TestRunner")
        )
        runner.assert_true(cfg_res[0]["d"]["success"], "3.2 Assessment criteria update returns success")
        runner.assert_equal(float(cfg_res[0]["d"]["data"]["passing_score"]), 80.0, "3.2 Passing threshold updated to 80.0%")

        # 3.3 Score Evaluation - Boundary test:
        # emp1 gets 80.0% -> PASSED (exactly on threshold)
        sc1 = await exec_sql(
            "SELECT public.fn_hr_training_record_score(%s::uuid, %s::uuid, %s::uuid, %s, %s, %s, %s::uuid, %s) as d;",
            (prog_id, enr1_id, school_id, 80.0, "PASSED", 100.0, None, "TestRunner")
        )
        runner.assert_true(sc1[0]["d"]["success"], "3.3 Score 80.0% on 80.0% threshold recorded successfully")
        runner.assert_equal(sc1[0]["d"]["data"]["status"], "COMPLETED", "3.3 Passing score auto-marks participant COMPLETED")

        # emp2 gets 79.9% -> FAILED (just below threshold)
        sc2 = await exec_sql(
            "SELECT public.fn_hr_training_record_score(%s::uuid, %s::uuid, %s::uuid, %s, %s, %s, %s::uuid, %s) as d;",
            (prog_id, enr2_id, school_id, 79.9, "FAILED", 60.0, None, "TestRunner")
        )
        runner.assert_true(sc2[0]["d"]["success"], "3.3 Score 79.9% (below threshold) recorded")
        runner.assert_equal(sc2[0]["d"]["data"]["assessment_status"], "FAILED", "3.3 Below-threshold status is FAILED")

        # 3.4 Verify Recalculated Assessment KPIs
        asmt2 = await exec_sql(
            "SELECT public.fn_hr_training_get_assessment_data(%s::uuid, %s::uuid) as d;",
            (prog_id, school_id)
        )
        kpis2 = asmt2[0]["d"]["kpis"]
        runner.assert_equal(kpis2["passed_count"], 1, "3.4 Passed count is 1")
        runner.assert_equal(kpis2["failed_count"], 1, "3.4 Failed count is 1")
        runner.assert_equal(kpis2["pending_count"], 0, "3.4 Pending count is 0")
        # Avg of 80.0 and 79.9 = 79.95 -> rounded to 80.0
        runner.assert_true(79.9 <= kpis2["average_score"] <= 80.0, "3.4 Average score accurately computed")

        # 3.5 Bulk Evaluate with pass_all
        bulk_res = await exec_sql(
            "SELECT public.fn_hr_training_bulk_evaluate(%s::uuid, %s::uuid, %s, %s, %s::uuid[], %s::uuid, %s) as d;",
            (prog_id, school_id, 92.0, "PASSED", None, None, "TestRunner")
        )
        runner.assert_true(bulk_res[0]["d"]["success"], "3.5 Bulk evaluate returns success")
        runner.assert_equal(bulk_res[0]["d"]["affected_count"], 2, "3.5 Bulk evaluate affected all 2 participants")

        # Verify both are now passed and program completion rate is 100%
        prog_comp = await exec_sql("SELECT completed_count, completion_rate FROM public.hr_training_programs WHERE id = %s;", (prog_id,))
        runner.assert_equal(prog_comp[0]["completed_count"], 2, "3.5 Program completed_count updated to 2")
        runner.assert_equal(float(prog_comp[0]["completion_rate"]), 100.0, "3.5 Program completion_rate updated to 100.0%")

        # =====================================================================
        # SUITE 4: CERTIFICATES & OFFICIAL PDF GENERATION
        # =====================================================================
        print("\n--- SUITE 4: Certificates & Official PDF Generation ---")

        # 4.1 Check initial certificate KPIs
        cert_kpi1 = await exec_sql(
            "SELECT public.fn_hr_training_get_certificates(%s::uuid, %s::uuid, %s, %s) as d;",
            (prog_id, school_id, None, None)
        )
        ck1 = cert_kpi1[0]["d"]["kpis"]
        runner.assert_equal(ck1["total_issued"], 0, "4.1 Initial total_issued certificates is 0")
        runner.assert_equal(ck1["eligible_to_issue"], 2, "4.1 Both completed participants are eligible to issue")

        # 4.2 Issue certificate to emp1
        issue_res = await exec_sql(
            "SELECT public.fn_hr_training_issue_certificate(%s::uuid, %s::uuid, %s::uuid, %s, %s, %s::uuid, %s) as d;",
            (prog_id, emp1_id, school_id, None, 12, None, "TestRunner")
        )
        runner.assert_true(issue_res[0]["d"]["success"], "4.2 Issue certificate returns success")
        cert1_id = str(issue_res[0]["d"]["data"]["id"])
        cert1_no = str(issue_res[0]["d"]["data"]["certificate_number"])
        runner.assert_true(cert1_no.startswith("CERT-TRN-"), "4.2 Auto-generated certificate number has CERT-TRN- prefix")

        # 4.3 Idempotent re-issuance (same program + employee)
        reissue_res = await exec_sql(
            "SELECT public.fn_hr_training_issue_certificate(%s::uuid, %s::uuid, %s::uuid, %s, %s, %s::uuid, %s) as d;",
            (prog_id, emp1_id, school_id, cert1_no, 12, None, "TestRunner")
        )
        runner.assert_true(reissue_res[0]["d"]["success"], "4.3 Re-issuing certificate handles conflict idempotently")
        runner.assert_equal(str(reissue_res[0]["d"]["data"]["id"]), cert1_id, "4.3 Same certificate ID preserved on upsert")

        # 4.4 Check updated KPIs: eligible should now be 1, total_issued should be 1
        cert_kpi2 = await exec_sql(
            "SELECT public.fn_hr_training_get_certificates(%s::uuid, %s::uuid, %s, %s) as d;",
            (prog_id, school_id, None, None)
        )
        ck2 = cert_kpi2[0]["d"]["kpis"]
        runner.assert_equal(ck2["total_issued"], 1, "4.4 Total issued is now 1")
        runner.assert_equal(ck2["valid_count"], 1, "4.4 Valid count is 1")
        runner.assert_equal(ck2["eligible_to_issue"], 1, "4.4 Eligible to issue decreased to 1")

        # 4.5 Generate Official PDF bytes
        pdf_data_res = await exec_sql(
            "SELECT public.fn_hr_training_get_certificate_pdf_data(%s::uuid, %s::uuid) as d;",
            (cert1_id, school_id)
        )
        cert_pdf_meta = pdf_data_res[0]["d"]
        runner.assert_true(cert_pdf_meta is not None, "4.5 Certificate PDF metadata retrieved")
        pdf_bytes = _generate_certificate_pdf_bytes(cert_pdf_meta, school_name="EduSHAMIIT Test Academy")
        runner.assert_true(len(pdf_bytes) > 1000, "4.5 Generated PDF length > 1KB")
        runner.assert_true(pdf_bytes.startswith(b"%PDF"), "4.5 PDF header signature valid (%PDF)")

        # 4.6 Revoke Certificate
        revoke_res = await exec_sql(
            "SELECT public.fn_hr_training_revoke_certificate(%s::uuid, %s::uuid, %s::uuid, %s) as d;",
            (cert1_id, school_id, None, "TestRunner")
        )
        runner.assert_true(revoke_res[0]["d"]["success"], "4.6 Revoke certificate returns success")

        # Check KPIs after revocation
        cert_kpi3 = await exec_sql(
            "SELECT public.fn_hr_training_get_certificates(%s::uuid, %s::uuid, %s, %s) as d;",
            (prog_id, school_id, None, None)
        )
        ck3 = cert_kpi3[0]["d"]["kpis"]
        runner.assert_equal(ck3["valid_count"], 0, "4.6 Valid certificates count is now 0")
        runner.assert_equal(ck3["expired_revoked_count"], 1, "4.6 Expired/revoked count is now 1")

        # =====================================================================
        # SUITE 5: FEEDBACK, RATINGS & DISTRIBUTION MATH
        # =====================================================================
        print("\n--- SUITE 5: Feedback, Ratings & Distribution Math ---")

        # 5.1 Zero reviews: must return 0.0 and no division by zero
        fb1 = await exec_sql(
            "SELECT public.fn_hr_training_get_feedback(%s::uuid, %s::uuid) as d;",
            (prog_id, school_id)
        )
        fbd1 = fb1[0]["d"]
        runner.assert_equal(fbd1["total_reviews"], 0, "5.1 Zero reviews: total_reviews is 0")
        runner.assert_equal(fbd1["avg_rating"], 0.0, "5.1 Zero reviews: avg_rating is 0.0 (no mock 4.8)")
        runner.assert_equal(fbd1["star_counts"]["5"], 0, "5.1 Zero reviews: 5★ count is 0")

        # 5.2 Submit Review 1: 5 Stars across the board
        sfb1 = await exec_sql(
            "SELECT public.fn_hr_training_submit_feedback(%s::uuid, %s::uuid, %s::uuid, %s, %s, %s, %s, %s) as d;",
            (prog_id, school_id, emp1_id, emp1["full_name"], 5, 5, 5, "Outstanding training!")
        )
        runner.assert_true(sfb1[0]["d"]["success"], "5.2 Submit 5-star review returns success")

        # 5.3 Submit Review 2: 1 Star (lowest boundary)
        sfb2 = await exec_sql(
            "SELECT public.fn_hr_training_submit_feedback(%s::uuid, %s::uuid, %s::uuid, %s, %s, %s, %s, %s) as d;",
            (prog_id, school_id, emp2_id, emp2["full_name"], 1, 2, 1, "Needs improvement on pacing.")
        )
        runner.assert_true(sfb2[0]["d"]["success"], "5.3 Submit 1-star review returns success")

        # 5.4 Check Computed Averages: (5 + 1) / 2 = 3.0
        fb2 = await exec_sql(
            "SELECT public.fn_hr_training_get_feedback(%s::uuid, %s::uuid) as d;",
            (prog_id, school_id)
        )
        fbd2 = fb2[0]["d"]
        runner.assert_equal(fbd2["total_reviews"], 2, "5.4 Total reviews is 2")
        runner.assert_equal(fbd2["avg_rating"], 3.0, "5.4 Average rating is (5+1)/2 = 3.0")
        runner.assert_equal(fbd2["avg_trainer_rating"], 3.5, "5.4 Trainer rating is (5+2)/2 = 3.5")
        runner.assert_equal(fbd2["avg_content_rating"], 3.0, "5.4 Content rating is (5+1)/2 = 3.0")
        runner.assert_equal(fbd2["star_counts"]["5"], 1, "5.4 5-star count is 1")
        runner.assert_equal(fbd2["star_counts"]["1"], 1, "5.4 1-star count is 1")
        runner.assert_equal(fbd2["star_counts"]["4"], 0, "5.4 4-star count is 0")

        # =====================================================================
        # SUITE 6: SESSION ATTENDANCE & UPSERT IDEMPOTENCY
        # =====================================================================
        print("\n--- SUITE 6: Session Attendance & Upsert Idempotency ---")

        # Create test session
        sess_res = await exec_sql("""
            INSERT INTO public.hr_training_sessions (
                school_id, program_id, session_title, session_date, start_time, end_time, status
            ) VALUES (
                %s, %s, 'Interactive Session 1', CURRENT_DATE, '10:00:00', '12:00:00', 'SCHEDULED'
            ) RETURNING id;
        """, (school_id, prog_id))
        sess_id = str(sess_res[0]["id"])

        # Record attendance: emp1 PRESENT, emp2 ABSENT
        att_payload = json.dumps([
            {"enrollment_id": enr1_id, "attendance_status": "PRESENT", "remarks": "On time"},
            {"enrollment_id": enr2_id, "attendance_status": "ABSENT", "remarks": "Excused sick leave"}
        ])
        att_res = await exec_sql(
            "SELECT public.fn_hr_training_record_session_attendance(%s::uuid, %s::uuid, %s::jsonb, %s::uuid) as d;",
            (sess_id, school_id, att_payload, None)
        )
        runner.assert_true(att_res[0]["d"]["success"], "6.1 Record session attendance returns success")
        runner.assert_equal(att_res[0]["d"]["updated_count"], 2, "6.1 Recorded attendance for 2 participants")

        # Upsert: Change emp2 from ABSENT to LATE
        att_update_payload = json.dumps([
            {"enrollment_id": enr2_id, "attendance_status": "LATE", "remarks": "Arrived 15 mins late"}
        ])
        att_up_res = await exec_sql(
            "SELECT public.fn_hr_training_record_session_attendance(%s::uuid, %s::uuid, %s::jsonb, %s::uuid) as d;",
            (sess_id, school_id, att_update_payload, None)
        )
        runner.assert_true(att_up_res[0]["d"]["success"], "6.2 Upsert attendance status returns success")

        # Verify updated attendance summary on program detail
        prog_det2 = await exec_sql(
            "SELECT public.fn_hr_training_get_program_detail(%s::uuid, %s::uuid) as d;",
            (prog_id, school_id)
        )
        att_sum2 = prog_det2[0]["d"]["attendance_summary"]
        runner.assert_equal(att_sum2["total_records"], 2, "6.2 Attendance total records is 2")
        runner.assert_equal(att_sum2["present_count"], 1, "6.2 Present count is 1")
        runner.assert_equal(att_sum2["late_count"], 1, "6.2 Late count is 1")
        runner.assert_equal(att_sum2["absent_count"], 0, "6.2 Absent count updated to 0")
        # Compliance: (1 + 1*0.5) / 2 * 100 = 75.0%
        runner.assert_equal(float(att_sum2["compliance_rate"]), 75.0, "6.2 Compliance rate correctly computed as 75.0%")

        # =====================================================================
        # SUITE 7: AUDIT LOGGING & ACTIVITY VERIFICATION
        # =====================================================================
        print("\n--- SUITE 7: Audit Activity Trail ---")

        act_rows = await exec_sql("""
            SELECT action, summary FROM public.hr_training_activity
            WHERE school_id = %s AND (entity_id = %s OR summary ILIKE %s)
            ORDER BY created_at DESC;
        """, (school_id, prog_id, f"%{test_prog_code}%"))

        actions = [a["action"] for a in act_rows]
        runner.assert_true(len(actions) > 0, "7.1 Audit logs created for training operations")
        runner.assert_true("ASSESSMENT_SETTINGS_UPDATED" in actions, "7.1 ASSESSMENT_SETTINGS_UPDATED logged")
        runner.assert_true("ASSESSMENT_RECORDED" in actions, "7.1 ASSESSMENT_RECORDED logged")
        runner.assert_true("BULK_ASSESSMENT_RECORDED" in actions, "7.1 BULK_ASSESSMENT_RECORDED logged")

    finally:
        # Clean up test artifacts
        print("\n🧹 Cleaning up test program and related records...")
        await exec_sql("DELETE FROM public.hr_training_programs WHERE id = %s;", (prog_id,), fetch=False)
        print("✅ Cleanup complete.")

    return runner.print_summary()


if __name__ == "__main__":
    success = asyncio.run(run_all_edge_case_tests())
    sys.exit(0 if success else 1)
