import hmac
import hashlib
import base64
import os

def verify_jwt_signature(token, secret):
    if not token or not secret:
        return False
    parts = token.split('.')
    if len(parts) != 3:
        return False
    
    header_payload = f"{parts[0]}.{parts[1]}"
    signature = parts[2]
    
    if isinstance(secret, str):
        secret = secret.encode('utf-8')
    
    expected_signature_bytes = hmac.new(
        secret,
        header_payload.encode('utf-8'),
        hashlib.sha256
    ).digest()
    
    expected_signature = base64.urlsafe_b64encode(expected_signature_bytes).decode('utf-8').rstrip('=')
    
    return signature == expected_signature

def load_env(filepath):
    env = {}
    if os.path.exists(filepath):
        with open(filepath, 'r', encoding='utf-8') as f:
            for line in f:
                if '=' in line and not line.startswith('#'):
                    try:
                        key, val = line.strip().split('=', 1)
                        env[key] = val
                    except ValueError:
                        continue
    return env

root_env = load_env('e:/EduSHAMIIT/.env')
jwt_secret = root_env.get('SUPABASE_JWT_SECRET') or root_env.get('JWT_SECRET')

print(f"Secret: {jwt_secret}")
print(f"ANON_KEY Valid: {verify_jwt_signature(root_env.get('ANON_KEY'), jwt_secret)}")
print(f"SERVICE_ROLE_KEY Valid: {verify_jwt_signature(root_env.get('SERVICE_ROLE_KEY'), jwt_secret)}")
print(f"SUPABASE_ANON_KEY Valid: {verify_jwt_signature(root_env.get('SUPABASE_ANON_KEY'), jwt_secret)}")
print(f"SUPABASE_SERVICE_ROLE_KEY Valid: {verify_jwt_signature(root_env.get('SUPABASE_SERVICE_ROLE_KEY'), jwt_secret)}")
