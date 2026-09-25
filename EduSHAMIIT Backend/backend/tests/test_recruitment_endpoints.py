import os
import urllib.request
import json
import sys

BASE_URL = os.environ.get("BASE_URL", "http://127.0.0.1:8000" if os.path.exists("/.dockerenv") else "http://localhost:8082")

endpoints = [
    '/api/recruitment/stats',
    '/api/recruitment/pipeline',
    '/api/recruitment/analytics',
    '/api/recruitment/jobs?limit=50',
    '/api/recruitment/candidates?limit=6',
    '/api/recruitment/interviews'
]

def run_tests():
    from jose import jwt
    token = jwt.encode({
        'sub': '38a93170-997b-4b4c-bc8e-256b93169c23',
        'school_id': '11111111-1111-1111-1111-111111111111',
        'role': 'super_admin',
        'email': 'mathematicsking888@gmail.com',
        'exp': 9999999999
    }, 'super-secret-jwt-token-with-at-least-32-characters-long', algorithm='HS256')

    headers = {
        'Accept': 'application/json',
        'Authorization': f'Bearer {token}'
    }

    all_passed = True
    for ep in endpoints:
        url = f'{BASE_URL}{ep}'
        try:
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req) as resp:
                data = json.loads(resp.read().decode('utf-8'))
                data_val = data.get('data')
                cnt = len(data_val) if isinstance(data_val, list) else ('dict keys=' + str(list(data_val.keys())) if isinstance(data_val, dict) else str(data_val))
                print(f"SUCCESS [{resp.status}] {ep}: success={data.get('success')}, data={cnt}")
        except Exception as e:
            all_passed = False
            print(f"ERROR {ep}: {e}")

    if not all_passed:
        sys.exit(1)
    print("All endpoints passed successfully!")

if __name__ == "__main__":
    run_tests()

