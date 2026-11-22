import os
import sys
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import requests
from app.config import settings
import psycopg2
from psycopg2.extras import RealDictCursor
from jose import jwt

def test_get_books():
    conn = psycopg2.connect(settings.DATABASE_URL)
    cur = conn.cursor(cursor_factory=RealDictCursor)
    
    cur.execute("SELECT id, school_id, title FROM public.library_books WHERE title ILIKE '%New lecture test%' LIMIT 1;")
    book = cur.fetchone()
    if not book:
        cur.execute("SELECT id, school_id, title FROM public.library_books LIMIT 1;")
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

    base_url = os.environ.get("API_BASE_URL", "http://127.0.0.1:8082")
    url = f"{base_url}/api/v1/library/books"
    res = requests.get(url, headers=headers, params={"search": book['title'][:10]})
    print(f"GET /books status: {res.status_code}")
    data = res.json()
    books = data.get("data", [])
    print(f"Returned {len(books)} books")
    for b in books:
        print(f"Book: {b.get('title')}, is_digital: {b.get('is_digital')}, files: {len(b.get('digital_files', []))}")
        for df in b.get('digital_files', []):
            print(f"  - File: {df.get('title')}, type: {df.get('file_type')}, stream_url: {df.get('stream_url')}, is_live: {df.get('is_live_stream')}")

if __name__ == "__main__":
    test_get_books()
