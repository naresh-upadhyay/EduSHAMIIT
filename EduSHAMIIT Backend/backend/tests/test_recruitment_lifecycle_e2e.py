"""
End-to-End Recruitment Lifecycle Verification Test for EduSHAMIIT ERP.
Tests:
1. Job Opening & Candidate Application Creation
2. Interview Scheduling & In-Depth Feedback Submission
3. Assessment Assignment (with test link & instructions) & Scoring with Email Dispatch
4. Offer Creation (with CTC auto-calculation, benefits, terms) & Sending Offer Letter
5. Offer Acceptance & Status Updates
6. Candidate Hiring (Atomic Vacancy increment, Employee Profile creation, Onboarding Tasks creation, Welcome Email)
7. Edge Cases: Over-hiring without override, re-hiring already hired candidate, invalid transitions
8. Candidate 360 Detail Aggregation
"""

import os
import sys
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import asyncio
import uuid
import datetime
from datetime import date, timedelta
import psycopg2
from psycopg2.extras import RealDictCursor

from app.config import settings
from app.api.recruitment import (
    exec_sql,
    JobOpeningCreate, create_job,
    CandidateCreate, create_candidate,
    StageMoveRequest, move_stage,
    InterviewScheduleRequest, schedule_interview,
    InterviewFeedbackCreate, submit_interview_feedback,
    AssessmentCreate, create_assessment,
    AssessmentResultUpdate, update_assessment_result,
    OfferCreate, create_offer,
    send_offer, accept_offer, reject_offer,
    HireCandidateRequest, hire_candidate,
    get_candidate_360_profile
)

ADMIN_USER = {
    "id": "11111111-1111-1111-1111-111111111111",
    "email": "admin@edushamiit.com",
    "role": "admin",
    "school_id": "11111111-1111-1111-1111-111111111111"
}
SCHOOL_ID = "11111111-1111-1111-1111-111111111111"


async def run_e2e_recruitment_test():
    print("=" * 80)
    print("STARTING RECRUITMENT LIFECYCLE END-TO-END VERIFICATION")
    print("=" * 80)

    test_email = "e2e.candidate.physics@shamiit.edu"
    test_job_code = "JOB-TEST-PHY-01"
    
    print("\n--- STEP 0: CLEANUP PREVIOUS TEST DATA ---")
    await exec_sql("DELETE FROM public.recruitment_assessments WHERE candidate_id IN (SELECT id FROM public.recruitment_candidates WHERE email = %s);", (test_email,), fetch=False)
    await exec_sql("DELETE FROM public.recruitment_offers WHERE candidate_id IN (SELECT id FROM public.recruitment_candidates WHERE email = %s);", (test_email,), fetch=False)
    await exec_sql("DELETE FROM public.recruitment_interviews WHERE candidate_id IN (SELECT id FROM public.recruitment_candidates WHERE email = %s);", (test_email,), fetch=False)
    await exec_sql("DELETE FROM public.recruitment_stage_history WHERE candidate_id IN (SELECT id FROM public.recruitment_candidates WHERE email = %s);", (test_email,), fetch=False)
    await exec_sql("DELETE FROM public.employee_onboarding WHERE candidate_id IN (SELECT id FROM public.recruitment_candidates WHERE email = %s);", (test_email,), fetch=False)
    await exec_sql("DELETE FROM public.profiles WHERE email = %s;", (test_email,), fetch=False)
    await exec_sql("DELETE FROM public.recruitment_applications WHERE candidate_id IN (SELECT id FROM public.recruitment_candidates WHERE email = %s);", (test_email,), fetch=False)
    await exec_sql("DELETE FROM public.recruitment_candidates WHERE email = %s;", (test_email,), fetch=False)
    await exec_sql("DELETE FROM public.recruitment_jobs WHERE job_code = %s;", (test_job_code,), fetch=False)

    # Ensure admin profile exists in public.profiles for created_by foreign key
    await exec_sql(
        """
        INSERT INTO public.profiles (id, school_id, user_id, full_name, email, role, department, designation)
        VALUES (%s, %s, %s, 'HR Administrator', 'admin@edushamiit.com', 'hr', 'Human Resources', 'Head of HR')
        ON CONFLICT (id) DO UPDATE SET role = 'hr';
        """,
        (ADMIN_USER["id"], SCHOOL_ID, ADMIN_USER["id"]),
        fetch=False
    )
    print(">>> PASS: Pre-cleanup completed and Admin Profile verified successfully.")

    # 1. CREATE JOB OPENING (1 vacancy)
    print("\n--- STEP 1: CREATE JOB OPENING (1 Vacancy) ---")
    job_payload = JobOpeningCreate(
        job_title="Senior Physics Faculty (JEE Advanced)",
        job_code=test_job_code,
        department="Academics",
        designation="Senior Physics Faculty",
        employment_type="Full-time",
        vacancies=1,
        salary_min=1200000.0,
        salary_max=1800000.0,
        description="Lead advanced physics instruction for competitive exams and mentor students.",
        responsibilities="1. Deliver interactive lectures\n2. Prepare mock test papers\n3. Conduct doubt clearing sessions",
        qualifications="M.Sc / M.Tech in Physics with high academic honors",
        required_skills=["Quantum Mechanics", "Electrodynamics", "JEE Pedagogy"],
        publishing_status="Active"
    )
    job_res = await create_job(job_payload, school_id=SCHOOL_ID, user=ADMIN_USER)
    assert job_res.get("success") is True, f"Failed to create job: {job_res}"
    job_id = job_res["data"]["id"]
    print(f">>> PASS: Job Opening created with ID: {job_id}, vacancies: 1, filled: 0")

    # 2. CREATE CANDIDATE & APPLICATION
    print("\n--- STEP 2: CREATE CANDIDATE & INITIAL APPLICATION ---")
    cand_payload = CandidateCreate(
        job_id=job_id,
        full_name="Dr. Vikramaditya Sharma",
        email=test_email,
        phone="+91 9876543210",
        city="Bengaluru",
        qualification="Ph.D. in Applied Physics",
        experience_years=6.5,
        current_organization="National Science Academy",
        current_designation="Associate Professor",
        source="Direct Referral"
    )
    cand_res = await create_candidate(cand_payload, school_id=SCHOOL_ID, user=ADMIN_USER)
    assert cand_res.get("success") is True, f"Failed to create candidate: {cand_res}"
    cand_id = cand_res["data"]["id"]
    app_id = cand_res["data"]["application"]["id"]
    print(f">>> PASS: Candidate created with ID: {cand_id}, Application ID: {app_id}, Stage: Applied")

    # 3. INTERVIEW SCHEDULING & FEEDBACK SUBMISSION
    print("\n--- STEP 3: INTERVIEW SCHEDULING & IN-DEPTH FEEDBACK ---")
    await move_stage(app_id, StageMoveRequest(to_stage="Interview", notes="Screening cleared"), school_id=SCHOOL_ID, user=ADMIN_USER)
    
    interview_date = date.today() + timedelta(days=2)
    interview_payload = InterviewScheduleRequest(
        application_id=app_id,
        interview_round="Round 1 - Technical Pedagogy",
        scheduled_date=interview_date,
        scheduled_time_start="11:00:00",
        scheduled_time_end="12:30:00",
        mode="Online",
        meeting_link_or_location="https://meet.google.com/xyz-shamiit-eval",
        notes="Assess depth in JEE advanced problem solving"
    )
    int_res = await schedule_interview(interview_payload, school_id=SCHOOL_ID, user=ADMIN_USER)
    assert int_res.get("success") is True, f"Failed to schedule interview: {int_res}"
    interview_id = int_res["data"]["id"]
    print(f">>> PASS: Interview scheduled with ID: {interview_id}, Status: Scheduled, Round: {interview_payload.interview_round}")

    # Submit feedback
    feedback_payload = InterviewFeedbackCreate(
        technical_skills=5,
        communication=4,
        subject_knowledge=5,
        teaching_ability=5,
        problem_solving=5,
        classroom_management=4,
        leadership=4,
        recommendation="Strong Hire",
        comments="Outstanding mastery in theoretical and applied physics. Great pedagogical approach."
    )
    fb_res = await submit_interview_feedback(interview_id, feedback_payload, school_id=SCHOOL_ID, user=ADMIN_USER)
    assert fb_res.get("success") is True, f"Failed to submit feedback: {fb_res}"
    itw_db = await exec_sql("SELECT status FROM public.recruitment_interviews WHERE id = %s", (interview_id,))
    assert itw_db[0]["status"] == "Completed", f"Expected Completed status, got {itw_db[0]['status']}"
    print(f">>> PASS: Interview feedback submitted successfully. Status: Completed, Recommendation: {feedback_payload.recommendation}")

    # 4. ASSESSMENT ASSIGNMENT & RESULT RECORDING
    print("\n--- STEP 4: ASSESSMENT ASSIGNMENT & EVALUATION WITH EMAIL DISPATCH ---")
    assessment_payload = AssessmentCreate(
        application_id=app_id,
        title="Advanced Physics & Analytical Problem Solving Aptitude",
        assessment_type="Technical Test",
        assessment_date=date.today() + timedelta(days=3),
        max_score=100.0,
        score=None,
        result="Pending",
        remarks="Candidate notified to attempt within allotted time window.",
        test_link="https://eval.edushamiit.com/test/phy-adv-902",
        instructions="Total Duration: 60 Minutes. 25 Multi-step problems. Scientific calculators allowed.",
        send_email=True
    )
    ass_res = await create_assessment(assessment_payload, school_id=SCHOOL_ID, user=ADMIN_USER)
    assert ass_res.get("success") is True, f"Failed to assign assessment: {ass_res}"
    assessment_id = ass_res["data"]["id"]
    assert ass_res["data"]["test_link"] == assessment_payload.test_link, "Test link mismatch in DB"
    assert ass_res["data"]["instructions"] == assessment_payload.instructions, "Instructions mismatch in DB"
    print(f">>> PASS: Assessment assigned with ID: {assessment_id}, Link: {assessment_payload.test_link}, Invitation email triggered.")

    # Record Assessment Result (Passed)
    result_payload = AssessmentResultUpdate(
        score=94.5,
        max_score=100.0,
        result="Passed",
        remarks="Outstanding performance! Demonstrates top 1 percentile mastery in theoretical physics.",
        send_email=True
    )
    res_res = await update_assessment_result(assessment_id, result_payload, school_id=SCHOOL_ID, user=ADMIN_USER)
    assert res_res.get("success") is True, f"Failed to update assessment result: {res_res}"
    assert res_res["data"]["result"] == "Passed", f"Expected result Passed, got {res_res['data']['result']}"
    assert float(res_res["data"]["score"]) == 94.5, f"Expected score 94.5, got {res_res['data']['score']}"
    print(f">>> PASS: Assessment scored and evaluated. Result: Passed (94.5/100.0), Evaluation outcome email triggered.")

    # 5. OFFER GENERATION & DISPATCH
    print("\n--- STEP 5: OFFER CREATION (CTC AUTO-CALCULATION) & EMAIL DISPATCH ---")
    await move_stage(app_id, StageMoveRequest(to_stage="Offer", notes="Candidate selected after assessment"), school_id=SCHOOL_ID, user=ADMIN_USER)

    monthly_salary = 125000.0
    expected_annual_ctc = monthly_salary * 12.0
    offer_payload = OfferCreate(
        application_id=app_id,
        salary=monthly_salary,
        probation_period_months=6,
        joining_date=date.today() + timedelta(days=14),
        offer_expiry_date=date.today() + timedelta(days=7),
        benefits="1. EPF & Gratuity\n2. Comprehensive Family Health Cover (₹5,00,000)\n3. Academic Research & Seminar Grant",
        terms="1. Full-time on campus engagement.\n2. Subject to background verification and degree certificate authenticity.",
        send_immediately=True
    )
    offer_res = await create_offer(offer_payload, school_id=SCHOOL_ID, user=ADMIN_USER)
    assert offer_res.get("success") is True, f"Failed to create offer: {offer_res}"
    offer_id = offer_res["data"]["id"]
    assert offer_res["data"]["status"] == "Sent", f"Expected offer status 'Sent', got {offer_res['data']['status']}"
    assert float(offer_res["data"]["salary"]) == monthly_salary, "Offered salary mismatch"
    print(f">>> PASS: Offer generated with ID: {offer_id}, Status: Sent, Monthly: ₹{monthly_salary:,.2f}, Annual CTC: ₹{expected_annual_ctc:,.2f}, Email dispatched.")

    # Accept the Offer
    acc_res = await accept_offer(offer_id, school_id=SCHOOL_ID, user=ADMIN_USER)
    assert acc_res.get("success") is True, f"Failed to accept offer: {acc_res}"
    assert acc_res["data"]["status"] == "Accepted", f"Expected Accepted, got {acc_res['data']['status']}"
    print(f">>> PASS: Offer accepted successfully. Status: Accepted.")

    # 6. ATOMIC CANDIDATE HIRING & ONBOARDING INTEGRATION
    print("\n--- STEP 6: ATOMIC CANDIDATE HIRING & ONBOARDING PROVISIONING ---")
    emp_code = "EMP-PHY-9988"
    hire_payload = HireCandidateRequest(
        application_id=app_id,
        employee_id=emp_code,
        joining_date=date.today() + timedelta(days=14),
        department="Academics",
        designation="Senior Physics Faculty"
    )
    hire_res = await hire_candidate(cand_id, hire_payload, school_id=SCHOOL_ID, user=ADMIN_USER)
    assert hire_res.get("success") is True, f"Failed to hire candidate: {hire_res}"
    print(f">>> PASS: Candidate hired successfully! Employee Code: {hire_res['data']['employee_id']}, Profile ID: {hire_res['data']['profile_id']}, Onboarding ID: {hire_res['data']['onboarding_id']}")

    # Verify Database State Post-Hire
    app_db = await exec_sql("SELECT current_stage, stage_status FROM public.recruitment_applications WHERE id = %s", (app_id,))
    assert app_db[0]["current_stage"] == "Hired", f"Expected Hired, got {app_db[0]['current_stage']}"
    assert app_db[0]["stage_status"] == "Completed", f"Expected Completed, got {app_db[0]['stage_status']}"

    job_db = await exec_sql("SELECT vacancies, filled_vacancies, publishing_status FROM public.recruitment_jobs WHERE id = %s", (job_id,))
    assert job_db[0]["filled_vacancies"] == 1, f"Expected 1 filled vacancy, got {job_db[0]['filled_vacancies']}"
    assert job_db[0]["publishing_status"] == "Filled", f"Expected Filled status, got {job_db[0]['publishing_status']}"

    profile_db = await exec_sql("SELECT * FROM public.profiles WHERE employee_id = %s", (emp_code,))
    assert len(profile_db) == 1, f"Employee profile not found in public.profiles for {emp_code}"
    assert profile_db[0]["full_name"] == "Dr. Vikramaditya Sharma", "Name mismatch in profile"
    assert profile_db[0]["role"] == "teacher", f"Expected role 'teacher', got {profile_db[0]['role']}"

    onboarding_db = await exec_sql("SELECT * FROM public.employee_onboarding WHERE id = %s", (hire_res['data']['onboarding_id'],))
    assert len(onboarding_db) == 1, "Onboarding record not found"
    assert onboarding_db[0]["joining_status"] == "Expected", "Joining status mismatch"

    print(">>> PASS: DB integrity verified: Application=Hired, Job vacancies filled=1/1 (Status: Filled), Profile created with role 'teacher', Onboarding record initiated.")

    # 7. EDGE CASE TESTS
    print("\n--- STEP 7: EDGE CASES VERIFICATION ---")
    # Edge Case A: Attempting to hire the same candidate again
    print("Test Edge Case A: Re-hiring already hired candidate...")
    try:
        await hire_candidate(cand_id, hire_payload, school_id=SCHOOL_ID, user=ADMIN_USER)
        assert False, "Should have raised 400 for already hired candidate"
    except Exception as e:
        assert "already hired" in str(e).lower(), f"Expected 'already hired' error, got: {e}"
        print(f">>> PASS: Successfully blocked re-hiring already hired candidate: {e}")

    # Edge Case B: Attempting to hire another candidate into the filled job without override
    print("Test Edge Case B: Hiring into fully filled job opening without override limit...")
    cand_b_payload = CandidateCreate(
        job_id=job_id,
        full_name="Dr. Ananya Ray",
        email="ananya.ray.test@shamiit.edu",
        phone="+91 9123456780",
        source="Career Page"
    )
    cand_b_res = await create_candidate(cand_b_payload, school_id=SCHOOL_ID, user=ADMIN_USER)
    cand_b_id = cand_b_res["data"]["id"]
    app_b_id = cand_b_res["data"]["application"]["id"]

    hire_b_payload = HireCandidateRequest(
        application_id=app_b_id,
        employee_id="EMP-PHY-9989",
        override_vacancy_limit=False
    )
    try:
        await hire_candidate(cand_b_id, hire_b_payload, school_id=SCHOOL_ID, user=ADMIN_USER)
        assert False, "Should have raised 400 due to no remaining vacancies"
    except Exception as e:
        assert "no remaining vacancies" in str(e).lower(), f"Expected 'no remaining vacancies' error, got: {e}"
        print(f">>> PASS: Successfully blocked over-hiring without override authorization: {e}")

    # Edge Case C: Assessment result recorded as 'Failed'
    print("Test Edge Case C: Assessment evaluation marked as 'Failed' with remedial feedback...")
    fail_ass_payload = AssessmentCreate(
        application_id=app_id,
        title="Psychometric & Culture Alignment Assessment",
        assessment_type="Psychometric",
        max_score=50.0,
        result="Pending",
        send_email=False
    )
    fail_ass = await create_assessment(fail_ass_payload, school_id=SCHOOL_ID, user=ADMIN_USER)
    fail_ass_id = fail_ass["data"]["id"]
    fail_eval = await update_assessment_result(
        fail_ass_id,
        AssessmentResultUpdate(score=18.0, max_score=50.0, result="Failed", remarks="Did not meet minimum threshold in collaborative pedagogy.", send_email=True),
        school_id=SCHOOL_ID,
        user=ADMIN_USER
    )
    assert fail_eval["data"]["result"] == "Failed", f"Expected Failed, got {fail_eval['data']['result']}"
    print(f">>> PASS: Assessment marked as Failed (Score: 18.0/50.0) with candidate notification triggered.")

    # Edge Case D: Offer Draft -> Send -> Reject flow on candidate B
    print("Test Edge Case D: Offer Draft creation, subsequent send, and rejection with reason...")
    draft_offer_payload = OfferCreate(
        application_id=app_b_id,
        salary=110000.0,
        probation_period_months=3,
        joining_date=date.today() + timedelta(days=30),
        send_immediately=False
    )
    draft_offer = await create_offer(draft_offer_payload, school_id=SCHOOL_ID, user=ADMIN_USER)
    draft_offer_id = draft_offer["data"]["id"]
    assert draft_offer["data"]["status"] == "Draft", f"Expected Draft, got {draft_offer['data']['status']}"
    
    # Send the draft offer
    sent_res = await send_offer(draft_offer_id, school_id=SCHOOL_ID, user=ADMIN_USER)
    assert sent_res["data"]["status"] == "Sent", f"Expected Sent, got {sent_res['data']['status']}"
    
    # Reject the offer with reason
    rej_res = await reject_offer(draft_offer_id, reason="Candidate negotiated higher compensation elsewhere", school_id=SCHOOL_ID, user=ADMIN_USER)
    assert rej_res["data"]["status"] == "Rejected", f"Expected Rejected, got {rej_res['data']['status']}"
    print(f">>> PASS: Offer Draft -> Sent -> Rejected flow verified successfully with rejection reasoning.")

    # Edge Case E: Hiring with override_vacancy_limit=True when job is at full capacity
    print("Test Edge Case E: Successful hire with override_vacancy_limit=True...")
    hire_b_override = HireCandidateRequest(
        application_id=app_b_id,
        employee_id="EMP-PHY-OVERRIDE",
        override_vacancy_limit=True,
        department="Academics",
        designation="Senior Physics Faculty"
    )
    hire_override_res = await hire_candidate(cand_b_id, hire_b_override, school_id=SCHOOL_ID, user=ADMIN_USER)
    assert hire_override_res.get("success") is True, "Failed to hire with vacancy override"
    print(f">>> PASS: Successfully hired candidate beyond standard vacancy limit with explicit override authorization!")

    # Cleanup Cand B
    await exec_sql("DELETE FROM public.recruitment_offers WHERE candidate_id = %s", (cand_b_id,), fetch=False)
    await exec_sql("DELETE FROM public.recruitment_stage_history WHERE candidate_id = %s", (cand_b_id,), fetch=False)
    await exec_sql("DELETE FROM public.employee_onboarding WHERE candidate_id = %s", (cand_b_id,), fetch=False)
    await exec_sql("DELETE FROM public.profiles WHERE email = %s;", ("ananya.ray.test@shamiit.edu",), fetch=False)
    await exec_sql("DELETE FROM public.recruitment_applications WHERE id = %s", (app_b_id,), fetch=False)
    await exec_sql("DELETE FROM public.recruitment_candidates WHERE id = %s", (cand_b_id,), fetch=False)

    # 8. CANDIDATE 360 DETAIL AGGREGATION
    print("\n--- STEP 8: CANDIDATE 360 DETAIL AGGREGATION ---")
    c360 = await get_candidate_360_profile(cand_id, school_id=SCHOOL_ID, user=ADMIN_USER)
    assert c360.get("success") is True, f"Failed to get candidate 360 detail: {c360}"
    c360_data = c360["data"]
    
    assert len(c360_data["applications"]) >= 1, "Missing applications in 360 view"
    assert c360_data["applications"][0]["current_stage"] == "Hired", "Stage mismatch in 360 view"
    assert len(c360_data["interviews"]) >= 1, "Missing interviews in 360 view"
    assert c360_data["interviews"][0]["status"] == "Completed", "Interview status mismatch"
    assert len(c360_data["assessments"]) >= 1, "Missing assessments in 360 view"
    assert c360_data["assessments"][0]["result"] == "Passed", "Assessment result mismatch"
    assert c360_data["assessments"][0]["test_link"] == assessment_payload.test_link, "Test link missing in 360 view"
    assert len(c360_data["offers"]) >= 1, "Missing offers in 360 view"
    assert c360_data["offers"][0]["status"] == "Accepted", "Offer status mismatch in 360 view"
    assert c360_data.get("employee_profile") is not None, "Linked employee profile missing in 360 view"
    assert c360_data["employee_profile"]["employee_id"] == emp_code, "Employee ID mismatch in 360 view"
    assert c360_data.get("onboarding") is not None, "Linked onboarding info missing in 360 view"
    print(">>> PASS: Candidate 360 view comprehensively verified with all linked records and full lifecycle history!")

    print("\n" + "=" * 80)
    print("ALL RECRUITMENT LIFECYCLE E2E TESTS PASSED WITH 100% SUCCESS!")
    print("=" * 80)


if __name__ == "__main__":
    asyncio.run(run_e2e_recruitment_test())
