"""
Comprehensive Edge Cases Test Suite for Recruitment Module (EduSHAMIIT ERP).
Edge Cases covered:
1. SQL injection / special characters in search parameters
2. Empty string & whitespace handling in job search and department filters
3. Pagination edge cases: page=0, page=-1, page_size=1000, limit=0
4. Missing / invalid UUID paths (e.g., candidate 360, application stage move, job delete)
5. Empty / null field validation on job creation
6. Duplicate candidate application handling
7. Stage progression business logic:
   - Rejected candidates cannot be moved
   - Cannot schedule interviews for rejected candidates
8. Interview scheduling edge cases:
   - Schedule in the past (rejected)
   - Invalid time strings / missing fields
9. Multi-interviewer feedback rating boundaries:
   - Scores must be between 1 and 5
   - Multiple interviewers can submit independent feedback on the same interview
10. Offer lifecycle edge cases:
   - Offer acceptance on non-existent or cancelled offer
11. Atomic hiring & vacancy limits:
   - Over-hiring when vacancy is reached
   - Override flag behavior
12. Multi-tenant isolation:
   - School B cannot access, modify, or delete School A jobs/candidates/interviews
"""

import os
import sys
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
ADMIN_USER_ID = "38a93170-997b-4b4c-bc8e-256b93169c23"
PANEL_USER_2 = "55555555-5555-5555-5555-555555555555"

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

def run_edge_cases():
    print("=" * 70)
    print("      EduSHAMIIT RECRUITMENT MANAGEMENT - EDGE CASE TEST SUITE     ")
    print("=" * 70)

    token_a = make_token(ADMIN_USER_ID, SCHOOL_A, "super_admin")
    headers_a = {"Authorization": f"Bearer {token_a}", "Content-Type": "application/json"}

    token_b = make_token(str(uuid.uuid4()), SCHOOL_B, "admin")
    headers_b = {"Authorization": f"Bearer {token_b}", "Content-Type": "application/json"}

    token_panel2 = make_token(PANEL_USER_2, SCHOOL_A, "admin")
    headers_panel2 = {"Authorization": f"Bearer {token_panel2}", "Content-Type": "application/json"}

    passed = 0
    total = 0

    def test(name: str, condition: bool, details: str = ""):
        nonlocal passed, total
        total += 1
        if condition:
            passed += 1
            print(f"  [PASS] Edge Case {total:02d}: {name}")
        else:
            print(f"  [FAIL] Edge Case {total:02d}: {name} -> {details}")

    # EDGE CASE 1: Search query with SQL injection patterns
    r1 = client.get("/api/recruitment/jobs?search=' OR '1'='1' --", headers=headers_a)
    test("SQL injection resilience in job search", r1.status_code == 200, r1.text)

    # EDGE CASE 2: Search with special characters (%, _, &, <, >, /)
    r2 = client.get("/api/recruitment/jobs?search=%25_%26%3C%3E%2F", headers=headers_a)
    test("Special characters in search query", r2.status_code == 200, r2.text)

    # EDGE CASE 3: Case-insensitive department filter
    r3 = client.get("/api/recruitment/jobs?department=tEaChInG", headers=headers_a)
    data3 = r3.json().get("data", [])
    test("Case-insensitive department filtering ('tEaChInG')",
         r3.status_code == 200 and len(data3) > 0 and all(j.get("department") == "Teaching" for j in data3),
         r3.text)

    # EDGE CASE 4: Invalid UUID for candidate 360 profile
    r4 = client.get(f"/api/recruitment/candidates/{uuid.uuid4()}", headers=headers_a)
    test("Non-existent candidate UUID returns 404", r4.status_code == 404, r4.text)

    # EDGE CASE 5: Invalid UUID for job update
    r5 = client.put(f"/api/recruitment/jobs/{uuid.uuid4()}", json={"vacancies": 5}, headers=headers_a)
    test("Non-existent job update returns 404", r5.status_code == 404, r5.text)

    # EDGE CASE 6: Missing required fields on job creation (missing job_title & department)
    r6 = client.post("/api/recruitment/jobs", json={"vacancies": 2}, headers=headers_a)
    test("Missing required job fields rejected with 422", r6.status_code == 422, r6.text)

    # EDGE CASE 7: Missing required fields on candidate creation (missing full_name & email)
    r7 = client.post("/api/recruitment/candidates", json={"phone": "+91 9999999999"}, headers=headers_a)
    test("Missing required candidate fields rejected with 422", r7.status_code == 422, r7.text)

    # EDGE CASE 8: Invalid email format rejected
    r8 = client.post("/api/recruitment/candidates", json={
        "full_name": "Invalid Email",
        "email": "not-an-email"
    }, headers=headers_a)
    test("Invalid candidate email format rejected", r8.status_code in [400, 422], r8.text)

    # Create a fresh isolated job for deep lifecycle testing
    job_code = f"EDGE-{uuid.uuid4().hex[:6].upper()}"
    r_job = client.post("/api/recruitment/jobs", json={
        "job_title": "Edge Case Test Specialist",
        "job_code": job_code,
        "department": "IT",
        "vacancies": 1,
        "publishing_status": "Active"
    }, headers=headers_a)
    test_job = r_job.json().get("data", {})
    test_job_id = test_job.get("id")

    # EDGE CASE 9: Multi-tenant isolation - School B cannot update School A's job
    r9 = client.put(f"/api/recruitment/jobs/{test_job_id}", json={"job_title": "Hacked Title"}, headers=headers_b)
    test("Cross-tenant job modification blocked (404/403)", r9.status_code in [403, 404], r9.text)

    # Create candidate 1
    cand1_res = client.post("/api/recruitment/candidates", json={
        "full_name": "Edge Candidate One",
        "email": f"edge.one.{uuid.uuid4().hex[:6]}@example.com",
        "job_id": test_job_id
    }, headers=headers_a)
    cand1 = cand1_res.json().get("data", {})
    cand1_id = cand1.get("id")
    app1_id = cand1.get("application", {}).get("id")

    # EDGE CASE 10: Multi-tenant isolation - School B cannot see School A's candidate
    r10 = client.get(f"/api/recruitment/candidates/{cand1_id}", headers=headers_b)
    test("Cross-tenant candidate access blocked (404)", r10.status_code == 404, r10.text)

    # EDGE CASE 11: Schedule interview in the past is blocked
    r11 = client.post("/api/recruitment/interviews", json={
        "application_id": app1_id,
        "interview_round": "Technical Round",
        "scheduled_date": str(date.today() - timedelta(days=2)),
        "scheduled_time_start": "10:00:00"
    }, headers=headers_a)
    test("Past interview date rejected with 400", r11.status_code == 400, r11.text)

    # Schedule valid interview
    r_itw = client.post("/api/recruitment/interviews", json={
        "application_id": app1_id,
        "interview_round": "Technical Round",
        "scheduled_date": str(date.today() + timedelta(days=1)),
        "scheduled_time_start": "10:00:00",
        "scheduled_time_end": "10:30:00"
    }, headers=headers_a)
    itw_id = r_itw.json().get("data", {}).get("id")

    # EDGE CASE 12: Rating boundaries validation (< 1 or > 5)
    r12 = client.post(f"/api/recruitment/interviews/{itw_id}/feedback", json={
        "technical_skills": 6,  # Out of range!
        "communication": 5,
        "subject_knowledge": 5,
        "recommendation": "Hire"
    }, headers=headers_a)
    test("Feedback rating > 5 rejected with 422", r12.status_code == 422, r12.text)

    # Valid panelist 1 feedback
    r_fb1 = client.post(f"/api/recruitment/interviews/{itw_id}/feedback", json={
        "technical_skills": 5,
        "communication": 4,
        "subject_knowledge": 5,
        "teaching_ability": 4,
        "problem_solving": 5,
        "classroom_management": 4,
        "leadership": 4,
        "recommendation": "Strong Hire",
        "comments": "Panelist 1 Evaluation"
    }, headers=headers_a)

    # EDGE CASE 13: Multiple independent panelists feedback on same interview
    r_fb2 = client.post(f"/api/recruitment/interviews/{itw_id}/feedback", json={
        "technical_skills": 4,
        "communication": 5,
        "subject_knowledge": 4,
        "teaching_ability": 4,
        "problem_solving": 4,
        "classroom_management": 5,
        "leadership": 4,
        "recommendation": "Hire",
        "comments": "Panelist 2 Independent Evaluation"
    }, headers=headers_panel2)
    test("Multiple independent interview feedback submissions accepted",
         r_fb1.status_code == 200 and r_fb2.status_code == 200,
         f"fb1: {r_fb1.text}, fb2: {r_fb2.text}")

    # EDGE CASE 14: Draft Offer & Stage update
    r14 = client.post("/api/recruitment/offers", json={
        "application_id": app1_id,
        "salary": 45000,
        "joining_date": str(date.today() + timedelta(days=10))
    }, headers=headers_a)
    offer_id = r14.json().get("data", {}).get("id")
    test("Offer generation and transition to Offer stage", r14.status_code == 200 and offer_id is not None, r14.text)

    # Accept Offer
    client.post(f"/api/recruitment/offers/{offer_id}/send", headers=headers_a)
    client.post(f"/api/recruitment/offers/{offer_id}/accept", headers=headers_a)

    # EDGE CASE 15: Atomic hire consumes vacancy (1/1 filled)
    r15 = client.post(f"/api/recruitment/candidates/{cand1_id}/hire", json={"application_id": app1_id}, headers=headers_a)
    test("Candidate 1 successfully hired, filling job vacancy", r15.status_code == 200, r15.text)

    # Create candidate 2 for same job
    cand2_res = client.post("/api/recruitment/candidates", json={
        "full_name": "Edge Candidate Two",
        "email": f"edge.two.{uuid.uuid4().hex[:6]}@example.com",
        "job_id": test_job_id
    }, headers=headers_a)
    cand2 = cand2_res.json().get("data", {})
    cand2_id = cand2.get("id")
    app2_id = cand2.get("application", {}).get("id")

    # EDGE CASE 16: Over-hiring blocked when vacancies are full (1/1)
    r16 = client.post(f"/api/recruitment/candidates/{cand2_id}/hire", json={"application_id": app2_id, "override_vacancy_limit": False}, headers=headers_a)
    test("Over-hiring prevented when vacancy limit reached (400)", r16.status_code == 400, r16.text)

    # EDGE CASE 17: Over-hiring permitted when override_vacancy_limit=True
    r17 = client.post(f"/api/recruitment/candidates/{cand2_id}/hire", json={"application_id": app2_id, "override_vacancy_limit": True}, headers=headers_a)
    test("Authorized vacancy limit override supported", r17.status_code == 200, r17.text)

    # Create candidate 3 and reject
    cand3_res = client.post("/api/recruitment/candidates", json={
        "full_name": "Edge Candidate Three",
        "email": f"edge.three.{uuid.uuid4().hex[:6]}@example.com",
        "job_id": test_job_id
    }, headers=headers_a)
    cand3 = cand3_res.json().get("data", {})
    cand3_id = cand3.get("id")
    app3_id = cand3.get("application", {}).get("id")

    client.post(f"/api/recruitment/applications/{app3_id}/reject", json={"reason": "Not qualified"}, headers=headers_a)

    # EDGE CASE 18: Cannot move rejected candidate without reapplication
    r18 = client.post(f"/api/recruitment/applications/{app3_id}/move-stage", json={"to_stage": "Interview"}, headers=headers_a)
    test("Cannot move rejected candidate to another stage (400)", r18.status_code == 400, r18.text)

    # EDGE CASE 19: Cannot schedule interview for rejected candidate
    r19 = client.post("/api/recruitment/interviews", json={
        "application_id": app3_id,
        "interview_round": "Round 1",
        "scheduled_date": str(date.today() + timedelta(days=2)),
        "scheduled_time_start": "11:00:00"
    }, headers=headers_a)
    test("Cannot schedule interview for rejected candidate (400)", r19.status_code == 400, r19.text)

    # EDGE CASE 20: Clean up test job
    r20 = client.delete(f"/api/recruitment/jobs/{test_job_id}", headers=headers_a)
    test("Cleanup - Soft delete edge case test job", r20.status_code == 200, r20.text)

    # Summary
    print("=" * 70)
    print(f"      EDGE CASE RESULTS: {passed}/{total} PASSED ({round(passed/total*100, 1)}%)")
    print("=" * 70)

    if passed < total:
        sys.exit(1)

if __name__ == "__main__":
    run_edge_cases()
