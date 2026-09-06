import requests
from app.config import settings
import psycopg2
from psycopg2.extras import RealDictCursor
from jose import jwt

def test_digital_viewer_e2e():
    conn = psycopg2.connect(settings.DATABASE_URL)
    cur = conn.cursor(cursor_factory=RealDictCursor)
    
    cur.execute("SELECT id, school_id, title FROM public.library_books WHERE title ILIKE '%New lecture test%' LIMIT 1;")
    book = cur.fetchone()
    book_id = str(book['id'])
    school_id = str(book['school_id'])

    cur.execute("SELECT id FROM auth.users LIMIT 1;")
    user = cur.fetchone()
    user_id = str(user['id'])

    jwt_secret = getattr(settings, "SUPABASE_JWT_SECRET", getattr(settings, "JWT_SECRET", "super-secret-jwt-token-with-at-least-32-characters-long"))
    token = jwt.encode(
        {"sub": user_id, "school_id": school_id, "role": "admin", "aud": "authenticated"},
        jwt_secret,
        algorithm="HS256"
    )

    headers = {
        "Authorization": f"Bearer {token}",
        "X-School-ID": school_id,
        "Content-Type": "application/json"
    }

    # 1. Get secure playback / stream session token
    url_token = f"http://127.0.0.1:8000/api/v1/library/books/{book_id}/digital-stream-token"
    res_token = requests.post(url_token, headers=headers, json={})
    print(f"1. Generate Stream Token Status: {res_token.status_code}")
    assert res_token.status_code == 200
    token_data = res_token.json().get("data", {})
    print(f"   Stream URL: {token_data.get('stream_url')}")
    print(f"   Signed Token: {token_data.get('stream_token', '')[:30]}...")


    # 2. Record reading / listening progress
    url_progress = f"http://127.0.0.1:8000/api/v1/library/books/{book_id}/progress"
    res_progress = requests.post(url_progress, headers=headers, json={
        "media_type": "VIDEO",
        "progress_percentage": 50.0,
        "seconds_spent": 120,
        "last_position_seconds": 60,
        "is_completed": False
    })
    print(f"2. Record Digital Progress Status: {res_progress.status_code}")
    assert res_progress.status_code == 200

    print("\nALL DIGITAL STREAMING & PLAYBACK ENDPOINTS TESTED AND PASSED (200 OK)!")

if __name__ == "__main__":
    test_digital_viewer_e2e()

