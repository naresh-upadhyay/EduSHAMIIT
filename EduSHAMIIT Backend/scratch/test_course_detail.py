import requests

BASE_URL = "http://127.0.0.1:80"
STUDENT_CREDS = {"email": "naresh.king88898@gmail.com", "password": "naresh@1A"}
STUDENT_ADMIN_CREDS = {"email": "temp_student_admin@gmail.com", "password": "TempPassword1A"}

# 1. Login student admin
resp = requests.post(f"{BASE_URL}/api/auth/login", json=STUDENT_ADMIN_CREDS)
sa_token = resp.json().get("data", {}).get("token", "")
sa_headers = {"Authorization": f"Bearer {sa_token}"}

# 2. Get students lists to find school_id and class
stud_list = requests.get(f"{BASE_URL}/api/admin/students/list", headers=sa_headers).json()
students = stud_list.get("data", {}).get("students", [])
student_class = students[0]["class"] if students else "10A"

# 3. Create subject
sub_data = {"name": "Temp Test Subject 2", "class": student_class, "icon": "📐", "color": "#4F46E5"}
resp_sub = requests.post(f"{BASE_URL}/api/admin/students/subjects", headers=sa_headers, json=sub_data)
new_sub_id = resp_sub.json().get("data", {}).get("id")

print(f"Created temporary subject ID: {new_sub_id}")

# 4. Create course
course_data = {
    "subject_id": new_sub_id,
    "title": "Temp Test Course 2",
    "description": "Auto generated course 2",
    "is_published": True,
    "syllabus_coverage": [
        {"topic": "Calculus", "progress": 0.85, "status": "success"},
        {"topic": "Linear Algebra", "progress": 0.5, "status": "warning"}
    ],
    "upcoming_topics": ["Fourier Series", "Complex Analysis"],
    "resources_text": "8 lecture videos, 4 tutorial sheets",
    "chapters_count": "32 chapters"
}
resp_course = requests.post(f"{BASE_URL}/api/admin/students/courses", headers=sa_headers, json=course_data)
new_course_id = resp_course.json().get("data", {}).get("id")
print(f"Created temporary course: {resp_course.json()}")

# 5. Update course
update_payload = {
    "title": "Updated Temp Course 2",
    "upcoming_topics": ["Fourier Series", "Complex Analysis", "Numerical Methods"]
}
resp_put = requests.put(f"{BASE_URL}/api/admin/students/courses/{new_course_id}", headers=sa_headers, json=update_payload)
print(f"Updated course response: {resp_put.json()}")

# 6. Fetch using student token
resp_login_s = requests.post(f"{BASE_URL}/api/auth/login", json=STUDENT_CREDS)
s_token = resp_login_s.json().get("data", {}).get("token", "")
s_headers = {"Authorization": f"Bearer {s_token}"}

resp_get = requests.get(f"{BASE_URL}/api/student/courses", headers=s_headers)
courses = resp_get.json().get("data", {}).get("courses", [])

created_course = next((c for c in courses if c["id"] == new_course_id), None)
print(f"\nCreated course details fetched as student:\n{created_course}")

# 7. Cleanup
requests.delete(f"{BASE_URL}/api/admin/students/courses/{new_course_id}", headers=sa_headers)
requests.delete(f"{BASE_URL}/api/admin/students/subjects/{new_sub_id}", headers=sa_headers)
print("\nCleanup completed.")
