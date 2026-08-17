"""
Comprehensive HTTP API Test Suite for Academic Class Management.
Tests all FastAPI endpoints with live JWT authentication.
"""
import sys
import os
import requests
import json
import uuid
from jose import jwt
from app.config import settings

API_BASE_URL = os.environ.get("API_BASE_URL", "http://localhost:8000")
JWT_SECRET = getattr(settings, "JWT_SECRET", "super-secret-jwt-token-key-for-edushamiit-backend-auth")

def get_test_token(user_id: str, school_id: str, role: str = "super_admin", email: str = "admin@school.com"):
    payload = {
        "sub": user_id,
        "school_id": school_id,
        "role": role,
        "email": email,
        "exp": 9999999999
    }
    return jwt.encode(payload, JWT_SECRET, algorithm="HS256")

passed = 0
failed = 0

def log_test(name: str, success: bool, detail: str = ""):
    global passed, failed
    if success:
        passed += 1
        print(f"  ✅ [PASS] {name} {detail}")
    else:
        failed += 1
        print(f"  ❌ [FAIL] {name} - {detail}")

def run_e2e_tests():
    global passed, failed
    print("\n" + "=" * 70)
    print("🌐 RUNNING FULL E2E HTTP API TEST SUITE: ACADEMIC CLASS MANAGEMENT")
    print("=" * 70)

    school_id = "11111111-1111-1111-1111-111111111111"
    user_id = "38a93170-997b-4b4c-bc8e-256b93169c23"
    token = get_test_token(user_id, school_id, "super_admin", "mathematicsking888@gmail.com")

    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }

    created_class_id = None
    created_section_id = None
    created_subject_id = None

    try:
        # 1. GET /api/classes/stats
        res = requests.get(f"{API_BASE_URL}/api/classes/stats?academic_year=2026-27", headers=headers)
        data = res.json()
        log_test(
            "GET /api/classes/stats (Academic Overview Statistics)",
            res.status_code == 200 and data.get("success") == True,
            f"Total Classes: {data.get('data', {}).get('total_classes')}"
        )

        # 2. GET /api/classes
        res = requests.get(f"{API_BASE_URL}/api/classes?academic_year=2026-27", headers=headers)
        data = res.json()
        log_test(
            "GET /api/classes (List Paginated Classes)",
            res.status_code == 200 and data.get("success") == True,
            f"Classes Count: {len(data.get('data', {}).get('classes', []))}"
        )

        # 3. POST /api/classes (Create with inline sections)
        unique_code = f"C{uuid.uuid4().hex[:4].upper()}"
        create_payload = {
            "name": f"Test Grade {unique_code}",
            "code": unique_code,
            "stage": "Secondary",
            "academic_year": "2026-27",
            "display_order": 99,
            "status": "ACTIVE",
            "sections": [
                {"name": "Section A", "code": f"{unique_code}A", "capacity": 35},
                {"name": "Section B", "code": f"{unique_code}B", "capacity": 35}
            ]
        }
        res = requests.post(f"{API_BASE_URL}/api/classes", headers=headers, json=create_payload)
        data = res.json()
        created_class_id = data.get("data", {}).get("id")
        created_sections = data.get("data", {}).get("sections", [])
        if created_sections:
            created_section_id = created_sections[0].get("id")
        log_test(
            "POST /api/classes (Create Class + 2 Inline Sections)",
            res.status_code == 200 and data.get("success") == True and len(created_sections) == 2,
            f"Created Class ID: {created_class_id}"
        )

        # 4. POST /api/classes (Duplicate Code Rejected)
        res = requests.post(f"{API_BASE_URL}/api/classes", headers=headers, json=create_payload)
        log_test(
            "POST /api/classes (Duplicate Code Rejected with 409)",
            res.status_code == 409
        )

        # 5. GET /api/classes/{id} (Detail)
        res = requests.get(f"{API_BASE_URL}/api/classes/{created_class_id}", headers=headers)
        data = res.json()
        log_test(
            "GET /api/classes/{id} (Class Full Detail with Sections)",
            res.status_code == 200 and len(data.get("data", {}).get("sections", [])) == 2
        )

        # 6. PATCH /api/classes/{id} (Update)
        update_payload = {"name": f"Updated Grade {unique_code}", "status": "ACTIVE"}
        res = requests.patch(f"{API_BASE_URL}/api/classes/{created_class_id}", headers=headers, json=update_payload)
        data = res.json()
        log_test(
            "PATCH /api/classes/{id} (Update Class Display Name)",
            res.status_code == 200 and data.get("data", {}).get("name") == f"Updated Grade {unique_code}"
        )

        # 7. GET /api/classes/sections/all
        res = requests.get(f"{API_BASE_URL}/api/classes/sections/all?academic_year=2026-27", headers=headers)
        data = res.json()
        log_test(
            "GET /api/classes/sections/all (List All Sections)",
            res.status_code == 200 and len(data.get("data", {}).get("sections", [])) > 0
        )

        # 8. POST /api/classes/sections (Add Standalone Section)
        sec_payload = {
            "class_id": created_class_id,
            "name": "Section C",
            "code": f"{unique_code}C",
            "capacity": 30,
            "academic_year": "2026-27",
            "status": "ACTIVE"
        }
        res = requests.post(f"{API_BASE_URL}/api/classes/sections", headers=headers, json=sec_payload)
        data = res.json()
        log_test(
            "POST /api/classes/sections (Add Standalone Section C)",
            res.status_code == 200 and data.get("success") == True
        )

        # 9. GET /api/classes/subjects/all
        res = requests.get(f"{API_BASE_URL}/api/classes/subjects/all", headers=headers)
        data = res.json()
        log_test(
            "GET /api/classes/subjects/all (List Subjects Catalog)",
            res.status_code == 200 and len(data.get("data", {}).get("subjects", [])) > 0
        )

        # 10. POST /api/classes/subjects (Create Subject)
        sub_code = f"SUB{uuid.uuid4().hex[:3].upper()}"
        sub_payload = {
            "name": f"Robotics {sub_code}",
            "code": sub_code,
            "type": "Practical",
            "description": "Hands-on robotics laboratory",
            "periods_per_week": 3,
            "status": "ACTIVE",
            "class_ids": [created_class_id]
        }
        res = requests.post(f"{API_BASE_URL}/api/classes/subjects", headers=headers, json=sub_payload)
        data = res.json()
        created_subject_id = data.get("data", {}).get("id")
        log_test(
            "POST /api/classes/subjects (Create Subject Catalog Item)",
            res.status_code == 200 and data.get("success") == True,
            f"Subject ID: {created_subject_id}"
        )

        # 11. GET /api/classes/users/teachers
        res = requests.get(f"{API_BASE_URL}/api/classes/users/teachers", headers=headers)
        data = res.json()
        teachers_list = data.get("data", [])
        log_test(
            "GET /api/classes/users/teachers (Teacher Picker API)",
            res.status_code == 200 and isinstance(teachers_list, list)
        )

        # 12. GET /api/classes/users/students
        res = requests.get(f"{API_BASE_URL}/api/classes/users/students?academic_year=2026-27", headers=headers)
        data = res.json()
        students_list = data.get("data", [])
        log_test(
            "GET /api/classes/users/students (Student Picker API)",
            res.status_code == 200 and isinstance(students_list, list)
        )

        # 13. POST /api/classes/{id}/teachers (Assign Class Teachers)
        if teachers_list:
            teacher_id_to_assign = teachers_list[0]["id"]
            assign_t_payload = {"teacher_ids": [teacher_id_to_assign], "academic_year": "2026-27"}
            res = requests.post(f"{API_BASE_URL}/api/classes/{created_class_id}/teachers", headers=headers, json=assign_t_payload)
            data = res.json()
            log_test(
                "POST /api/classes/{id}/teachers (Assign Teacher)",
                res.status_code == 200 and data.get("success") == True
            )

        # 14. POST /api/classes/{id}/students (Assign Students)
        if students_list:
            student_id_to_assign = students_list[0]["id"]
            assign_s_payload = {"student_ids": [student_id_to_assign], "academic_year": "2026-27", "confirm_move": True}
            res = requests.post(f"{API_BASE_URL}/api/classes/{created_class_id}/students?section_id={created_section_id}", headers=headers, json=assign_s_payload)
            data = res.json()
            log_test(
                "POST /api/classes/{id}/students (Assign Student to Section)",
                res.status_code == 200 and data.get("success") == True
            )

        # 15. POST /api/classes/{id}/subjects (Manage Subjects)
        if created_subject_id:
            sub_assign_payload = {"subject_ids": [created_subject_id], "academic_year": "2026-27"}
            res = requests.post(f"{API_BASE_URL}/api/classes/{created_class_id}/subjects", headers=headers, json=sub_assign_payload)
            data = res.json()
            log_test(
                "POST /api/classes/{id}/subjects (Assign Subject to Class)",
                res.status_code == 200 and data.get("success") == True
            )

        # 16. DELETE /api/classes/{id} (Archive with force=True)
        res = requests.delete(f"{API_BASE_URL}/api/classes/{created_class_id}?force=true", headers=headers)
        data = res.json()
        log_test(
            "DELETE /api/classes/{id}?force=true (Archive Class & Cascade Sections)",
            res.status_code == 200 and data.get("success") == True
        )

        # 17. DELETE /api/classes/subjects/{id} (Archive Subject)
        if created_subject_id:
            res = requests.delete(f"{API_BASE_URL}/api/classes/subjects/{created_subject_id}?force=true", headers=headers)
            log_test(
                "DELETE /api/classes/subjects/{id} (Archive Subject)",
                res.status_code == 200
            )

    finally:
        pass

    print("\n" + "=" * 70)
    total = passed + failed
    print(f"📊 HTTP API RESULTS: {passed} PASSED | {failed} FAILED (Total: {total})")
    print(f"🎯 SUCCESS RATE: {(passed / total * 100.0) if total > 0 else 0:.1f}%")
    print("=" * 70 + "\n")

    if failed > 0:
        sys.exit(1)

if __name__ == "__main__":
    run_e2e_tests()
