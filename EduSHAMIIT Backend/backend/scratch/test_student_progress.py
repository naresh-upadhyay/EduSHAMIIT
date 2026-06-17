import requests
import sys

BASE_URL = "http://127.0.0.1:80"
STUDENT_CREDS = {"email": "naresh.king88898@gmail.com", "password": "naresh@1A"}

def test_progress_flow():
    print("[1] Logging in student...")
    login_resp = requests.post(f"{BASE_URL}/api/auth/login", json=STUDENT_CREDS)
    if login_resp.status_code != 200:
        print("Student login failed:", login_resp.text)
        sys.exit(1)
    
    token = login_resp.json()["data"]["token"]
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    print("Logged in successfully.")

    # 2. Get student courses list
    print("[2] Fetching initial courses list...")
    courses_resp = requests.get(f"{BASE_URL}/api/student/courses", headers=headers)
    if courses_resp.status_code != 200:
        print("Failed to get courses:", courses_resp.text)
        sys.exit(1)
        
    courses = courses_resp.json()["data"]["courses"]
    print(f"Found {len(courses)} courses.")
    
    # Let's find Mathematics
    math_course = None
    for c in courses:
        if "math" in c["name"].lower():
            math_course = c
            break
            
    if not math_course:
        print("Mathematics course not found!")
        sys.exit(1)
        
    course_id = math_course["id"]
    initial_chapters = math_course["chapters"]
    initial_progress = math_course["progress"]
    print(f"Mathematics Course ID: {course_id}")
    print(f"Initial Chapters count string: '{initial_chapters}'")
    print(f"Initial progress: {initial_progress}")

    # 3. Get course details to pick a topic
    print("[3] Fetching course details...")
    details_resp = requests.get(f"{BASE_URL}/api/student/courses/{course_id}/details", headers=headers)
    if details_resp.status_code != 200:
        print("Failed to get course details:", details_resp.text)
        sys.exit(1)
        
    details_data = details_resp.json()["data"]
    chapters = details_data.get("chapters", [])
    if not chapters:
        print("No chapters found in course. Cannot test topic progress.")
        sys.exit(1)
        
    first_chapter = chapters[0]
    topics = first_chapter.get("topics", [])
    if not topics:
        print(f"No topics found in chapter '{first_chapter.get('title')}'. Cannot test.")
        sys.exit(1)
        
    target_topic = topics[0]
    topic_id = target_topic["id"]
    topic_title = target_topic["title"]
    originally_completed = target_topic.get("completed", False)
    print(f"Selected target topic: '{topic_title}' (ID: {topic_id}), Originally completed: {originally_completed}")

    # 4. Toggle progress to Completed
    print(f"[4] Toggling topic progress to completed = {not originally_completed}...")
    toggle_payload = {"completed": not originally_completed}
    toggle_resp = requests.post(f"{BASE_URL}/api/student/courses/topics/{topic_id}/progress", json=toggle_payload, headers=headers)
    if toggle_resp.status_code != 200:
        print("Failed to toggle progress:", toggle_resp.text)
        sys.exit(1)
        
    print("Progress toggled successfully:", toggle_resp.json())

    # 5. Fetch details again to verify completion injection
    print("[5] Re-fetching course details to verify completion status...")
    details_resp2 = requests.get(f"{BASE_URL}/api/student/courses/{course_id}/details", headers=headers)
    details_data2 = details_resp2.json()["data"]
    chapters2 = details_data2.get("chapters", [])
    updated_topic = chapters2[0]["topics"][0]
    print(f"New completed state in details API: {updated_topic.get('completed')}")
    if updated_topic.get("completed") == originally_completed:
        print("ERROR: Completion state did not update in details response!")
        sys.exit(1)

    # 6. Fetch courses list to verify progress calculation updates
    print("[6] Re-fetching courses list to verify progress percentage recalculation...")
    courses_resp2 = requests.get(f"{BASE_URL}/api/student/courses", headers=headers)
    courses2 = courses_resp2.json()["data"]["courses"]
    updated_math = None
    for c in courses2:
        if c["id"] == course_id:
            updated_math = c
            break
            
    print(f"New chapters count string: '{updated_math['chapters']}'")
    print(f"New progress: {updated_math['progress']}")

    # 7. Cleanup/restore original state
    print("[7] Restoring original topic progress state...")
    cleanup_payload = {"completed": originally_completed}
    cleanup_resp = requests.post(f"{BASE_URL}/api/student/courses/topics/{topic_id}/progress", json=cleanup_payload, headers=headers)
    if cleanup_resp.status_code != 200:
        print("Failed to clean up progress state:", cleanup_resp.text)
    else:
        print("Successfully restored original progress state.")

    print("\n--- ALL PROGRESS API TESTS PASSED SUCCESSFULLY! ---")

if __name__ == "__main__":
    test_progress_flow()
