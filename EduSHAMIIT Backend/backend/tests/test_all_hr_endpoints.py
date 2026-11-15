import os
import urllib.request
import urllib.error
import json
import sys

BASE_URL = os.environ.get("BASE_URL", "http://127.0.0.1:8000" if os.path.exists("/.dockerenv") else "http://localhost:8082")

endpoints = [
    # Health & System Config
    ('/health', False),
    ('/api/admin/system-config/public', False),
    
    # HR Overview
    ('/api/hr/overview/stats', True),
    
    # Recruitment Endpoints
    ('/api/recruitment/stats', True),
    ('/api/recruitment/pipeline', True),
    ('/api/recruitment/analytics', True),
    ('/api/recruitment/jobs?limit=50', True),
    ('/api/recruitment/candidates?limit=6', True),
    ('/api/recruitment/interviews', True),
    
    # Onboarding Endpoints
    ('/api/onboarding/dashboard', True),
    ('/api/onboarding/records?limit=10', True),
    
    # HR Training Endpoints
    ('/api/training/stats', True),
    ('/api/training/programs', True),
    ('/api/training/sessions', True),
    ('/api/training/learning-paths', True),
    ('/api/training/leaderboard', True),
    
    # HR Policies & Documents
    ('/api/hr/stats', True),
    ('/api/hr/policies', True),
    ('/api/hr/categories', True),
    ('/api/hr/documents', True),
]

def run_tests():
    # Generate JWT super_admin token
    from jose import jwt
    token = jwt.encode({
        'sub': '5198c4b0-f1cb-45db-9649-41688d0438ba',
        'school_id': '11111111-1111-1111-1111-111111111111',
        'role': 'super_admin',
        'email': 'mathematicsking888@gmail.com',
        'exp': 9999999999
    }, 'super-secret-jwt-token-with-at-least-32-characters-long', algorithm='HS256')

    headers_auth = {
        'Accept': 'application/json',
        'Authorization': f'Bearer {token}'
    }
    headers_public = {
        'Accept': 'application/json'
    }

    passed = 0
    failed = 0

    print("=" * 75)
    print(f"{'ENDPOINT':<40} | {'STATUS':<6} | {'RESULT'}")
    print("=" * 75)

    for ep, req_auth in endpoints:
        url = f'{BASE_URL}{ep}'
        hdrs = headers_auth if req_auth else headers_public
        try:
            req = urllib.request.Request(url, headers=hdrs)
            with urllib.request.urlopen(req, timeout=10) as resp:
                data = json.loads(resp.read().decode('utf-8'))
                status_code = resp.status
                data_val = data.get('data') if isinstance(data, dict) else data
                
                if isinstance(data_val, list):
                    summary = f"list (count={len(data_val)})"
                elif isinstance(data_val, dict):
                    keys = list(data_val.keys())[:4]
                    summary = f"dict (keys={keys}...)"
                else:
                    summary = str(data_val)[:35]
                    
                print(f"{ep:<40} | {status_code:<6} | OK: {summary}")
                passed += 1
        except urllib.error.HTTPError as e:
            body = e.read().decode('utf-8', errors='replace')[:150]
            print(f"{ep:<40} | {e.code:<6} | FAILED: {body}")
            failed += 1
        except Exception as e:
            print(f"{ep:<40} | ERROR  | FAILED: {e}")
            failed += 1

    print("=" * 75)
    print(f"Total: {len(endpoints)}, Passed: {passed}, Failed: {failed}")
    print("=" * 75)

    if failed > 0:
        sys.exit(1)
    else:
        print("ALL API ENDPOINTS TESTED AND PASSING 100% PERFECTLY!")

if __name__ == "__main__":
    run_tests()
