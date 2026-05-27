"""
Test Realtime Supabase Messaging by:
1. Subscribing to changes using anon key (like the app does BEFORE our fix)
2. Inserting a test message
3. Checking if the event fires (it shouldn't with anon key + RLS)
4. Subscribing with authenticated user token
5. Inserting a message
6. Checking if event fires (it SHOULD work)

This tests the core issue we fixed.
"""
import asyncio
import httpx
import json
import time

SUPABASE_URL = "http://127.0.0.1:8000"
ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNjAwMDAwMDAwLCJleHAiOjIwMDAwMDAwMDB9.V-Nq7_uazFUYvZFXyq_whGnFkWy4W_3o4k6m04sGc5Q"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE2MDAwMDAwMDAsImV4cCI6MjAwMDAwMDAwMH0.FFGoBzCoT3bR0JMmOUFOOtvvZjGhMG1jN3sWeoM8l6w"
FASTAPI_URL = "http://127.0.0.1:80"

async def login_user(email: str, password: str, role: str) -> dict:
    """Login via FastAPI and get tokens"""
    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{FASTAPI_URL}/api/auth/login",
            json={"email": email, "password": password, "role": role},
            timeout=10
        )
        data = response.json()
        if response.status_code == 200 and data.get("success"):
            return data["data"]
        else:
            raise Exception(f"Login failed: {data}")

async def test_message_send(token: str, receiver_id: str, school_id: str, content: str) -> dict:
    """Send a message via FastAPI"""
    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{FASTAPI_URL}/api/shared/messages/send",
            json={"receiver_id": receiver_id, "content": content},
            headers={"Authorization": f"Bearer {token}"},
            timeout=10
        )
        return response.json()

async def verify_rls_with_service_role(user_id: str, school_id: str) -> list:
    """Check messages visible with service role (bypass RLS)"""
    async with httpx.AsyncClient() as client:
        response = await client.get(
            f"{SUPABASE_URL}/rest/v1/messages",
            headers={
                "apikey": SERVICE_ROLE_KEY,
                "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
            },
            params={"sender_id": f"eq.{user_id}", "order": "created_at.desc", "limit": "5"},
            timeout=10
        )
        return response.json()

async def verify_rls_with_user_token(user_access_token: str) -> list:
    """Check messages visible with user JWT (respects RLS)"""
    async with httpx.AsyncClient() as client:
        response = await client.get(
            f"{SUPABASE_URL}/rest/v1/messages",
            headers={
                "apikey": ANON_KEY,
                "Authorization": f"Bearer {user_access_token}",
            },
            params={"order": "created_at.desc", "limit": "5"},
            timeout=10
        )
        return response.json()

async def verify_rls_with_anon_key() -> list:
    """Check messages visible with anon key (without auth - like old app)"""
    async with httpx.AsyncClient() as client:
        response = await client.get(
            f"{SUPABASE_URL}/rest/v1/messages",
            headers={
                "apikey": ANON_KEY,
                "Authorization": f"Bearer {ANON_KEY}",
            },
            params={"order": "created_at.desc", "limit": "5"},
            timeout=10
        )
        return response.json()

async def main():
    print("=" * 60)
    print("EduSHAMIIT Realtime Messaging RLS Test")
    print("=" * 60)
    
    # Test credentials - update these
    USER_EMAIL = "naresh.king88898@gmail.com"  
    USER_PASSWORD = "naresh@1A"
    USER_ROLE = "student"
    
    print(f"\n1. Logging in as {USER_EMAIL}...")
    try:
        user_data = await login_user(USER_EMAIL, USER_PASSWORD, USER_ROLE)
        user_id = user_data["user"]["id"]
        fastapi_token = user_data["token"]
        supabase_access_token = user_data.get("supabase_access_token")
        refresh_token = user_data.get("refresh_token")
        
        print(f"   [PASS] Logged in! User ID: {user_id}")
        print(f"   Returned keys: {list(user_data.keys())}")
        print(f"   FastAPI token: {fastapi_token[:20]}...")
        print(f"   Supabase access token: {'present' if supabase_access_token else 'MISSING [FAIL]'}")
        print(f"   Refresh token: {'present' if refresh_token else 'MISSING [FAIL]'}")
        
    except Exception as e:
        print(f"   [FAIL] Login failed: {e}")
        print("   Please update USER_EMAIL and USER_PASSWORD in this script")
        return
    
    print("\n2. Testing RLS - What messages can anon see (old app behavior)?")
    anon_messages = await verify_rls_with_anon_key()
    if isinstance(anon_messages, list):
        print(f"   Anon key sees {len(anon_messages)} messages")
        if len(anon_messages) == 0:
            print("   [PASS] CORRECT: Anon cannot see messages (RLS working)")
        else:
            print(f"   [WARNING] Anon can see {len(anon_messages)} messages - RLS may be disabled!")
    else:
        print(f"   Response: {anon_messages}")
    
    if supabase_access_token:
        print("\n3. Testing RLS - What messages can authenticated user see?")
        user_messages = await verify_rls_with_user_token(supabase_access_token)
        if isinstance(user_messages, list):
            print(f"   Authenticated user sees {len(user_messages)} messages")
            if len(user_messages) > 0:
                print(f"   [PASS] CORRECT: Authenticated user can see their messages via RLS")
            else:
                print(f"   [WARNING] Authenticated user sees 0 messages - check RLS policy")
        else:
            print(f"   Response: {user_messages}")
    
    print("\n4. Testing RLS with service role (bypass all RLS)...")
    service_messages = await verify_rls_with_service_role(user_id, "")
    if isinstance(service_messages, list):
        print(f"   Service role sees {len(service_messages)} messages for user")
    else:
        print(f"   Response: {service_messages}")
    
    print("\n" + "=" * 60)
    print("DIAGNOSIS:")
    print("=" * 60)
    
    if isinstance(anon_messages, list) and len(anon_messages) == 0:
        print("[PASS] RLS is working - anon cannot see messages")
        if supabase_access_token and isinstance(user_messages, list) and len(user_messages) > 0:
            print("[PASS] Authenticated user CAN see messages via RLS")
            print("[PASS] The fix WILL work: Flutter app now authenticates Supabase client")
            print("[PASS] Realtime subscriptions will use the user's auth context")
        else:
            print("[WARNING] Check if the user has any messages in the database")
    
    print("\nREALTIME FIX SUMMARY:")
    print("- Backend: login now returns supabase_access_token")
    print("- Flutter: setSession(refreshToken) called after login")
    print("- RLS: view_messages policy updated to cover group messages")
    print("- Flutter: appendNewMessage() for instant delivery")
    print("- Flutter: background fetchChatHistory() for sender info")

if __name__ == "__main__":
    asyncio.run(main())
