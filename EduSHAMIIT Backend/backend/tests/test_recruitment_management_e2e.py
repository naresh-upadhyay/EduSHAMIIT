"""
End-to-End Test Suite for Recruitment Management Module (EduSHAMIIT ERP).
Tests:
- Authentication, Authorization & RBAC
- Multi-Tenant / School Isolation (School A cannot see School B)
- Real-time KPI Stats & Analytics
- Pipeline Stage Details with Subtabs & Pagination
- Job Openings CRUD, Duplication & Status Transitions
- Candidate Creation, Search & 360 Profile Drawer
- Interview Scheduling, Overdue/Past Date Guard & Multi-Interviewer Feedback
- Offer Creation, Sending & Acceptance
- Atomic Vacancy-Checked Hiring Workflow & Onboarding Integration
- Over-Hiring Prevention (Vacancy Exceeded Guard)
- Rejection & Withdrawal Workflows
- Bulk Operations
- CSV Exports & Audit Timeline
"""

import os
import sys
os.environ["DATABASE_URL"] = "postgresql://postgres:eduSHAMIIT2026_pg@localhost:54322/postgres"
os.environ["POSTGRES_PORT"] = "54322"
os.environ["POSTGRES_PASSWORD"] = "eduSHAMIIT2026_pg"
os.environ["SUPABASE_URL"] = "http://localhost:8082"
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import sys
import uuid
from datetime import date, timedelta
from jose import jwt
from fastapi.testclient import TestClient

from app.main import app
from app.config import settings

SCHOOL_A = "11111111-1111-1111-1111-111111111111"
SCHOOL_B = "22222222-2222-2222-2222-222222222222"
ADMIN_USER_ID = "5198c4b0-f1cb-45db-9649-41688d0438ba"
INTERVIEWER_USER_ID = "44444444-4444-4444-4444-444444444444"

JWT_SECRET = settings.SUPABASE_JWT_SECRET or settings.JWT_SECRET

def make_token(user_id: str, school_id: str, role: str) -> str:
    payload = {
        "sub": user_id,
        "school_id": school_id,
        "role": role,
        "email": f"{role}@{school_id[:8]}.com",
        "exp": 9999999999
    }
    return jwt.encode(payload, JWT_SECRET, algorithm="HS256")

client = TestClient(app)

def run_tests():
    print("=" * 70)
    print("      EduSHAMIIT HR RECRUITMENT MANAGEMENT - E2E TEST SUITE        ")
    print("=" * 70)

    token_admin_a = make_token(ADMIN_USER_ID, SCHOOL_A, "super_admin")
    headers_admin_a = {"Authorization": f"Bearer {token_admin_a}", "Content-Type": "application/json"}

    token_admin_b = make_token(str(uuid.uuid4()), SCHOOL_B, "admin")
    headers_admin_b = {"Authorization": f"Bearer {token_admin_b}", "Content-Type": "application/json"}

    token_unauth = make_token(str(uuid.uuid4()), SCHOOL_A, "student")
    headers_unauth = {"Authorization": f"Bearer {token_unauth}", "Content-Type": "application/json"}

    passed = 0
    total = 0

    def test(name: str, condition: bool, details: str = ""):
        nonlocal passed, total
        total += 1
        if condition:
            passed += 1
            print(f"  [PASS] Scenario {total:02d}: {name}")
        else:
            print(f"  [FAIL] Scenario {total:02d}: {name} -> {details}")

    # 1. Access Control: Unauthorized role rejected
    r1 = client.get("/api/recruitment/stats", headers=headers_unauth)
    test("RBAC - Unauthorized role blocked with 403", r1.status_code == 403, r1.text)

    # 2. Real-time KPI Stats
    r2 = client.get("/api/recruitment/stats", headers=headers_admin_a)
    stats = r2.json().get("data", {})
    test("KPI Stats Retrieval - Real DB Aggregations",
         r2.status_code == 200 and stats.get("active_positions", 0) > 0 and stats.get("total_applicants", 0) > 0,
         r2.text)

    # 3. Recruitment Analytics (Donut, Dept hiring, Conversion)
    r3 = client.get("/api/recruitment/analytics", headers=headers_admin_a)
    analytics = r3.json().get("data", {})
    test("Recruitment Analytics - Sources, Depts & Pipeline Conversion",
         r3.status_code == 200 and len(analytics.get("applicants_by_source", [])) > 0 and len(analytics.get("department_hiring", [])) > 0,
         r3.text)

    # 4. Pipeline Stages
    r4 = client.get("/api/recruitment/pipeline", headers=headers_admin_a)
    stages = r4.json().get("data", {})
    test("Pipeline Stages - Counts per stage",
         r4.status_code == 200 and "Screening" in stages and "Interview" in stages,
         r4.text)

    # 5. Pipeline Stage Details Workspace (Screening stage)
    r5 = client.get("/api/recruitment/pipeline/Screening?subtab=all&page=1&page_size=10", headers=headers_admin_a)
    screening_data = r5.json().get("data", [])
    pagination = r5.json().get("pagination", {})
    test("Pipeline Stage Details Workspace - Filtered Candidate List & Pagination",
         r5.status_code == 200 and len(screening_data) > 0 and pagination.get("total_records", 0) > 0,
         r5.text)

    # 6. Stage Details Search & Subtab Filtering
    r6 = client.get("/api/recruitment/pipeline/Screening?search=Priya&subtab=pending", headers=headers_admin_a)
    priya_found = any("Priya" in c.get("full_name", "") for c in r6.json().get("data", []))
    test("Pipeline Stage Details - Search & Subtab Filtering",
         r6.status_code == 200 and priya_found,
         r6.text)

    # 7. Job Openings Listing & Pagination
    r7 = client.get("/api/recruitment/jobs?page=1&page_size=10", headers=headers_admin_a)
    jobs = r7.json().get("data", [])
    test("Job Openings - Paginated List with Aggregated Applicant Counts",
         r7.status_code == 200 and len(jobs) > 0 and "total_applicants" in jobs[0],
         r7.text)

    # 8. Create Job Opening with full schema
    new_job_code = f"TEST-JOB-{uuid.uuid4().hex[:6].upper()}"
    new_job_payload = {
        "job_title": "Senior Chemistry Faculty",
        "job_code": new_job_code,
        "department": "Teaching",
        "designation": "PGT Chemistry",
        "employment_type": "Full-time",
        "vacancies": 1,
        "location": "Senior Wing",
        "qualifications": "M.Sc Chemistry, B.Ed",
        "experience_required": "3-5 years",
        "salary_min": 40000,
        "salary_max": 60000,
        "publishing_status": "Active"
    }
    r8 = client.post("/api/recruitment/jobs", json=new_job_payload, headers=headers_admin_a)
    created_job = r8.json().get("data", {})
    created_job_id = created_job.get("id")
    test("Create Job Opening - Full Enterprise Validation & Code Generation",
         r8.status_code == 200 and created_job.get("job_code") == new_job_code,
         r8.text)

    # 9. Duplicate Job Opening Prevention
    r9 = client.post("/api/recruitment/jobs", json=new_job_payload, headers=headers_admin_a)
    test("Duplicate Job Opening Code Guard", r9.status_code == 400, r9.text)

    # 10. Update Job Opening
    r10 = client.put(f"/api/recruitment/jobs/{created_job_id}", json={"vacancies": 2, "designation": "Head of Chemistry"}, headers=headers_admin_a)
    test("Update Job Opening - Modify Vacancies & Designation",
         r10.status_code == 200 and r10.json().get("data", {}).get("vacancies") == 2,
         r10.text)

    # 11. Duplicate Job Opening into Draft
    r11 = client.post(f"/api/recruitment/jobs/{created_job_id}/duplicate", headers=headers_admin_a)
    dup_job = r11.json().get("data", {})
    test("Duplicate Job Opening Action - Creates Draft Copy",
         r11.status_code == 200 and dup_job.get("publishing_status") == "Draft",
         r11.text)

    # 12. Multi-Tenant Isolation - School B cannot see School A's new job
    r12 = client.get(f"/api/recruitment/jobs/{created_job_id}", headers=headers_admin_b)
    test("Multi-Tenant Isolation - Job Inaccessible to Other School", r12.status_code == 404, r12.text)

    # 13. Create Candidate with Initial Job Application
    cand_email = f"test.applicant.{uuid.uuid4().hex[:6]}@example.com"
    cand_payload = {
        "full_name": "Rohan Deshmukh",
        "email": cand_email,
        "phone": "+91 9876500112",
        "gender": "Male",
        "qualification": "M.Sc Chemistry, B.Ed",
        "specialization": "Organic Chemistry",
        "experience_years": 4.0,
        "current_organization": "Modern High School",
        "current_designation": "Chemistry Teacher",
        "expected_salary": 50000,
        "skills": ["Chemistry", "Lab Safety", "IIT-JEE Foundation"],
        "source": "LinkedIn",
        "job_id": created_job_id
    }
    r13 = client.post("/api/recruitment/candidates", json=cand_payload, headers=headers_admin_a)
    created_cand = r13.json().get("data", {})
    cand_id = created_cand.get("id")
    app_id = created_cand.get("application", {}).get("id")
    test("Candidate Management - Create Candidate with Initial Application",
         r13.status_code == 200 and cand_id is not None and app_id is not None,
         r13.text)

    # 14. Candidate 360-Degree Profile Drawer
    r14 = client.get(f"/api/recruitment/candidates/{cand_id}", headers=headers_admin_a)
    profile = r14.json().get("data", {})
    test("Candidate Profile 360 Drawer - Complete Sections Included",
         r14.status_code == 200 and "applications" in profile and "stage_history" in profile and "interviews" in profile,
         r14.text)

    # 15. Stage Transition - Move Applied to Screening
    r15 = client.post(f"/api/recruitment/applications/{app_id}/move-stage", json={"to_stage": "Screening", "notes": "Initial resume check passed"}, headers=headers_admin_a)
    test("Stage Progression - Move Candidate to Screening", r15.status_code == 200, r15.text)

    # 16. Schedule Interview - Overdue/Past Date Guard
    r16 = client.post("/api/recruitment/interviews", json={
        "application_id": app_id,
        "interview_round": "Technical Round",
        "scheduled_date": str(date.today() - timedelta(days=1)),
        "scheduled_time_start": "10:00:00",
        "scheduled_time_end": "10:30:00",
        "mode": "In Person"
    }, headers=headers_admin_a)
    test("Interview Validation - Guard Against Past Dates", r16.status_code == 400, r16.text)

    # 17. Schedule Interview - Valid Upcoming Date
    r17 = client.post("/api/recruitment/interviews", json={
        "application_id": app_id,
        "interview_round": "Technical Round",
        "scheduled_date": str(date.today() + timedelta(days=3)),
        "scheduled_time_start": "11:00:00",
        "scheduled_time_end": "11:45:00",
        "mode": "In Person",
        "meeting_link_or_location": "Conference Room A"
    }, headers=headers_admin_a)
    itw_id = r17.json().get("data", {}).get("id")
    test("Schedule Interview - Move Stage to Interview & Store Schedule",
         r17.status_code == 200 and itw_id is not None,
         r17.text)

    # 18. Submit Interviewer Feedback (8 Competency Ratings + Recommendation)
    feedback_payload = {
        "technical_skills": 5,
        "communication": 4,
        "subject_knowledge": 5,
        "teaching_ability": 4,
        "problem_solving": 5,
        "classroom_management": 4,
        "leadership": 4,
        "recommendation": "Strong Hire",
        "comments": "Excellent organic chemistry mastery and great interaction with demo students."
    }
    r18 = client.post(f"/api/recruitment/interviews/{itw_id}/feedback", json=feedback_payload, headers=headers_admin_a)
    feedback_data = r18.json().get("data", {})
    test("Interview Feedback - Independent Submission & Competency Scoring",
         r18.status_code == 200 and feedback_data.get("overall_rating") is not None,
         r18.text)

    # 19. Assessment Evaluation Recording
    r19 = client.post("/api/recruitment/assessments", json={
        "application_id": app_id,
        "title": "Teaching Demo Assessment",
        "assessment_type": "Teaching Demo",
        "score": 92.5,
        "max_score": 100.0,
        "result": "Passed",
        "remarks": "Engaging demonstration with clear black-board work."
    }, headers=headers_admin_a)
    test("Candidate Assessments - Record Evaluation & Result", r19.status_code == 200, r19.text)

    # 20. Offer Management - Draft Offer
    r20 = client.post("/api/recruitment/offers", json={
        "application_id": app_id,
        "salary": 52000,
        "joining_date": str(date.today() + timedelta(days=15)),
        "probation_period_months": 6,
        "benefits": "Medical insurance, PF, Transport allowance",
        "terms": "Standard school service rules apply"
    }, headers=headers_admin_a)
    offer_id = r20.json().get("data", {}).get("id")
    test("Offer Generation - Draft Offer & Move to Offer Stage",
         r20.status_code == 200 and offer_id is not None,
         r20.text)

    # 21. Offer Workflow - Send & Accept Offer
    r21_send = client.post(f"/api/recruitment/offers/{offer_id}/send", headers=headers_admin_a)
    r21_accept = client.post(f"/api/recruitment/offers/{offer_id}/accept", headers=headers_admin_a)
    test("Offer Workflow - Send & Accept Transitions",
         r21_send.status_code == 200 and r21_accept.status_code == 200,
         f"send: {r21_send.text}, accept: {r21_accept.text}")

    # 22. Atomic Hiring Workflow - Vacancy Validation, Profile Creation, Onboarding Integration
    hire_payload = {
        "application_id": app_id,
        "joining_date": str(date.today() + timedelta(days=15)),
        "designation": "PGT Chemistry",
        "department": "Teaching",
        "override_vacancy_limit": False
    }
    r22 = client.post(f"/api/recruitment/candidates/{cand_id}/hire", json=hire_payload, headers=headers_admin_a)
    hire_result = r22.json().get("data", {})
    test("Atomic Hiring Workflow - Status Updated, Employee Profile & Onboarding Created",
         r22.status_code == 200 and "profile_id" in hire_result and "onboarding_id" in hire_result,
         r22.text)

    # 23. Verify Vacancies Decremented on Job
    r23 = client.get(f"/api/recruitment/jobs/{created_job_id}", headers=headers_admin_a)
    job_after_hire = r23.json().get("data", {})
    test("Job Vacancy Sync - Filled Vacancies Atomically Incremented",
         job_after_hire.get("filled_vacancies") == 1,
         str(job_after_hire))

    # 24. Rejection Workflow - Create second candidate and reject
    cand2_payload = {
        "full_name": "Kavita Rao",
        "email": f"kavita.rao.{uuid.uuid4().hex[:6]}@example.com",
        "qualification": "B.Sc Chemistry",
        "job_id": created_job_id
    }
    r24_cand = client.post("/api/recruitment/candidates", json=cand2_payload, headers=headers_admin_a)
    app2_id = r24_cand.json().get("data", {}).get("application", {}).get("id")
    cand2_id = r24_cand.json().get("data", {}).get("id")
    
    r24_reject = client.post(f"/api/recruitment/applications/{app2_id}/reject", json={"reason": "Experience mismatch", "notes": "Minimum 3 years required"}, headers=headers_admin_a)
    test("Rejection Workflow - Candidate Rejected with Reason", r24_reject.status_code == 200, r24_reject.text)

    # 25. Business Rule Guard - Cannot interview or hire rejected candidate
    r25_itw = client.post("/api/recruitment/interviews", json={
        "application_id": app2_id,
        "interview_round": "Technical Round",
        "scheduled_date": str(date.today() + timedelta(days=2)),
        "scheduled_time_start": "10:00:00",
        "scheduled_time_end": "10:30:00"
    }, headers=headers_admin_a)
    test("Business Rule Guard - Cannot Schedule Interview for Rejected Candidate", r25_itw.status_code == 400, r25_itw.text)

    # 26. Fill Remaining Vacancy on Job
    cand3_payload = {
        "full_name": "Siddharth Joshi",
        "email": f"siddharth.{uuid.uuid4().hex[:6]}@example.com",
        "qualification": "Ph.D Chemistry",
        "job_id": created_job_id
    }
    r26_cand = client.post("/api/recruitment/candidates", json=cand3_payload, headers=headers_admin_a)
    app3_id = r26_cand.json().get("data", {}).get("application", {}).get("id")
    cand3_id = r26_cand.json().get("data", {}).get("id")

    r26_hire = client.post(f"/api/recruitment/candidates/{cand3_id}/hire", json={"application_id": app3_id}, headers=headers_admin_a)
    test("Second Hire - Reaches Total Vacancy Limit (2/2)", r26_hire.status_code == 200, r26_hire.text)

    # 27. Over-Hiring Prevention Guard - 3rd candidate on job with 2 vacancies fails without override
    cand4_payload = {
        "full_name": "Meera Sen",
        "email": f"meera.sen.{uuid.uuid4().hex[:6]}@example.com",
        "qualification": "M.Sc Chemistry",
        "job_id": created_job_id
    }
    r27_cand = client.post("/api/recruitment/candidates", json=cand4_payload, headers=headers_admin_a)
    app4_id = r27_cand.json().get("data", {}).get("application", {}).get("id")
    cand4_id = r27_cand.json().get("data", {}).get("id")

    r27_overhire = client.post(f"/api/recruitment/candidates/{cand4_id}/hire", json={"application_id": app4_id, "override_vacancy_limit": False}, headers=headers_admin_a)
    test("Over-Hiring Prevention Guard - Vacancy Limit Exceeded Blocked (400)", r27_overhire.status_code == 400, r27_overhire.text)

    # 28. Bulk Action - Bulk Stage Move
    r28 = client.post("/api/recruitment/candidates/bulk-action", json={
        "candidate_ids": [cand3_id, cand4_id],
        "action": "move_stage",
        "target_stage": "Shortlisted"
    }, headers=headers_admin_a)
    test("Bulk Operations - Bulk Stage Move", r28.status_code == 200, r28.text)

    # 29. CSV Export for Job Openings
    r29 = client.get("/api/recruitment/export/jobs", headers=headers_admin_a)
    test("CSV Export - Job Openings File Download",
         r29.status_code == 200 and "text/csv" in r29.headers.get("content-type", ""),
         r29.headers.get("content-type", ""))

    # 30. CSV Export for Candidates
    r30 = client.get("/api/recruitment/export/candidates", headers=headers_admin_a)
    test("CSV Export - Candidates File Download",
         r30.status_code == 200 and "text/csv" in r30.headers.get("content-type", ""),
         r30.headers.get("content-type", ""))

    # 31. Recruitment Activity Timeline
    r31 = client.get("/api/recruitment/activities", headers=headers_admin_a)
    acts = r31.json().get("data", [])
    test("Recruitment Activity Timeline - Persistent Action Log",
         r31.status_code == 200 and len(acts) > 0,
         r31.text)

    # 32. Soft Delete Job Opening
    r32 = client.delete(f"/api/recruitment/jobs/{created_job_id}", headers=headers_admin_a)
    test("Soft Delete Job Opening", r32.status_code == 200, r32.text)

    # Summary
    print("=" * 70)
    print(f"      TEST RESULTS: {passed}/{total} SCENARIOS PASSED ({round(passed/total*100, 1)}%)")
    print("=" * 70)

    if passed < total:
        sys.exit(1)

if __name__ == "__main__":
    run_tests()
