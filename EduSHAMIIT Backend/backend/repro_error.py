import sys
import os
import httpx
import json
from dotenv import load_dotenv

# Add backend directory to sys path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.services.supabase_client import get_supabase

# Load environment variables
load_dotenv('../.env')

def test_duplicate_registration():
    sb = get_supabase()
    email = "newstudent@example.com"
    password = "NewPassword123!"
    
    print(f"Attempting to register {email} (again)...")
    try:
        # First ensure user exists (it was supposedly deleted but let's be sure)
        print("Ensuring user exists by trying once...")
        try:
            sb.auth().sign_up({"email": email, "password": password})
            print("First sign_up worked (user created).")
        except Exception as e:
            print(f"First sign_up error (expected if user exists): {str(e)}")
            
        # Try again - this should throw the duplicate error
        print("\nAttempting DUPLICATE sign_up...")
        sb.auth().sign_up({"email": email, "password": password})
        print("Wait, DUPLICATE sign_up worked? (Should not happen)")
    except Exception as e:
        print(f"DUPLICATE sign_up caught error: '{str(e)}'")
        
        # Now let's see what the RAW response was
        print("\nManually checking raw response for duplicate sign_up...")
        url = os.getenv("SUPABASE_URL")
        key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
        headers = {
            "apikey": key,
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json"
        }
        res = httpx.post(f"{url}/auth/v1/signup", headers=headers, json={"email": email, "password": password})
        print(f"Status: {res.status_code}")
        print(f"JSON: {res.json()}")

if __name__ == "__main__":
    test_duplicate_registration()
