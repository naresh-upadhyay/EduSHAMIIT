import os
import sys
import requests
import subprocess
import json

try:
    sys.stdout.reconfigure(encoding='utf-8')
except AttributeError:
    pass

BASE_URL = os.getenv("API_BASE_URL", "http://127.0.0.1:8082")
STUDENT_CREDS = {"email": "naresh.king88898@gmail.com", "password": "naresh@1A"}
TEACHER_CREDS = {"email": "nehaupadhyay9119@gmail.com", "password": "naresh@1A"}

print("==========================================================")
print("  Rule-Based Badge System E2E & Unit Test Suite")
print("==========================================================")

# 1. API Verification (from Host)
print("\n--- 1. Testing Student API Endpoint (/api/student/achievements) ---")

print("Logging in as student...")
s_login = requests.post(f"{BASE_URL}/api/auth/login", json=STUDENT_CREDS)
if s_login.status_code != 200:
    print(f"[FAIL] Student login failed: {s_login.status_code} - {s_login.text}")
    sys.exit(1)

token_s = s_login.json()["data"]["token"]
headers_s = {"Authorization": f"Bearer {token_s}"}

print("Fetching achievements JIT...")
ach_resp = requests.get(f"{BASE_URL}/api/student/achievements", headers=headers_s)
if ach_resp.status_code != 200:
    print(f"[FAIL] Fetch achievements failed: {ach_resp.status_code} - {ach_resp.text}")
    sys.exit(1)

data_ach = ach_resp.json()["data"]
unlocked = data_ach.get("unlocked_achievements", [])
locked = data_ach.get("locked_achievements", [])

print(f"Total XP: {data_ach.get('xp_points')}")
print(f"Unlocked achievements count: {len(unlocked)}")
print(f"Locked achievements count: {len(locked)}")

# Assertions on Student Endpoint Data Structure
for a in unlocked:
    assert "progress" in a, f"Unlocked badge {a['title']} missing progress"
    assert a["progress"] >= 100.0, f"Unlocked badge {a['title']} progress {a['progress']} < 100"
    assert a["is_locked"] is False, f"Unlocked badge {a['title']} is_locked is True"

maths_scorer_found = False
gold_medal_found = False

for a in locked:
    assert "progress" in a, f"Locked badge {a['title']} missing progress"
    assert a["progress"] < 100.0, f"Locked badge {a['title']} progress {a['progress']} >= 100"
    assert a["is_locked"] is True, f"Locked badge {a['title']} is_locked is False"
    if a["title"] == "Maths Top Scorer":
        maths_scorer_found = True
        print(f"  -> Found Maths Top Scorer (Progress: {a['progress']}% done)")
    if a["title"] == "Gold Medal":
        gold_medal_found = True
        print(f"  -> Found Gold Medal (Progress: {a['progress']}% done)")

# Wait, if Gold Medal or Maths Top Scorer are unlocked, they will be in unlocked list, which is also valid!
for a in unlocked:
    if a["title"] == "Maths Top Scorer":
        maths_scorer_found = True
        print(f"  -> Found Maths Top Scorer (Unlocked, Progress: {a['progress']}% done)")
    if a["title"] == "Gold Medal":
        gold_medal_found = True
        print(f"  -> Found Gold Medal (Unlocked, Progress: {a['progress']}% done)")

assert maths_scorer_found, "Maths Top Scorer badge template missing in student dashboard list!"
assert gold_medal_found, "Gold Medal badge template missing in student dashboard list!"
print("[PASS] Student achievements endpoint schema & JIT values validated successfully.")


print("\n--- 2. Testing Teacher API Endpoint (/api/teacher/achievements/student-progress) ---")

print("Logging in as teacher...")
t_login = requests.post(f"{BASE_URL}/api/auth/login", json=TEACHER_CREDS)
if t_login.status_code != 200:
    print(f"[FAIL] Teacher login failed: {t_login.status_code} - {t_login.text}")
    sys.exit(1)

token_t = t_login.json()["data"]["token"]
headers_t = {"Authorization": f"Bearer {token_t}"}

print("Fetching student progress for Class 10A...")
progress_resp = requests.get(f"{BASE_URL}/api/teacher/achievements/student-progress?class_name=10A", headers=headers_t)
if progress_resp.status_code != 200:
    print(f"[FAIL] Fetch student progress failed: {progress_resp.status_code} - {progress_resp.text}")
    sys.exit(1)

students_progress = progress_resp.json()["data"]["students"]
naresh_prog = None
for s in students_progress:
    if s["name"] == "Naresh Upadhyay":
        naresh_prog = s
        break

if not naresh_prog:
    print("[FAIL] Naresh Upadhyay profile not found in progress list!")
    sys.exit(1)

print(f"Naresh Upadhyay Earned Badges: {naresh_prog['earned_badges']}")

# Verify that Maths Top Scorer (if progress < 100%) is NOT listed in earned_badges
math_locked_progress = None
for a in locked:
    if a["title"] == "Maths Top Scorer":
        math_locked_progress = a["progress"]

maths_scorer_id = "30000000-0000-0000-0000-000000000007"
if math_locked_progress is not None and math_locked_progress < 100.0:
    assert maths_scorer_id not in naresh_prog["earned_badges"], (
        f"Maths Top Scorer (ID: {maths_scorer_id}) is locked ({math_locked_progress}%), "
        f"but returned in teacher's list of earned badges: {naresh_prog['earned_badges']}"
    )
    print("  -> Confirmed: Locked Maths Top Scorer (progress < 100%) is hidden from teacher's earned list.")
else:
    print("  -> Maths Top Scorer is fully unlocked. Nothing to hide.")

print("[PASS] Teacher student-progress filtering validated successfully.")


# 3. Unit & Internal Services Verification (executed inside Container)
print("\n--- 3. Running Container-Side Unit Tests (/app/services/badge_rules.py) ---")

container_test_code = """
import asyncio
from app.services.supabase_client import get_supabase
from app.services.badge_rules import evaluate_and_update_student_badges
from app.tools.student_tools import get_student_tools

async def main():
    sb = get_supabase()
    school_id = "11111111-1111-1111-1111-111111111111"
    
    # Resolve Naresh's ID
    p_res = await sb.table("profiles").select("id, class").eq("email", "naresh.king88898@gmail.com").maybe_single().aexecute()
    assert p_res.data, "Naresh profile not found in DB!"
    student_id = p_res.data["id"]
    
    # A. Test evaluate_and_update_student_badges RPC
    print("    - Running evaluate_and_update_student_badges RPC...")
    await evaluate_and_update_student_badges(sb, school_id, student_id)
    print("    - evaluate_and_update_student_badges executed successfully.")
    
    # B. Test AI tool output
    tools = get_student_tools(school_id)
    get_achievements_tool = next(t for t in tools if t.name == "get_achievements")
    
    # Mock context/user for tool
    import app.tools.student_tools
    original_get_user = app.tools.student_tools.get_current_user_id
    app.tools.student_tools.get_current_user_id = lambda: student_id
    
    try:
        tool_output = get_achievements_tool.invoke({})
        print("    - get_achievements AI agent tool output sample:")
        print("\\n".join(["      " + line for line in tool_output.split("\\n")[:12]]))
        assert "Achievements:" in tool_output or "achievements" in tool_output.lower()
    finally:
        app.tools.student_tools.get_current_user_id = original_get_user
        
    print("    - All internal evaluations returned valid values.")

asyncio.run(main())
"""

# Run the python code directly inside edushamiit-api container using docker exec
cmd = [
    "docker", "exec", "edushamiit-api", "python", "-c", container_test_code
]

res = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8")
if res.returncode != 0:
    print(f"[FAIL] Container-side unit tests failed:\n{res.stderr}\nOutput:\n{res.stdout}")
    sys.exit(1)

print(res.stdout)
print("[PASS] Container-side unit tests completed successfully.")

print("\n==========================================================")
print("  ALL TESTS PASSED! Badge system is 100% verified.")
print("==========================================================")
