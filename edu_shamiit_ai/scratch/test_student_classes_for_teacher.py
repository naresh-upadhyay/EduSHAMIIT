import requests
import json

BASE_URL = "http://127.0.0.1:80"
TEACHER_CREDS = {"email": "nehaupadhyay9119@gmail.com", "password": "naresh@1A"}

def run_test():
    print("Logging in teacher...")
    resp = requests.post(f"{BASE_URL}/api/auth/login", json=TEACHER_CREDS)
    if resp.status_code != 200:
        print(f"Login failed: {resp.text}")
        return
    token = resp.json()["data"]["token"]
    headers = {"Authorization": f"Bearer {token}"}
    
    print("\nCalling GET /api/student/live-classes with teacher token...")
    r = requests.get(f"{BASE_URL}/api/student/live-classes", headers=headers)
    print("Status Code:", r.status_code)
    try:
        data = r.json()
        print("Response Success:", data.get("success"))
        if data.get("success"):
            print("Live classes count:", len(data["data"]["live"]))
            print("Upcoming classes count:", len(data["data"]["upcoming"]))
            print("Recorded classes count:", len(data["data"]["recorded"]))
            print("Recorded classes sample:")
            for item in data["data"]["recorded"][:2]:
                print(f" - ID: {item['id']}, Title: {item['subject']}")
        else:
            print("Message:", data.get("message"))
    except Exception as e:
        print("Raw response:", r.text)

if __name__ == "__main__":
    run_test()
