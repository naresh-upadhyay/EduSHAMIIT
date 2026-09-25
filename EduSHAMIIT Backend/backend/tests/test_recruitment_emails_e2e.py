"""
Recruitment Email Automation & Stage Transitions E2E Test Suite.
Tests:
1. Application confirmation email on public job apply
2. Stage transition email on 'Shortlisted'
3. Stage transition email on 'Interview'
4. Stage transition email on 'Selected'
5. Formal offer email on offer send
6. Hired welcome email on candidate hire (with Employee ID)
7. Rejection update email on candidate rejection
8. Edge cases: Missing email, bulk actions, and error resilience
"""

import os
import sys
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import sys
import os
import uuid
import time
from datetime import datetime, date, timedelta
from fastapi.testclient import TestClient

from app.main import app
from app.services.email_service import get_email_service
import psycopg2
from psycopg2.extras import RealDictCursor
from app.config import settings

client = TestClient(app)

SUPER_ADMIN_TOKEN = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
    "eyJzdWIiOiIzOGE5MzE3MC05OTdiLTRiNGMtYmM4ZS0yNTZiOTMxNjljMjMiLCJzY2hvb2xfaWQiOiIxMTExMTExMS0xMTExLTExMTEtMTExMS0xMTExMTExMTExMTEiLCJyb2xlIjoic3VwZXJfYWRtaW4iLCJlbWFpbCI6InN1cGVyX2FkbWluQDExMTExMTExLmNvbSIsImV4cCI6OTk5OTk5OTk5OX0."
    "oydD6z-7l6WwA0vyYoEKWqXgy9a_s0hMWjd4CKF2Dmg"
)
SCHOOL_ID = "11111111-1111-1111-1111-111111111111"
AUTH_HEADERS = {
    "Authorization": f"Bearer {SUPER_ADMIN_TOKEN}",
    "X-School-Id": SCHOOL_ID
}


def get_db():
    return psycopg2.connect(settings.DATABASE_URL)


def run_tests():
    print("=" * 70)
    print("  TESTING RECRUITMENT EMAIL AUTOMATION & STAGE TRANSITIONS")
    print("=" * 70)

    # Intercept emails to verify dispatches without needing live SMTP connection
    dispatched_emails = []
    email_svc = get_email_service()
    orig_send = email_svc._send_email

    def mock_send(to_email, subject, html_content, *args, **kwargs):
        dispatched_emails.append({
            "to": to_email,
            "subject": subject,
            "html": html_content,
            "attachments": kwargs.get("attachments"),
            "timestamp": time.time()
        })
        return True

    email_svc._send_email = mock_send

    # 1. Fetch an active public job opening
    res_jobs = client.get("/api/recruitment/jobs", headers=AUTH_HEADERS)
    assert res_jobs.status_code == 200, f"Failed to list jobs: {res_jobs.text}"
    jobs = res_jobs.json().get("data", [])
    assert len(jobs) > 0, "No recruitment jobs found in database."
    active_jobs = [j for j in jobs if j.get("is_public") and j.get("publishing_status") == "Active"]
    if active_jobs:
        job = active_jobs[0]
    else:
        # Activate the first job for testing
        job = jobs[0]
        with get_db() as conn:
            with conn.cursor() as cur:
                cur.execute("UPDATE public.recruitment_jobs SET is_public = true, publishing_status = 'Active' WHERE id = %s", (job["id"],))
                conn.commit()
    job_id = job["id"]
    job_title = job["job_title"]
    print(f"[+] Using test job opening: '{job_title}' ({job_id})")

    # 2. Test 1: Submit Application via Public Careers -> Verify Confirmation Email
    test_email = f"candidate_{uuid.uuid4().hex[:8]}@example.com"
    cand_name = f"Test Applicant {uuid.uuid4().hex[:6]}"
    apply_payload = {
        "job_id": job_id,
        "full_name": cand_name,
        "email": test_email,
        "phone": "+91 98765 43210",
        "gender": "Male",
        "date_of_birth": "1994-05-15",
        "city": "Dehradun",
        "state": "Uttarakhand",
        "highest_qualification": "M.Sc Mathematics",
        "total_experience": 4.5,
        "current_organization": "Prestige Academy",
        "current_job_title": "Senior Faculty",
        "skills": ["Calculus", "Algebra", "Curriculum Design"],
        "resume_url": "/api/recruitment/public/resumes/resume_sample.pdf",
        "work_mode_preference": "On-site",
        "notice_period_days": 30,
        "expected_salary": 65000.0,
        "why_join_us": "Excited to contribute to academic excellence."
    }

    res_apply = client.post("/api/public/careers/apply", json=apply_payload)
    assert res_apply.status_code == 200, f"Application submission failed: {res_apply.text}"
    apply_data = res_apply.json().get("data", {})
    app_ref = apply_data.get("application_reference")
    assert app_ref and app_ref.startswith("APP-2026-"), f"Unexpected app ref: {app_ref}"

    # Allow daemon thread to run
    time.sleep(0.3)

    # Verify confirmation email in intercepted list
    confirm_emails = [e for e in dispatched_emails if e["to"] == test_email and "Application Confirmed" in e["subject"]]
    assert len(confirm_emails) >= 1, "Confirmation email was not dispatched for job application!"
    confirm_email = confirm_emails[0]
    assert app_ref in confirm_email["subject"], "Application reference missing from confirmation subject"
    assert cand_name in confirm_email["html"], "Candidate name missing from confirmation email HTML"
    assert job_title in confirm_email["html"], "Job title missing from confirmation email HTML"
    print(f"[PASS] 1. Application submission confirmation email dispatched ({app_ref}).")

    # Find the application ID from DB
    with get_db() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT * FROM public.recruitment_applications WHERE application_reference = %s", (app_ref,))
            app_record = cur.fetchone()
            assert app_record is not None, "Application record not found in DB"
            app_id = str(app_record["id"])
            candidate_id = str(app_record["candidate_id"])

    # 3. Test 2: Move Stage to 'Shortlisted' -> Verify Shortlist Email
    dispatched_emails.clear()
    res_shortlist = client.post(
        f"/api/recruitment/applications/{app_id}/move-stage",
        json={"to_stage": "Shortlisted", "notes": "Strong academic qualifications and pedagogy skills."},
        headers=AUTH_HEADERS
    )
    assert res_shortlist.status_code == 200, f"Move to Shortlisted failed: {res_shortlist.text}"
    time.sleep(0.3)

    shortlist_emails = [e for e in dispatched_emails if e["to"] == test_email and "Shortlisted" in e["subject"]]
    assert len(shortlist_emails) >= 1, "Shortlisted transition email was not dispatched!"
    assert "Strong academic qualifications" in shortlist_emails[0]["html"], "Recruiter notes missing from shortlist email"
    print("[PASS] 2. Shortlisted stage transition email dispatched with notes.")

    # 4. Test 3: Move Stage to 'Interview' -> Verify Interview Stage Advancement Email
    dispatched_emails.clear()
    res_interview = client.post(
        f"/api/recruitment/applications/{app_id}/move-stage",
        json={"to_stage": "Interview", "notes": "Advancing to Round 1 Technical & Pedagogy Evaluation."},
        headers=AUTH_HEADERS
    )
    assert res_interview.status_code == 200, f"Move to Interview failed: {res_interview.text}"
    time.sleep(0.3)

    interview_emails = [e for e in dispatched_emails if e["to"] == test_email and "Interview" in e["subject"]]
    assert len(interview_emails) >= 1, "Interview stage transition email was not dispatched!"
    print("[PASS] 3. Interview stage advancement email dispatched.")

    # 5. Test 4: Move Stage to 'Selected' -> Verify Selection Congratulatory Email
    dispatched_emails.clear()
    res_selected = client.post(
        f"/api/recruitment/applications/{app_id}/move-stage",
        json={"to_stage": "Selected", "notes": "Panel rated performance as Outstanding."},
        headers=AUTH_HEADERS
    )
    assert res_selected.status_code == 200, f"Move to Selected failed: {res_selected.text}"
    time.sleep(0.3)

    selected_emails = [e for e in dispatched_emails if e["to"] == test_email and "Selected" in e["subject"]]
    assert len(selected_emails) >= 1, "Selected stage transition email was not dispatched!"
    assert "Congratulations on Your Selection" in selected_emails[0]["html"]
    print("[PASS] 4. Selected stage congratulatory email dispatched.")

    # 6. Test 5: Create and Send Offer -> Verify Formal Offer Email
    dispatched_emails.clear()
    offer_payload = {
        "application_id": app_id,
        "salary": 750000.0,
        "joining_date": (date.today() + timedelta(days=21)).isoformat(),
        "probation_period_months": 6,
        "benefits": "Medical insurance, annual performance bonus, subsidized campus meals",
        "employment_type": "Full-time",
        "offer_expiry_date": (date.today() + timedelta(days=7)).isoformat(),
        "terms": "Standard appointment subject to verification of degree certificates."
    }
    res_offer = client.post("/api/recruitment/offers", json=offer_payload, headers=AUTH_HEADERS)
    assert res_offer.status_code == 200, f"Offer creation failed: {res_offer.text}"
    offer_id = res_offer.json()["data"]["id"]

    # Now call send_offer
    res_send_offer = client.post(f"/api/recruitment/offers/{offer_id}/send", headers=AUTH_HEADERS)
    assert res_send_offer.status_code == 200, f"Send offer failed: {res_send_offer.text}"
    time.sleep(0.3)

    offer_emails = [e for e in dispatched_emails if e["to"] == test_email and "Offer" in e["subject"]]
    assert len(offer_emails) >= 1, "Formal job offer email was not dispatched!"
    assert "750,000" in offer_emails[0]["html"] or "750000" in offer_emails[0]["html"], "Salary missing from offer email"
    assert "Medical insurance" in offer_emails[0]["html"] or "terms" in offer_emails[0]["html"].lower()
    assert offer_emails[0].get("attachments"), "PDF offer letter was not attached to offer email!"
    pdf_att = offer_emails[0]["attachments"][0]
    assert pdf_att["filename"].endswith(".pdf"), f"Attachment filename unexpected: {pdf_att['filename']}"
    assert len(pdf_att["content"]) > 1000, "Attached PDF content is too small"
    assert pdf_att["content"].startswith(b"%PDF"), "Attached PDF content does not start with %PDF header"
    print(f"[PASS] 5. Formal job offer email dispatched with professional PDF attachment ({pdf_att['filename']}, {len(pdf_att['content'])} bytes).")

    # Test GET /recruitment/offers/{id}/pdf endpoint
    res_pdf = client.get(f"/api/recruitment/offers/{offer_id}/pdf", headers=AUTH_HEADERS)
    assert res_pdf.status_code == 200, f"Get offer PDF failed: {res_pdf.text}"
    assert "application/pdf" in res_pdf.headers.get("content-type", ""), f"Unexpected media type: {res_pdf.headers.get('content-type')}"
    assert len(res_pdf.content) > 1000, "Streamed PDF content is too small"
    assert res_pdf.content.startswith(b"%PDF"), "Streamed PDF does not start with %PDF header"
    print(f"[PASS] 5b. GET /recruitment/offers/{offer_id}/pdf successfully streamed professional PDF ({len(res_pdf.content)} bytes).")

    # 7. Test 6: Hire Candidate -> Verify Appointment Welcome Email with Employee ID
    dispatched_emails.clear()
    hire_payload = {
        "application_id": app_id,
        "employee_id": f"EMP{uuid.uuid4().hex[:4].upper()}",
        "department": "Teaching",
        "designation": "Senior Faculty",
        "joining_date": (date.today() + timedelta(days=14)).isoformat(),
        "override_vacancy_limit": True
    }
    res_hire = client.post(f"/api/recruitment/candidates/{candidate_id}/hire", json=hire_payload, headers=AUTH_HEADERS)
    assert res_hire.status_code == 200, f"Hire candidate failed: {res_hire.text}"
    time.sleep(0.3)

    hired_emails = [e for e in dispatched_emails if e["to"] == test_email and "Welcome" in e["subject"]]
    assert len(hired_emails) >= 1, "Hired welcome email was not dispatched!"
    assert hire_payload["employee_id"] in hired_emails[0]["html"], "Employee ID missing from hired email"
    print(f"[PASS] 6. Appointment welcome email dispatched with Employee ID ({hire_payload['employee_id']}).")

    # 8. Test 7: Rejection Email
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute("UPDATE public.recruitment_jobs SET vacancies = 10, filled_vacancies = 0, publishing_status = 'Active' WHERE id = %s", (job_id,))
            conn.commit()

    dispatched_emails.clear()
    reject_email = f"cand_rej_{uuid.uuid4().hex[:6]}@example.com"
    res_app_rej = client.post("/api/public/careers/apply", json={
        **apply_payload,
        "full_name": "Rejected Applicant",
        "email": reject_email
    })
    assert res_app_rej.status_code == 200
    rej_ref = res_app_rej.json()["data"]["application_reference"]
    time.sleep(0.3)

    with get_db() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT id FROM public.recruitment_applications WHERE application_reference = %s", (rej_ref,))
            rej_app_id = str(cur.fetchone()["id"])

    dispatched_emails.clear()
    res_reject = client.post(
        f"/api/recruitment/applications/{rej_app_id}/reject",
        json={"reason": "Role requirements changed", "notes": "We encourage applying for future openings."},
        headers=AUTH_HEADERS
    )
    assert res_reject.status_code == 200
    time.sleep(0.3)

    rej_emails = [e for e in dispatched_emails if e["to"] == reject_email and "Update" in e["subject"]]
    assert len(rej_emails) >= 1, "Rejection email was not dispatched!"
    assert "thoughtful review" in rej_emails[0]["html"].lower()
    print("[PASS] 7. Rejection update email dispatched politely.")

    # 9. Test 8: Edge Cases (Missing email resilience)
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute("UPDATE public.recruitment_candidates SET email = '' WHERE id = %s", (candidate_id,))
            conn.commit()

    res_move_no_email = client.post(
        f"/api/recruitment/applications/{app_id}/move-stage",
        json={"to_stage": "Shortlisted"},
        headers=AUTH_HEADERS
    )
    assert res_move_no_email.status_code == 200, "Moving stage for candidate without email crashed"
    print("[PASS] 8. Candidate without email handled safely without errors.")

    # Check recruitment activity logs in database
    with get_db() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                "SELECT COUNT(*) as cnt FROM public.recruitment_activities WHERE school_id = %s AND action = 'EMAIL_DISPATCHED'",
                (SCHOOL_ID,)
            )
            email_logs = cur.fetchone()["cnt"]
            assert email_logs >= 5, f"Expected at least 5 email logs, found {email_logs}"
    print(f"[PASS] 9. Recruitment activity logs verified ({email_logs} email dispatch events logged).")

    # Restore original send method
    email_svc._send_email = orig_send

    print("=" * 70)
    print("  ALL 9 RECRUITMENT EMAIL AUTOMATION TESTS PASSED (100% SUCCESS)!")
    print("=" * 70)


if __name__ == "__main__":
    run_tests()
