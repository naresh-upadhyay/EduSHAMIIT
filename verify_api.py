import httpx
import json, sys

BASE = "https://edushamiit-api-xi3m4tapoa-uc.a.run.app"

# Health
try:
    r = httpx.get(f"{BASE}/health", timeout=10)
    print(f"[HEALTH] {r.status_code} -> {r.text}")
except Exception as e:
    print(f"[HEALTH FAIL] {e}")
    sys.exit(1)

# Login with non-existent user
payload = {"email": "nonexistent@test.com", "password": "test123"}
try:
    r = httpx.post(f"{BASE}/api/auth/login", json=payload, timeout=15)
    print(f"[LOGIN] {r.status_code} -> {r.text[:200]}")
except Exception as e:
    print(f"[LOGIN FAIL] {e}")
    sys.exit(1)

print("\nAPI is reachable and processing requests correctly!")