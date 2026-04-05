import sys
import os
import uuid
from fastapi.testclient import TestClient

# Add backend directory to sys path so we can import app
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.main import app

client = TestClient(app)

def get_auth_token(role="student"):
    """Register and get an auth token for testing"""
    email = f"test_{role}_{uuid.uuid4().hex[:6]}@example.com"
    data = {
        "email": email,
        "password": "Password123!",
        "full_name": f"Test {role.capitalize()}",
        "role": role,
        "school_id": "11111111-1111-1111-1111-111111111111",
        "class_name": "10A" if role == "student" else None
    }
    
    # Register
    res = client.post("/api/auth/register", json=data)
    if res.status_code != 200:
        print(f"Failed to register {role}: {res.text}")
        return None
        
    # Login
    res = client.post("/api/auth/login", json={"email": email, "password": "Password123!", "role": role})
    if res.status_code == 200:
        return res.json().get("data", {}).get("token")
    else:
        print(f"Failed to login {role}: {res.text}")
        return None

def run_tests():
    print("Gathering auth tokens...")
    student_token = get_auth_token("student")
    teacher_token = get_auth_token("teacher")
    
    if not student_token and not teacher_token:
        print("Auth failed. Skipping tests.")
        return
        
    print(f"Student token: {'OK' if student_token else 'FAIL'}")
    print(f"Teacher token: {'OK' if teacher_token else 'FAIL'}")
    
    headers = {
        "Authorization": f"Bearer {teacher_token if teacher_token else student_token}"
    }

    routes = []
    for r in app.routes:
        if hasattr(r, 'methods') and hasattr(r, 'path'):
            methods = [m for m in r.methods if m not in ('HEAD', 'OPTIONS')]
            if methods:
                routes.append((methods[0], r.path))
                
    print(f"\nDiscovered {len(routes)} routes.")
    
    errors = []
    successes = 0
    ignored = 0
    
    for method, path in sorted(routes, key=lambda x: x[1]):
        # Substitute path parameters natively
        test_path = path.replace("{event_id}", "1")
        test_path = test_path.replace("{notification_id}", "1")
        test_path = test_path.replace("{session_id}", "test-session")
        test_path = test_path.replace("{room}", "1")
        test_path = test_path.replace("{source}", "test.pdf")
        
        try:
            if method == "GET":
                res = client.get(test_path, headers=headers)
            elif method == "POST":
                res = client.post(test_path, headers=headers, json={})
            elif method == "PUT":
                res = client.put(test_path, headers=headers, json={})
            elif method == "DELETE":
                res = client.delete(test_path, headers=headers)
            else:
                ignored += 1
                continue
                
            if res.status_code >= 500:
                print(f"[{method}] {path} -> FAILED WITH {res.status_code}")
                # We can access traceback since it's the client mapping to the exception directly!
                errors.append({"method": method, "path": path, "status": res.status_code, "resp": res.text[:500]})
            else:
                successes += 1
                
        except Exception as e:
            print(f"[{method}] {path} -> EXCEPTION {str(e)}")
            errors.append({"method": method, "path": path, "status": "Exception", "resp": str(e)})

    print("\n" + "="*50)
    print(f"TEST RUN COMPLETE. Total={len(routes)}, Success(Non-500)={successes}, 500 Errors={len(errors)}")
    
    if errors:
        print("\n=== THE FOLLOWING ROUTES CRASHED (500 ERROR) ===")
        for e in errors:
            print(f"- {e['method']} {e['path']}")
            print(f"  Response: {e['resp']}")
    else:
        print("\nALL ROUTES PASSED SMOKE TEST (NO 500s)!")

if __name__ == "__main__":
    run_tests()
