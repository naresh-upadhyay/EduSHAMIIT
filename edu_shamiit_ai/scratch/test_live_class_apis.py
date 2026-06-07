import requests
import json

BASE_URL = "http://127.0.0.1:80"

STUDENT_CREDS = {"email": "naresh.king88898@gmail.com", "password": "naresh@1A"}
TEACHER_CREDS = {"email": "nehaupadhyay9119@gmail.com", "password": "naresh@1A"}

def run_tests():
    # 1. Login Teacher and Student
    print("Logging in teacher...")
    t_resp = requests.post(f"{BASE_URL}/api/auth/login", json=TEACHER_CREDS)
    if t_resp.status_code != 200:
        print(f"Teacher login failed: {t_resp.text}")
        return
    t_token = t_resp.json()["data"]["token"]
    t_headers = {"Authorization": f"Bearer {t_token}"}
    print("Teacher logged in.")

    print("\nLogging in student...")
    s_resp = requests.post(f"{BASE_URL}/api/auth/login", json=STUDENT_CREDS)
    if s_resp.status_code != 200:
        print(f"Student login failed: {s_resp.text}")
        return
    s_token = s_resp.json()["data"]["token"]
    s_headers = {"Authorization": f"Bearer {s_token}"}
    print("Student logged in.")

    # 2. Schedule a Live Class using Teacher token to get a valid live class ID
    print("\nFetching teacher live classes/subjects...")
    class_list_resp = requests.get(f"{BASE_URL}/api/teacher/live-classes", headers=t_headers)
    if class_list_resp.status_code != 200:
        print(f"Failed to fetch teacher classes: {class_list_resp.text}")
        return
    live_classes = class_list_resp.json()["data"]["live_classes"]
    
    if not live_classes:
        print("No live classes found to test with.")
        return
        
    test_class = live_classes[0]
    live_class_id = test_class["id"]
    subject_id = test_class.get("subject_id")
    print(f"Using Live Class ID: {live_class_id}, Subject: {test_class['title']}")

    # 3. Test LiveKit Token Generation
    print("\nTesting LiveKit token generation for teacher...")
    token_url = f"{BASE_URL}/api/livekit/token?room={live_class_id}"
    tok_resp = requests.get(token_url, headers=t_headers)
    if tok_resp.status_code != 200:
        print(f"Token generation failed: {tok_resp.text}")
    else:
        print("Token response:", json.dumps(tok_resp.json(), indent=2))

    # 4. Start Live Class (lifecycle)
    print(f"\nStarting live class {live_class_id}...")
    start_resp = requests.post(f"{BASE_URL}/api/live-classes/{live_class_id}/start", headers=t_headers, json={})
    if start_resp.status_code != 200:
        print(f"Start class failed: {start_resp.text}")
    else:
        print("Start class response:", start_resp.json())

    # 5. Join Live Class (student join log)
    print("\nLogging student join...")
    join_resp = requests.post(f"{BASE_URL}/api/live-classes/{live_class_id}/attendance/mark", headers=s_headers, json={"action": "join"})
    if join_resp.status_code != 200:
        print(f"Student join marking failed: {join_resp.text}")
    else:
        print("Student join logged:", join_resp.json())

    # 6. Send Live Class Chat
    print("\nSending chat message from student...")
    chat_payload = {"message": "Hello Teacher! This is a test message."}
    chat_resp = requests.post(f"{BASE_URL}/api/live-classes/{live_class_id}/chat", headers=s_headers, json=chat_payload)
    if chat_resp.status_code != 200:
        print(f"Send chat failed: {chat_resp.text}")
    else:
        print("Chat message sent:", chat_resp.json())

    # 7. Get Chat History
    print("\nFetching chat history...")
    hist_resp = requests.get(f"{BASE_URL}/api/live-classes/{live_class_id}/chat", headers=s_headers)
    if hist_resp.status_code != 200:
        print(f"Get chat history failed: {hist_resp.text}")
    else:
        print("Chat history count:", len(hist_resp.json()["data"]["chats"]))
        print("Latest chat message:", hist_resp.json()["data"]["chats"][-1])

    # 8. Student leaves Live Class (leave log)
    print("\nLogging student leave...")
    leave_resp = requests.post(f"{BASE_URL}/api/live-classes/{live_class_id}/attendance/mark", headers=s_headers, json={"action": "leave"})
    if leave_resp.status_code != 200:
        print(f"Student leave marking failed: {leave_resp.text}")
    else:
        print("Student leave logged:", leave_resp.json())

    # 9. End Live Class (lifecycle + auto attendance)
    print(f"\nEnding live class {live_class_id}...")
    end_resp = requests.post(f"{BASE_URL}/api/live-classes/{live_class_id}/end", headers=t_headers, json={})
    if end_resp.status_code != 200:
        print(f"End class failed: {end_resp.text}")
    else:
        print("End class response:", end_resp.json())

    # 10. Get Attendance Report
    print("\nFetching attendance report...")
    att_resp = requests.get(f"{BASE_URL}/api/live-classes/{live_class_id}/attendance", headers=t_headers)
    if att_resp.status_code != 200:
        print(f"Get attendance report failed: {att_resp.text}")
    else:
        print("Attendance report data:", json.dumps(att_resp.json(), indent=2))

    # 11. List Recordings
    print("\nListing recordings...")
    rec_resp = requests.get(f"{BASE_URL}/api/live-classes/{live_class_id}/recordings", headers=t_headers)
    if rec_resp.status_code != 200:
        print(f"List recordings failed: {rec_resp.text}")
    else:
        print("Recordings:", json.dumps(rec_resp.json(), indent=2))

if __name__ == "__main__":
    run_tests()
