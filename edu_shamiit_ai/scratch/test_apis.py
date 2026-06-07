import requests
import json

BASE_URL = "http://127.0.0.1:80"

# Student credentials from seeder
STUDENT_EMAIL = "naresh.king88898@gmail.com"
STUDENT_CREDS = {"email": STUDENT_EMAIL, "password": "naresh@1A"}

def run_tests():
    # 1. Login student
    print("Logging in student...")
    resp = requests.post(f"{BASE_URL}/api/auth/login", json=STUDENT_CREDS)
    if resp.status_code != 200 or not resp.json().get("success"):
        print(f"Failed login: {resp.status_code} {resp.text}")
        return
    token = resp.json()["data"]["token"]
    headers = {"Authorization": f"Bearer {token}"}
    print("Login success! Token retrieved.")

    # 2. Get timetable
    print("\nFetching student timetable...")
    tt_resp = requests.get(f"{BASE_URL}/api/student/timetable", headers=headers)
    if tt_resp.status_code != 200:
        print(f"Failed timetable: {tt_resp.status_code} {tt_resp.text}")
    else:
        print("Timetable response structure:")
        tt_data = tt_resp.json()
        print(json.dumps(tt_data, indent=2)[:1000] + "\n...")

    # 3. Post a comment (Question)
    class_id = "3f2433df-34df-4073-b782-647eabded519"
    comment_payload = {
        "comment": "Can we review the proof of the product rule?"
    }
    print(f"\nPosting a top-level question to live class {class_id}...")
    c_resp = requests.post(f"{BASE_URL}/api/student/live-classes/{class_id}/comments", headers=headers, json=comment_payload)
    if c_resp.status_code != 200:
        print(f"Failed posting comment: {c_resp.status_code} {c_resp.text}")
        return
    parent_comment = c_resp.json()["data"]
    parent_id = parent_comment["id"]
    print(f"Comment posted successfully. ID: {parent_id}")

    # 4. Reply to the comment
    reply_payload = {
        "comment": "Yes, I also want to cover the quotient rule!",
        "parent_id": parent_id
    }
    print(f"\nReplying to comment {parent_id}...")
    r_resp = requests.post(f"{BASE_URL}/api/student/live-classes/{class_id}/comments", headers=headers, json=reply_payload)
    if r_resp.status_code != 200:
        print(f"Failed replying: {r_resp.status_code} {r_resp.text}")
    else:
        print("Reply posted successfully!")

    # 5. Fetch comments
    print("\nFetching comments for live class...")
    get_resp = requests.get(f"{BASE_URL}/api/student/live-classes/{class_id}/comments", headers=headers)
    if get_resp.status_code != 200:
        print(f"Failed fetching comments: {get_resp.status_code} {get_resp.text}")
    else:
        comments_data = get_resp.json()
        print("Comments tree:")
        print(json.dumps(comments_data, indent=2))

if __name__ == "__main__":
    run_tests()
