"""
EduSHAMIIT ERP - Careers Portal & HR Recruitment Integration
Comprehensive Automated E2E Test Suite
Validates all requirements from Section 45 & 46 of the specification:
- Job Lifecycle & Visibility (Draft, Published, Paused, Closed, Expired)
- Search, Filter, Pagination, Sorting
- Public Job Details & Data Sanitization
- Public Application Submission, Reference Number Generation
- Duplicate Prevention (409 Conflict for same job + email, allows different jobs)
- Resume Upload Validation (format, size)
- HR Recruitment Pipeline Integration (Application, Candidate, Documents, Stage History, Activity Log)
- Deadline Enforcement
- Security & Server-Side Authorization
"""

import os
import sys
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))


import unittest
import requests
import json
import psycopg2
from psycopg2.extras import RealDictCursor
from datetime import datetime, date, timedelta
from app.config import settings

BASE_URL = os.environ.get("TEST_BASE_URL", os.environ.get("BASE_URL", "http://localhost:8082"))
PUBLIC_API = f"{BASE_URL}/api/public/careers"
HR_API = f"{BASE_URL}/api/recruitment"

class TestCareersPortalE2E(unittest.TestCase):
    school_id = "11111111-1111-1111-1111-111111111111"

    @classmethod
    def setUpClass(cls):
        """Set up database connection and clean test artifacts."""
        cls.conn = psycopg2.connect(settings.DATABASE_URL)
        cls.conn.autocommit = True
        cls.cur = cls.conn.cursor(cursor_factory=RealDictCursor)
        
        # Clean any prior test records
        cls._cleanup_test_data()

    @classmethod
    def tearDownClass(cls):
        """Clean test records and close connection."""
        cls._cleanup_test_data()
        cls.cur.close()
        cls.conn.close()

    @classmethod
    def _cleanup_test_data(cls):
        """Clean up test entities from the database."""
        cur = cls.cur
        cur.execute("DELETE FROM public.recruitment_candidates WHERE full_name ILIKE '%E2E%' OR email ILIKE '%e2e%'")
        cur.execute("DELETE FROM public.recruitment_jobs WHERE job_title ILIKE '%E2E%'")

    def _create_test_job(self, title="E2E Test Job Title", is_public=True, status="Active", deadline=None, work_mode="Hybrid", dept="Engineering"):
        """Helper to insert an isolated test job directly."""
        cur = self.cur
        ts = int(datetime.now().timestamp() * 1000)
        slug = f"e2e-test-{ts}"
        job_code = f"JOB-TEST-{ts}"
        cur.execute("""
            INSERT INTO public.recruitment_jobs (
                school_id, job_code, job_title, department, employment_type, work_mode,
                experience_required, salary_min, salary_max, vacancies,
                publishing_status, is_public, is_salary_public, is_openings_public,
                is_featured, slug, location, description,
                responsibilities, benefits, application_deadline, custom_questions
            ) VALUES (
                %s, %s, %s, %s, %s, %s,
                %s, %s, %s, %s,
                %s, %s, %s, %s,
                %s, %s, %s, %s,
                %s, %s, %s, %s
            ) RETURNING id, slug;
        """, (
            self.school_id, job_code, title, dept, "Full-time", work_mode,
            "3-5 Years", 80000, 120000, 3,
            status, is_public, False, True,
            True, slug, "Main Campus", "Exciting opportunity to join EduSHAMIIT team.",
            "Teach and mentor students.", "Health insurance, PF",
            deadline, json.dumps([{"id": "q1", "question": "Are you comfortable working on-site?", "type": "yes_no", "required": True}])
        ))
        row = cur.fetchone()
        return str(row['id']), row['slug']

    # =========================================================================
    # A. JOB CREATION & VISIBILITY RULES (Tests 1 - 10)
    # =========================================================================

    def test_01_draft_job_not_visible_publicly(self):
        """1 & 2. Draft/Inactive job must NOT appear in public careers listing."""
        job_id, slug = self._create_test_job(title="E2E Test Job Draft", is_public=False, status="Draft")
        resp = requests.get(f"{PUBLIC_API}/jobs")
        self.assertEqual(resp.status_code, 200)
        jobs = resp.json().get("data", [])
        slugs = [j["slug"] for j in jobs]
        self.assertNotIn(slug, slugs, "Draft job must not appear in public listing")

    def test_02_published_job_visible_publicly(self):
        """3 & 4. Published + Active job must appear in public careers listing."""
        job_id, slug = self._create_test_job(title="E2E Test Job Active Public", is_public=True, status="Active")
        resp = requests.get(f"{PUBLIC_API}/jobs?search=Active+Public")
        self.assertEqual(resp.status_code, 200)
        jobs = resp.json().get("data", [])
        slugs = [j["slug"] for j in jobs]
        self.assertIn(slug, slugs, "Published active job must appear in public listing")

    def test_03_private_job_not_visible_publicly(self):
        """5 & 6. Active job with is_public=False must NOT appear in public careers."""
        job_id, slug = self._create_test_job(title="E2E Test Job Internal Only", is_public=False, status="Active")
        resp = requests.get(f"{PUBLIC_API}/jobs?search=Internal+Only")
        self.assertEqual(resp.status_code, 200)
        jobs = resp.json().get("data", [])
        slugs = [j["slug"] for j in jobs]
        self.assertNotIn(slug, slugs, "Internal-only job must not appear in public listing")

    def test_04_paused_job_not_visible_publicly(self):
        """7 & 8. Paused job must NOT appear in public listing."""
        job_id, slug = self._create_test_job(title="E2E Test Job Paused", is_public=True, status="Paused")
        resp = requests.get(f"{PUBLIC_API}/jobs?search=Paused")
        self.assertEqual(resp.status_code, 200)
        jobs = resp.json().get("data", [])
        slugs = [j["slug"] for j in jobs]
        self.assertNotIn(slug, slugs, "Paused job must not appear in public listing")

    def test_05_closed_job_not_applicable(self):
        """9 & 10. Closed job cannot receive applications."""
        job_id, slug = self._create_test_job(title="E2E Test Job Closed", is_public=True, status="Closed")
        resp = requests.get(f"{PUBLIC_API}/jobs/{slug}")
        self.assertEqual(resp.status_code, 200)
        data = resp.json().get("data", {})
        self.assertFalse(data.get("can_apply"), "can_apply must be False for closed job")
        self.assertIn("closed", data.get("status_message", "").lower())

        # Attempt application submission -> must be rejected
        payload = {
            "job_id": job_id,
            "full_name": "E2E Test Candidate",
            "email": "e2etest_closed@example.com",
            "phone": "+919876543210",
            "resume_url": "/api/public/careers/resumes/dummy.pdf"
        }
        sub_resp = requests.post(f"{PUBLIC_API}/apply", json=payload)
        self.assertEqual(sub_resp.status_code, 400, "Applying to a closed job must return 400 Bad Request")

    # =========================================================================
    # B. CAREERS SEARCH & FILTERS (Tests 11 - 22)
    # =========================================================================

    def test_06_search_by_title_and_keyword(self):
        """11 & 12. Search jobs by title/keyword."""
        job_id, slug = self._create_test_job(title="E2E Test Job Quantum Physics Lecturer")
        resp = requests.get(f"{PUBLIC_API}/jobs?search=Quantum+Physics")
        self.assertEqual(resp.status_code, 200)
        jobs = resp.json().get("data", [])
        self.assertTrue(any(j["slug"] == slug for j in jobs))

    def test_07_filter_by_department(self):
        """14. Filter jobs by department."""
        job_id, slug = self._create_test_job(title="E2E Test Job Roboticist", dept="Robotics Lab")
        resp = requests.get(f"{PUBLIC_API}/jobs?department=Robotics+Lab")
        self.assertEqual(resp.status_code, 200)
        jobs = resp.json().get("data", [])
        self.assertTrue(any(j["slug"] == slug for j in jobs))
        for j in jobs:
            self.assertEqual(j["department"], "Robotics Lab")

    def test_08_filter_by_work_mode(self):
        """16. Filter jobs by work mode (Remote/Hybrid/On-site)."""
        job_id, slug = self._create_test_job(title="E2E Test Job Remote Specialist", work_mode="Remote")
        resp = requests.get(f"{PUBLIC_API}/jobs?work_mode=Remote")
        self.assertEqual(resp.status_code, 200)
        jobs = resp.json().get("data", [])
        self.assertTrue(any(j["slug"] == slug for j in jobs))
        for j in jobs:
            self.assertEqual(j["work_mode"], "Remote")

    def test_09_pagination_and_total(self):
        """21. Pagination returns valid page, page_size, total, total_pages."""
        resp = requests.get(f"{PUBLIC_API}/jobs?page=1&page_size=3")
        self.assertEqual(resp.status_code, 200)
        body = resp.json()
        self.assertIn("data", body)
        self.assertIn("pagination", body)
        pag = body["pagination"]
        self.assertEqual(pag["page"], 1)
        self.assertEqual(pag["page_size"], 3)
        self.assertGreaterEqual(pag["total_records"], 1)
        self.assertLessEqual(len(body["data"]), 3)

    def test_10_empty_search_result(self):
        """20. Search with non-matching term returns 0 results gracefully."""
        resp = requests.get(f"{PUBLIC_API}/jobs?search=XYZNonExistentKeyword998877")
        self.assertEqual(resp.status_code, 200)
        body = resp.json()
        self.assertEqual(len(body.get("data", [])), 0)
        self.assertEqual(body.get("pagination", {}).get("total_records", 0), 0)

    # =========================================================================
    # C. JOB DETAILS & DATA SANITIZATION (Tests 23 - 28)
    # =========================================================================

    def test_11_job_details_public_sanitization(self):
        """23 & 28. Valid job returns sanitized public fields; hides private salaries unless configured."""
        job_id, slug = self._create_test_job(title="E2E Test Job Sanitization")
        resp = requests.get(f"{PUBLIC_API}/jobs/{slug}")
        self.assertEqual(resp.status_code, 200)
        data = resp.json().get("data", {})
        self.assertEqual(data["job_title"], "E2E Test Job Sanitization")
        # Since is_salary_public is False, salary should be hidden
        self.assertIsNone(data.get("salary_range"))
        self.assertTrue(data.get("can_apply"))
        self.assertIn("custom_questions", data)

    def test_12_invalid_job_slug_returns_404(self):
        """24. Non-existent slug returns 404."""
        resp = requests.get(f"{PUBLIC_API}/jobs/completely-invalid-slug-123456")
        self.assertEqual(resp.status_code, 404)

    # =========================================================================
    # D. APPLICATION SUBMISSION & VALIDATION (Tests 29 - 40)
    # =========================================================================

    def test_13_successful_public_application(self):
        """29, 39, 40. Successful public application generates reference and saves in DB."""
        job_id, slug = self._create_test_job(title="E2E Test Job Application Flow")
        email = f"e2etest_applicant_{int(datetime.now().timestamp())}@example.com"
        payload = {
            "job_id": job_id,
            "full_name": "E2E Test Applicant One",
            "email": email,
            "phone": "+91 98765 43210",
            "current_location": "Bhopal, MP",
            "total_experience": 4.5,
            "highest_qualification": "M.Tech in Computer Science",
            "skills": ["Python", "Flutter", "PostgreSQL"],
            "cover_letter": "I would love to contribute to EduSHAMIIT.",
            "why_join_us": "Strong institutional reputation and excellence.",
            "resume_url": "/api/public/careers/resumes/e2e_resume.pdf",
            "linkedin_url": "https://linkedin.com/in/e2etest",
            "work_mode_preference": "Hybrid",
            "custom_answers": {"q1": "Yes"}
        }

        resp = requests.post(f"{PUBLIC_API}/apply", json=payload)
        self.assertEqual(resp.status_code, 200, f"Submission failed: {resp.text}")
        res_data = resp.json()
        self.assertTrue(res_data.get("success"))
        ref = res_data["data"].get("application_reference")
        self.assertTrue(ref and ref.startswith("APP-2026-"), f"Invalid ref format: {ref}")

        # Verify PostgreSQL database record in recruitment_applications
        cur = self.cur
        cur.execute("""
            SELECT a.*, c.full_name, c.email, c.source
            FROM public.recruitment_applications a
            JOIN public.recruitment_candidates c ON a.candidate_id = c.id
            WHERE a.application_reference = %s;
        """, (ref,))
        app_row = cur.fetchone()
        self.assertIsNotNone(app_row, "Application must exist in database")
        self.assertEqual(str(app_row["job_id"]), job_id)
        self.assertEqual(app_row["full_name"], "E2E Test Applicant One")
        self.assertEqual(app_row["email"], email)
        self.assertEqual(app_row["current_stage"], "Applied")
        self.assertEqual(app_row["stage_status"], "New")
        self.assertEqual(app_row["source"], "Public Careers")

    def test_14_missing_required_fields_validation(self):
        """30, 31, 32, 33. Missing or malformed required fields return 422 Unprocessable Entity."""
        job_id, slug = self._create_test_job(title="E2E Test Job Validation")
        # Missing email & invalid phone
        payload = {
            "job_id": job_id,
            "full_name": "E2E Test Incomplete",
            "phone": "abc",  # invalid phone
            "resume_url": "/api/public/careers/resumes/dummy.pdf"
        }
        resp = requests.post(f"{PUBLIC_API}/apply", json=payload)
        self.assertEqual(resp.status_code, 422)

    # =========================================================================
    # E. DUPLICATE APPLICATION PROTECTION (Tests 41 - 45)
    # =========================================================================

    def test_15_duplicate_application_blocked(self):
        """41. Same email + same job must be rejected with 409 Conflict."""
        job_id, slug = self._create_test_job(title="E2E Test Job Duplicate Protection")
        email = f"e2etest_dup_{int(datetime.now().timestamp())}@example.com"
        payload = {
            "job_id": job_id,
            "full_name": "E2E Duplicate Tester",
            "email": email,
            "phone": "+91 91234 56789",
            "resume_url": "/api/public/careers/resumes/resume1.pdf"
        }
        # First submission -> succeeds
        resp1 = requests.post(f"{PUBLIC_API}/apply", json=payload)
        self.assertEqual(resp1.status_code, 200)

        # Duplicate submission -> fails with 409
        resp2 = requests.post(f"{PUBLIC_API}/apply", json=payload)
        self.assertEqual(resp2.status_code, 409, "Duplicate submission must return 409 Conflict")
        detail = resp2.json().get("detail", {})
        msg = detail.get("message", "") if isinstance(detail, dict) else str(detail)
        self.assertIn("already applied", msg.lower())

    def test_16_same_candidate_multiple_jobs_allowed(self):
        """42 & 43. Same candidate applying for two different jobs must be allowed."""
        job1_id, _ = self._create_test_job(title="E2E Test Job Multi 1")
        job2_id, _ = self._create_test_job(title="E2E Test Job Multi 2")
        email = f"e2etest_multi_{int(datetime.now().timestamp())}@example.com"

        payload1 = {
            "job_id": job1_id,
            "full_name": "E2E Multi Job Candidate",
            "email": email,
            "phone": "+91 98888 77777",
            "resume_url": "/api/public/careers/resumes/resume.pdf"
        }
        payload2 = {
            "job_id": job2_id,
            "full_name": "E2E Multi Job Candidate",
            "email": email,
            "phone": "+91 98888 77777",
            "resume_url": "/api/public/careers/resumes/resume.pdf"
        }

        resp1 = requests.post(f"{PUBLIC_API}/apply", json=payload1)
        self.assertEqual(resp1.status_code, 200)

        resp2 = requests.post(f"{PUBLIC_API}/apply", json=payload2)
        self.assertEqual(resp2.status_code, 200, "Candidate must be permitted to apply for different jobs")

    # =========================================================================
    # F. RECRUITMENT PIPELINE INTEGRATION & AUDIT (Tests 46 - 55)
    # =========================================================================

    def test_17_pipeline_history_and_audit_log(self):
        """46, 53, 54. Verify application stage history and activity audit log."""
        job_id, slug = self._create_test_job(title="E2E Test Job Audit Flow")
        email = f"e2etest_audit_{int(datetime.now().timestamp())}@example.com"
        payload = {
            "job_id": job_id,
            "full_name": "E2E Audit Candidate",
            "email": email,
            "phone": "+91 99999 11111",
            "resume_url": "/api/public/careers/resumes/audit_resume.pdf"
        }
        resp = requests.post(f"{PUBLIC_API}/apply", json=payload)
        self.assertEqual(resp.status_code, 200)
        app_ref = resp.json()["data"]["application_reference"]

        cur = self.cur
        cur.execute("SELECT id, candidate_id FROM public.recruitment_applications WHERE application_reference = %s;", (app_ref,))
        app = cur.fetchone()
        self.assertIsNotNone(app)
        app_id = str(app["id"])
        cand_id = str(app["candidate_id"])

        # Check stage history
        cur.execute("SELECT * FROM public.recruitment_stage_history WHERE application_id = %s;", (app_id,))
        hist = cur.fetchall()
        self.assertGreaterEqual(len(hist), 1, "Initial stage history must be logged")
        self.assertEqual(hist[0]["to_stage"], "Applied")

        # Check candidate documents
        cur.execute("SELECT * FROM public.recruitment_candidate_documents WHERE candidate_id = %s;", (cand_id,))
        docs = cur.fetchall()
        self.assertGreaterEqual(len(docs), 1, "Candidate document must be registered")

        # Check activity log
        cur.execute("SELECT * FROM public.recruitment_activities WHERE candidate_id = %s;", (cand_id,))
        logs = cur.fetchall()
        self.assertGreaterEqual(len(logs), 1, "Audit activity log must be created")

    # =========================================================================
    # G. DEADLINE HANDLING (Tests 64 - 67)
    # =========================================================================

    def test_18_past_deadline_rejected(self):
        """65. Past deadline job is expired and rejects applications."""
        past_date = (date.today() - timedelta(days=5)).isoformat()
        job_id, slug = self._create_test_job(title="E2E Test Job Expired", deadline=past_date)

        # Check job details shows expired
        resp = requests.get(f"{PUBLIC_API}/jobs/{slug}")
        self.assertEqual(resp.status_code, 200)
        data = resp.json().get("data", {})
        self.assertFalse(data.get("can_apply"))
        self.assertTrue(data.get("is_expired"))
        self.assertIn("deadline", data.get("status_message", "").lower())

        # Attempt application -> rejected
        payload = {
            "job_id": job_id,
            "full_name": "E2E Late Candidate",
            "email": "e2etest_late@example.com",
            "phone": "+91 97777 66666",
            "resume_url": "/api/public/careers/resumes/resume.pdf"
        }
        sub_resp = requests.post(f"{PUBLIC_API}/apply", json=payload)
        self.assertEqual(sub_resp.status_code, 400)
        self.assertIn("deadline", sub_resp.json().get("detail", "").lower())

    def test_19_future_deadline_accepted(self):
        """64. Job with future deadline accepts applications."""
        future_date = (date.today() + timedelta(days=30)).isoformat()
        job_id, slug = self._create_test_job(title="E2E Test Job Future Deadline", deadline=future_date)

        resp = requests.get(f"{PUBLIC_API}/jobs/{slug}")
        self.assertEqual(resp.status_code, 200)
        data = resp.json().get("data", {})
        self.assertTrue(data.get("can_apply"))
        self.assertFalse(data.get("is_expired"))

    # =========================================================================
    # H. RESUME UPLOAD VALIDATION (Tests 34 - 35)
    # =========================================================================

    def test_20_resume_upload_file_types(self):
        """34. File upload endpoint validates extension (allows pdf, doc, docx, rejects exe)."""
        # Valid PDF upload
        files = {"file": ("my_resume.pdf", b"%PDF-1.4 simulated pdf content", "application/pdf")}
        resp = requests.post(f"{PUBLIC_API}/upload-resume", files=files)
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertTrue(data.get("success"))
        file_url = data.get("data", {}).get("resume_url", "")
        self.assertTrue(file_url.startswith("/api/recruitment/public/resumes/"))

        # Invalid .exe upload
        bad_files = {"file": ("malicious.exe", b"MZ simulated binary", "application/x-msdownload")}
        bad_resp = requests.post(f"{PUBLIC_API}/upload-resume", files=bad_files)
        self.assertEqual(bad_resp.status_code, 400, "Should reject non-allowed document types")

    # =========================================================================
    # I. STATS & FILTERS DYNAMIC API (Tests 5 - 6)
    # =========================================================================

    def test_21_stats_dynamic_counts(self):
        """Stats endpoint returns real counts from PostgreSQL."""
        resp = requests.get(f"{PUBLIC_API}/stats")
        self.assertEqual(resp.status_code, 200)
        stats = resp.json().get("data", {})
        self.assertIn("open_positions", stats)
        self.assertIn("departments_count", stats)
        self.assertGreater(stats["open_positions"], 0)

    def test_22_filters_dynamic_options(self):
        """Filters endpoint returns distinct options present in active public jobs."""
        resp = requests.get(f"{PUBLIC_API}/filters")
        self.assertEqual(resp.status_code, 200)
        filters = resp.json().get("data", {})
        self.assertIn("departments", filters)
        self.assertIn("locations", filters)
        self.assertIn("employment_types", filters)
        self.assertIn("work_modes", filters)
        self.assertIsInstance(filters["departments"], list)

    # =========================================================================
    # J. SECURITY & SERVER-SIDE AUTHORIZATION (Tests 56 - 63)
    # =========================================================================

    def test_23_unauthorized_access_to_hr_jobs(self):
        """56. Public unauthenticated request to HR internal jobs endpoint must be 401 Unauthorized."""
        resp = requests.get(f"{HR_API}/jobs")
        self.assertIn(resp.status_code, (401, 403), "Public user cannot query internal HR jobs API")

    def test_24_unauthorized_access_to_hr_candidates(self):
        """57. Public unauthenticated request to HR internal candidates must be 401 Unauthorized."""
        resp = requests.get(f"{HR_API}/candidates")
        self.assertIn(resp.status_code, (401, 403), "Public user cannot query internal HR candidates API")

if __name__ == "__main__":
    unittest.main(verbosity=2)
